// =============================================================================
// dragon-island — Brightness.qml
// Service: Screen Backlight Control via brightnessctl
// =============================================================================
/**
 * Properties:
 *   - brightnessPct: int [readonly] (0 - 100 percentage)
 *   - brightnessReal: real [readonly] (0.0 - 1.0 normalized)
 *
 * Functions:
 *   - setBrightness(pct: int): void
 *   - increase(step: int): void
 *   - decrease(step: int): void
 *   - refresh(): void
 *
 * Signals:
 *   - brightnessChanged(pct: int)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int brightnessPct: 100
    readonly property real brightnessReal: brightnessPct / 100.0

    // Read current brightness level
    Process {
        id: readProc
        command: ["sh", "-c", "brightnessctl -m | awk -F, '{gsub(/%/, \"\"); print $4}' | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(this.text.trim());
                if (!isNaN(val)) {
                    root.brightnessPct = Math.max(0, Math.min(100, val));
                }
            }
        }
    }

    // Write brightness level
    Process {
        id: writeProc
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!readProc.running) {
                readProc.running = true;
            }
        }
    }

    function setBrightness(pct: int): void {
        const target = Math.max(1, Math.min(100, pct));
        root.brightnessPct = target;
        writeProc.exec(["brightnessctl", "set", `${target}%`]);
    }

    function increase(step: int): void {
        setBrightness(root.brightnessPct + (step > 0 ? step : 5));
    }

    function decrease(step: int): void {
        setBrightness(root.brightnessPct - (step > 0 ? step : 5));
    }

    function refresh(): void {
        if (!readProc.running) {
            readProc.running = true;
        }
    }

    signal brightnessChanged(pct: int)
    onBrightnessPctChanged: root.brightnessChanged(root.brightnessPct)
}
