// =============================================================================
// dragon-island — Brightness.qml
// Service: display brightness
//   · internal panel: backlight via sysfs (read) + brightnessctl (write)
//   · external monitors: DDC/CI via ddcutil (VCP 0x10), matched to Hyprland monitors
//     by DRM connector name ("card1-DP-1" → "DP-1")
// =============================================================================
/**
 * Properties (backlight, internal panel):
 *   - available: bool [readonly] (a backlight device exists)
 *   - device: string [readonly] (e.g. "intel_backlight")
 *   - brightnessPct: int [readonly] (0 - 100)
 *   - brightnessReal: real [readonly] (0.0 - 1.0)
 * Properties (DDC):
 *   - ddcAvailable: bool [readonly] (ddcutil found at least one controllable monitor)
 *   - ddcDisplays: list<var> [readonly] ({ connector, bus, pct })
 *
 * Functions:
 *   - setBrightness(pct: int): void / setBrightnessReal(v: real): void (backlight, clamped 1 - 100)
 *   - increase(step: int): void       decrease(step: int): void        (backlight)
 *   - refresh(): void                 (backlight now + DDC re-detect)
 *   - controllableOn(screenName: string): bool   (backlight or DDC for that monitor)
 *   - levelFor(screenName: string): real         (0.0 - 1.0)
 *   - setLevelFor(screenName: string, v: real): void (debounced for DDC, which is slow)
 *
 * Change notification: brightnessPctChanged (property signal). Osd.qml listens to it,
 * so hardware keys (brightnessctl from Hyprland binds) show the OSD within ~300 ms.
 * DDC needs the i2c-dev module and udev access; the ddcutil package ships both.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // =========================================================================
    // Backlight (internal panel)
    // =========================================================================
    property string device: ""
    readonly property bool available: device.length > 0 && maxRaw > 0
    property int maxRaw: 0
    property int brightnessPct: 0
    readonly property real brightnessReal: brightnessPct / 100.0

    // Find the first backlight device once
    Process {
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = this.text.trim()
        }
    }

    FileView {
        id: maxFile
        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        printErrors: false
        onLoaded: root.maxRaw = parseInt(maxFile.text().trim()) || 0
    }

    FileView {
        id: curFile
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        printErrors: false
        onLoaded: {
            const raw = parseInt(curFile.text().trim());
            if (!isNaN(raw) && root.maxRaw > 0 && !writeDebounce.running) {
                root.brightnessPct = Math.round(raw * 100 / root.maxRaw);
            }
        }
    }

    // sysfs does not emit inotify events: poll the (cheap) file read instead of spawning processes
    Timer {
        interval: 300
        repeat: true
        running: root.available
        onTriggered: curFile.reload()
    }

    Process { id: writeProc }

    // While the user drags a slider, don't let polling fight the optimistic value
    Timer { id: writeDebounce; interval: 600 }

    function setBrightness(pct: int): void {
        if (!root.available) return;
        const target = Math.max(1, Math.min(100, Math.round(pct)));
        root.brightnessPct = target;
        writeDebounce.restart();
        writeProc.exec(["brightnessctl", "-d", root.device, "set", `${target}%`]);
    }

    function setBrightnessReal(v: real): void { setBrightness(Math.round(v * 100)); }
    function increase(step: int): void { setBrightness(root.brightnessPct + (step > 0 ? step : 5)); }
    function decrease(step: int): void { setBrightness(root.brightnessPct - (step > 0 ? step : 5)); }

    function refresh(): void {
        if (root.available) curFile.reload();
        detectDdc();
    }

    // =========================================================================
    // DDC/CI (external monitors)
    // =========================================================================
    property var ddcDisplays: []            // [{ connector, bus, pct, max }]
    readonly property bool ddcAvailable: ddcDisplays.length > 0

    // ddcutil must not talk to the same bus concurrently: one job at a time
    property var _queue: []
    property var _job: null
    property var _pendingSet: ({})          // connector → pct waiting for the debounce

    Process {
        id: ddcProc
        stdout: StdioCollector {
            onStreamFinished: root._jobOutput(this.text)
        }
        onExited: (code, status) => {
            root._job = null;
            root._runNext();
        }
    }

    function _enqueue(job): void {
        root._queue = root._queue.concat([job]);
        if (!ddcProc.running && root._job === null) _runNext();
    }

    function _runNext(): void {
        if (root._queue.length === 0) return;
        root._job = root._queue[0];
        root._queue = root._queue.slice(1);
        ddcProc.exec(root._job.args);
    }

    function _jobOutput(text: string): void {
        const job = root._job;
        if (!job) return;
        if (job.kind === "detect") {
            // "Display N" blocks: "I2C bus: /dev/i2c-7", "DRM connector: card1-DP-1"; "Invalid display" blocks are skipped
            const found = [];
            let cur = null;
            for (const raw of text.split("\n")) {
                const line = raw.trim();
                if (/^Display \d+/.test(line)) { cur = { connector: "", bus: -1, pct: -1, max: 100 }; found.push(cur); continue; }
                if (/^Invalid display/.test(line) || /^Phantom display/.test(line)) { cur = null; continue; }
                if (!cur) continue;
                let m = /^I2C bus:\s*\/dev\/i2c-(\d+)/.exec(line);
                if (m) { cur.bus = parseInt(m[1], 10); continue; }
                m = /^DRM connector:\s*card\d+-(.+)$/.exec(line);
                if (m) cur.connector = m[1].trim();
            }
            const displays = found.filter(d => d.bus >= 0);
            displays.forEach((d, i) => { if (!d.connector) d.connector = `ddc-${d.bus}`; });
            root.ddcDisplays = displays;
            for (const d of displays) {
                _enqueue({ kind: "get", connector: d.connector, args: ["ddcutil", "--bus", `${d.bus}`, "getvcp", "10", "--brief"] });
            }
        } else if (job.kind === "get") {
            // "VCP 10 C <current> <max>"
            const m = /VCP\s+10\s+C\s+(\d+)\s+(\d+)/.exec(text);
            if (!m) return;
            const cur = parseInt(m[1], 10), max = parseInt(m[2], 10) || 100;
            root.ddcDisplays = root.ddcDisplays.map(d => d.connector === job.connector
                ? Object.assign({}, d, { pct: Math.round(cur * 100 / max), max: max }) : d);
        }
    }

    function detectDdc(): void {
        _enqueue({ kind: "detect", args: ["sh", "-c", "command -v ddcutil >/dev/null || exit 3; exec ddcutil detect"] });
    }

    Component.onCompleted: detectDdc()

    // monitors can be changed with their own buttons: re-read now and then (DDC is slow)
    Timer {
        interval: 60000
        repeat: true
        running: root.ddcAvailable
        onTriggered: {
            for (const d of root.ddcDisplays)
                root._enqueue({ kind: "get", connector: d.connector, args: ["ddcutil", "--bus", `${d.bus}`, "getvcp", "10", "--brief"] });
        }
    }

    Timer {
        id: ddcDebounce
        interval: 250
        onTriggered: {
            const pending = root._pendingSet;
            root._pendingSet = {};
            for (const connector in pending) {
                const d = root.ddcDisplays.find(x => x.connector === connector);
                if (!d) continue;
                const value = Math.round(pending[connector] * d.max / 100);
                root._enqueue({ kind: "set", connector: connector, args: ["ddcutil", "--bus", `${d.bus}`, "setvcp", "10", `${value}`] });
            }
        }
    }

    function _isInternal(name: string): bool {
        return /^(eDP|LVDS|DSI)/.test(name);
    }

    // DDC display for a Hyprland monitor; if connectors are unknown and there is a single
    // DDC monitor, it is assumed to be the (only) external one.
    function _ddcFor(screenName: string): var {
        const exact = root.ddcDisplays.find(d => d.connector === screenName);
        if (exact) return exact;
        if (root.ddcDisplays.length === 1 && root.ddcDisplays[0].connector.startsWith("ddc-") && !_isInternal(screenName))
            return root.ddcDisplays[0];
        return null;
    }

    function controllableOn(screenName: string): bool {
        if (_ddcFor(screenName)) return true;
        return root.available && (_isInternal(screenName) || !root.ddcAvailable || screenName === "");
    }

    function levelFor(screenName: string): real {
        const d = _ddcFor(screenName);
        if (d) return Math.max(0, d.pct) / 100;
        return root.brightnessReal;
    }

    function setLevelFor(screenName: string, v: real): void {
        const pct = Math.max(1, Math.min(100, Math.round(v * 100)));
        const d = _ddcFor(screenName);
        if (!d) { setBrightness(pct); return; }
        // optimistic value for the slider, write after the debounce
        root.ddcDisplays = root.ddcDisplays.map(x => x.connector === d.connector ? Object.assign({}, x, { pct: pct }) : x);
        const p = Object.assign({}, root._pendingSet);
        p[d.connector] = pct;
        root._pendingSet = p;
        ddcDebounce.restart();
    }
}
