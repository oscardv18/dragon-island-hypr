// =============================================================================
// dragon-island — Osd.qml
// Service: On-Screen Display (OSD) Event Coordinator
// =============================================================================
/**
 * Properties:
 *   - visible: bool [readonly]
 *   - icon: string [readonly]
 *   - label: string [readonly]
 *   - value: real [readonly] (0.0 - 1.0 normalized)
 *   - isMuted: bool [readonly]
 *
 * Functions:
 *   - show(iconName: string, labelText: string, val: real, muted: bool): void
 *   - showVolume(pct: int, muted: bool): void
 *   - showBrightness(pct: int): void
 *   - dismiss(): void
 *
 * Signals:
 *   - triggered()
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool visible: false
    property string icon: ""
    property string label: ""
    property real value: 0.0
    property bool isMuted: false

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: root.visible = false
    }

    function show(iconName: string, labelText: string, val: real, muted: bool): void {
        root.icon = iconName;
        root.label = labelText;
        root.value = Math.max(0.0, Math.min(1.0, val));
        root.isMuted = muted;
        root.visible = true;
        hideTimer.restart();
        root.triggered();
    }

    function showVolume(pct: int, muted: bool): void {
        show(muted ? "volume-off" : "volume-high", "Volumen", pct / 100.0, muted);
    }

    function showBrightness(pct: int): void {
        show("sun", "Brillo", pct / 100.0, false);
    }

    function dismiss(): void {
        hideTimer.stop();
        root.visible = false;
    }

    signal triggered()
}
