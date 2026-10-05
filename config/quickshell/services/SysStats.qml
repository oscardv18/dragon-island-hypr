// =============================================================================
// dragon-island — SysStats.qml
// Service: CPU, RAM, Temperature and Disk Resource Monitoring
// =============================================================================
/**
 * Properties:
 *   - cpuPct: int [readonly] (0 - 100)
 *   - memPct: int [readonly] (0 - 100)
 *   - memUsedGb: real [readonly]
 *   - memTotalGb: real [readonly]
 *   - tempC: int [readonly] (degrees Celsius)
 *   - diskPct: int [readonly] (0 - 100)
 *   - diskUsedGb: real [readonly]
 *   - diskTotalGb: real [readonly]
 *
 * Functions:
 *   - refresh(): void
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
    property int memPct: 0
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property int tempC: 45
    property int diskPct: 0
    property real diskUsedGb: 0.0
    property real diskTotalGb: 0.0

    // Internal state for CPU differential calculation
    property real _prevTotal: 0
    property real _prevIdle: 0

    Process {
        id: statsProc
        command: [
            "sh", "-c",
            "awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat; " +
            "awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {print t, a}' /proc/meminfo; " +
            "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000; " +
            "df -BG / | tail -n1 | awk '{gsub(/G/,\"\"); print $2, $3, $5}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 4) return;

                // 1. CPU Diff
                const cpuParts = lines[0].trim().split(" ");
                if (cpuParts.length >= 2) {
                    const total = parseFloat(cpuParts[0]);
                    const idle = parseFloat(cpuParts[1]);
                    if (root._prevTotal > 0) {
                        const totalDiff = total - root._prevTotal;
                        const idleDiff = idle - root._prevIdle;
                        if (totalDiff > 0) {
                            const usage = Math.round(((totalDiff - idleDiff) / totalDiff) * 100);
                            root.cpuPct = Math.max(0, Math.min(100, usage));
                        }
                    }
                    root._prevTotal = total;
                    root._prevIdle = idle;
                }

                // 2. RAM (kB to GB)
                const memParts = lines[1].trim().split(" ");
                if (memParts.length >= 2) {
                    const totalKb = parseFloat(memParts[0]);
                    const availKb = parseFloat(memParts[1]);
                    const usedKb = totalKb - availKb;
                    root.memTotalGb = Math.round((totalKb / (1024 * 1024)) * 10) / 10;
                    root.memUsedGb = Math.round((usedKb / (1024 * 1024)) * 10) / 10;
                    if (totalKb > 0) {
                        root.memPct = Math.round((usedKb / totalKb) * 100);
                    }
                }

                // 3. Temperature (millidegrees to C)
                const tempMilli = parseInt(lines[2].trim());
                if (!isNaN(tempMilli)) {
                    root.tempC = Math.round(tempMilli / 1000);
                }

                // 4. Disk
                const diskParts = lines[3].trim().split(" ");
                if (diskParts.length >= 3) {
                    root.diskTotalGb = parseFloat(diskParts[0]) || 0;
                    root.diskUsedGb = parseFloat(diskParts[1]) || 0;
                    root.diskPct = parseInt(diskParts[2].replace("%", "")) || 0;
                }

                root.statsUpdated();
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running) {
                statsProc.running = true;
            }
        }
    }

    function refresh(): void {
        if (!statsProc.running) {
            statsProc.running = true;
        }
    }

    signal statsUpdated()
}
