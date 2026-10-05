// =============================================================================
// dragon-island — Brightness.qml
// Service: internal display backlight (reads sysfs, writes with brightnessctl)
// =============================================================================
/**
 * Properties:
 *   - available: bool [readonly] (false on desktops / external monitors without a backlight)
 *   - device: string [readonly] (e.g. "intel_backlight")
 *   - brightnessPct: int [readonly] (0 - 100)
 *   - brightnessReal: real [readonly] (0.0 - 1.0)
 *
 * Functions:
 *   - setBrightness(pct: int): void   (clamped to 1 - 100)
 *   - setBrightnessReal(v: real): void
 *   - increase(step: int): void       decrease(step: int): void
 *   - refresh(): void
 *
 * Change notification: brightnessPctChanged (property signal). Osd.qml listens to it,
 * so hardware keys (brightnessctl from Hyprland binds) show the OSD within ~300 ms.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

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
    function refresh(): void { if (root.available) curFile.reload(); }
}
