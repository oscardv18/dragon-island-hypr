// =============================================================================
// dragon-island — SysStats.qml
// Service: CPU (total + per core), RAM, temperature, disk, GPU and top processes
// =============================================================================
/**
 * Properties:
 *   - cpuPct: int [readonly] (0 - 100)
 *   - corePcts: list<int> [readonly] (one entry per logical core)
 *   - memPct: int [readonly]   memUsedGb / memTotalGb: real [readonly]
 *   - tempC: int [readonly] (CPU package temperature, -1 if unknown)
 *   - diskPct: int [readonly]  diskUsedGb / diskTotalGb: real [readonly] (root filesystem)
 *   - gpuPct: int [readonly] (-1 if unknown; AMD/Intel sysfs or nvidia-smi)
 *   - cpuHistory: list<int> [readonly] (last 30 samples, 2 s apart = 60 s, newest last)
 *   - rxRate / txRate: real [readonly] (bytes per second, all interfaces but lo)
 *   - rxHistory: list<real> [readonly] (last 12 download rates, 2 s apart, newest last: the bar's network line)
 *   - topProcs: list<var> [readonly] ({ name, cpu, memMb }, 4 entries, only while details are wanted)
 *
 * Functions:
 *   - refresh(): void
 *   - wantDetails(on: bool): void (per-process polling, enable while the Rendimiento popover is open)
 *
 * Signals:
 *   - statsUpdated()
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int cpuPct: 0
    property var corePcts: []
    property int memPct: 0
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property int tempC: -1
    property int diskPct: 0
    property real diskUsedGb: 0.0
    property real diskTotalGb: 0.0
    property int gpuPct: -1
    property var topProcs: []
    property var cpuHistory: []
    property real rxRate: 0
    property real txRate: 0
    property var rxHistory: []
    property var _net: null     // [rx, tx, timestamp ms]

    function formatRate(bps: real): string {
        if (bps >= 1048576) return `${(bps / 1048576).toFixed(1)} MB/s`;
        if (bps >= 1024) return `${Math.round(bps / 1024)} KB/s`;
        return `${Math.round(bps)} B/s`;
    }

    property var _prev: ({})   // cpu label → [total, idle]
    property int _detailRefs: 0

    // ---- sources: /proc and /sys through FileView (no process every 2 s; pulido, rendimiento) ----
    // The temperature and GPU files are found once (one short `sh` at start); the disk (`df`) is read every minute.
    property string _tempPath: ""
    property string _gpuPath: ""
    property bool _nvidia: false
    Process {
        id: probe
        running: true
        command: ["sh", "-c", `
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    coretemp|k10temp|zenpower|cpu_thermal|soc_thermal) echo "T $h/temp1_input"; break ;;
  esac
done
echo "Z /sys/class/thermal/thermal_zone0/temp"
for g in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$g" ] && { echo "G $g"; break; }; done
command -v nvidia-smi >/dev/null && echo "N"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = "", z = "";
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("T ")) t = line.substring(2);
                    else if (line.startsWith("Z ")) z = line.substring(2);
                    else if (line.startsWith("G ")) root._gpuPath = line.substring(2);
                    else if (line === "N") root._nvidia = true;
                }
                root._tempPath = t || z;
            }
        }
    }
    FileView { id: statFile; path: "/proc/stat"; printErrors: false; blockLoading: true }
    FileView { id: netFile; path: "/proc/net/dev"; printErrors: false; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; printErrors: false; blockLoading: true }
    FileView { id: tempFile; path: root._tempPath; printErrors: false; blockLoading: true }
    FileView { id: gpuFile; path: root._gpuPath; printErrors: false; blockLoading: true }
    Process {
        id: nvidiaProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector { onStreamFinished: { const g = parseInt(this.text); root.gpuPct = isNaN(g) ? -1 : g; } }
    }
    Process {
        id: diskProc
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = (this.text.trim().split("\n").pop() ?? "").trim().split(/\s+/);
                const size = Number(f[0]), used = Number(f[1]);
                if (size > 0) {
                    root.diskTotalGb = Math.round(size / 1e8) / 10;
                    root.diskUsedGb = Math.round(used / 1e8) / 10;
                    root.diskPct = Math.round(100 * used / size);
                }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!diskProc.running) diskProc.running = true }

    // the same text the old script printed, assembled from the files, so parse() did not change
    function _sample(): void {
        for (const f of [statFile, netFile, memFile]) f.reload();
        if (root._tempPath) tempFile.reload();
        if (root._gpuPath) gpuFile.reload();
        else if (root._nvidia && !nvidiaProc.running) nvidiaProc.running = true;
        const cpu = statFile.text().split("\n").filter(l => l.startsWith("cpu")).join("\n");
        let rx = 0, tx = 0;
        for (const line of netFile.text().split("\n").slice(2)) {
            const i = line.indexOf(":");
            if (i < 0 || line.substring(0, i).trim() === "lo") continue;
            const f = line.substring(i + 1).trim().split(/\s+/);
            rx += Number(f[0]) || 0;
            tx += Number(f[8]) || 0;
        }
        const mem = memFile.text();
        const kb = k => { const m = new RegExp(`^${k}:\\s+(\\d+)`, "m").exec(mem); return m ? m[1] : "0"; };
        const temp = root._tempPath ? (tempFile.text().trim() || "-1") : "-1";
        const gpu = root._gpuPath ? (gpuFile.text().trim() || "-1") : String(root._nvidia ? root.gpuPct : -1);
        root.parse(`#CPU\n${cpu}\n#NET\n${rx} ${tx}\n#MEM\n${kb("MemTotal")} ${kb("MemAvailable")}\n#TEMP\n${temp}\n#GPU\n${gpu}\n`);
    }

    function parse(text: string): void {
        let section = "";
        const prev = root._prev;
        const next = {};
        const cores = [];
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (!line) continue;
            if (line.startsWith("#")) { section = line.substring(1); continue; }
            const f = line.split(/\s+/);
            if (section === "CPU") {
                const label = f[0];
                const vals = f.slice(1).map(Number);
                const idle = vals[3] + (vals[4] || 0);
                const total = vals.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
                let pct = 0;
                if (prev[label]) {
                    const dt = total - prev[label][0];
                    const di = idle - prev[label][1];
                    pct = dt > 0 ? Math.round(100 * (dt - di) / dt) : 0;
                }
                next[label] = [total, idle];
                pct = Math.max(0, Math.min(100, pct));
                if (label === "cpu") root.cpuPct = pct; else cores.push(pct);
            } else if (section === "NET") {
                const now = Date.now(), rx = Number(f[0]), tx = Number(f[1]);
                if (root._net && now > root._net[2]) {
                    const dt = (now - root._net[2]) / 1000;
                    root.rxRate = Math.max(0, (rx - root._net[0]) / dt);
                    root.txRate = Math.max(0, (tx - root._net[1]) / dt);
                    root.rxHistory = root.rxHistory.concat([root.rxRate]).slice(-12);
                }
                root._net = [rx, tx, now];
            } else if (section === "MEM") {
                const totalKb = Number(f[0]), availKb = Number(f[1]);
                if (totalKb > 0) {
                    const usedKb = totalKb - availKb;
                    root.memTotalGb = Math.round(totalKb / 104857.6) / 10;
                    root.memUsedGb = Math.round(usedKb / 104857.6) / 10;
                    root.memPct = Math.round(100 * usedKb / totalKb);
                }
            } else if (section === "TEMP") {
                const milli = parseInt(f[0]);
                root.tempC = milli > 0 ? Math.round(milli / 1000) : -1;
            } else if (section === "DISK") {
                const size = Number(f[0]), used = Number(f[1]);
                if (size > 0) {
                    root.diskTotalGb = Math.round(size / 1e8) / 10;
                    root.diskUsedGb = Math.round(used / 1e8) / 10;
                    root.diskPct = Math.round(100 * used / size);
                }
            } else if (section === "GPU") {
                const g = parseInt(f[0]);
                root.gpuPct = isNaN(g) ? -1 : g;
            }
        }
        root._prev = next;
        root.corePcts = cores;
        root.cpuHistory = root.cpuHistory.concat([root.cpuPct]).slice(-30);
        root.statsUpdated();
    }

    Process {
        id: procsProc
        command: ["sh", "-c", "ps -eo comm=,pcpu=,rss= --sort=-pcpu | head -n 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const raw of this.text.split("\n")) {
                    const f = raw.trim().split(/\s+/);
                    if (f.length < 3) continue;
                    list.push({ name: f.slice(0, f.length - 2).join(" "), cpu: Number(f[f.length - 2]), memMb: Math.round(Number(f[f.length - 1]) / 1024) });
                }
                root.topProcs = list;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._sample();
            if (root._detailRefs > 0 && !procsProc.running) procsProc.running = true;
        }
    }

    function refresh(): void { root._sample(); }

    function wantDetails(on: bool): void {
        root._detailRefs = Math.max(0, root._detailRefs + (on ? 1 : -1));
        if (on && !procsProc.running) procsProc.running = true;
    }

    signal statsUpdated()
}
