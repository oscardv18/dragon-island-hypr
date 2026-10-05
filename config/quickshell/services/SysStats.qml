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

    property var _prev: ({})   // cpu label → [total, idle]
    property int _detailRefs: 0

    readonly property string script: `
echo "#CPU"; grep '^cpu' /proc/stat
echo "#MEM"; awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {print t, a}' /proc/meminfo
echo "#TEMP"
t=""
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    coretemp|k10temp|zenpower|cpu_thermal|soc_thermal) t=$(cat "$h/temp1_input" 2>/dev/null); break ;;
  esac
done
[ -z "$t" ] && t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
echo "\${t:--1}"
echo "#DISK"; df -B1 --output=size,used / | tail -n1
echo "#GPU"
g=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n1)
[ -z "$g" ] && command -v nvidia-smi >/dev/null && g=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
echo "\${g:--1}"
`

    Process {
        id: statsProc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
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
            if (!statsProc.running) statsProc.running = true;
            if (root._detailRefs > 0 && !procsProc.running) procsProc.running = true;
        }
    }

    function refresh(): void {
        if (!statsProc.running) statsProc.running = true;
    }

    function wantDetails(on: bool): void {
        root._detailRefs = Math.max(0, root._detailRefs + (on ? 1 : -1));
        if (on && !procsProc.running) procsProc.running = true;
    }

    signal statsUpdated()
}
