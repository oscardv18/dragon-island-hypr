// =============================================================================
// dragon-island — Osd.qml
// Service: on-screen display state, driven by Audio / Brightness changes (not by IPC)
// =============================================================================
/**
 * Properties:
 *   - visible: bool [readonly]
 *   - kind: string [readonly] ("volume" | "mic" | "brightness")
 *   - icon: string [readonly] (semantic name: "volume-high" | "volume-low" | "volume-off" | "mic" | "mic-off" | "sun")
 *   - label: string [readonly]
 *   - value: real [readonly] (0.0 - 1.0)
 *   - isMuted: bool [readonly]
 *
 * Functions:
 *   - show(kind: string, val: real, muted: bool): void
 *   - dismiss(): void
 *
 * Signals:
 *   - triggered()
 *
 * Changes in the first 1.5 s after startup (initial sync) are ignored.
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property bool visible: false
    property string kind: "volume"
    property string icon: ""
    property string label: ""
    property real value: 0.0
    property bool isMuted: false

    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer {
        id: hideTimer
        interval: Theme.durationToast
        onTriggered: root.visible = false
    }

    Connections {
        target: Audio
        function onVolumePctChanged() { root.show("volume", Audio.volume, Audio.muted); }
        function onMutedChanged() { root.show("volume", Audio.volume, Audio.muted); }
        function onMicMutedChanged() { root.show("mic", Audio.micVolume, Audio.micMuted); }
        // default device switch: not a user volume change
        function onSinkChanged() { root._suppressFor(800); }
    }

    Connections {
        target: Brightness
        function onBrightnessPctChanged() { root.show("brightness", Brightness.brightnessReal, false); }
    }

    Timer { id: suppress; interval: 800 }
    function _suppressFor(ms: int): void { suppress.interval = ms; suppress.restart(); }

    function show(kind: string, val: real, muted: bool): void {
        if (!root._armed || suppress.running) return;
        root.kind = kind;
        root.value = Math.max(0.0, Math.min(1.0, val));
        root.isMuted = muted;
        switch (kind) {
            case "mic":
                root.icon = muted ? "mic-off" : "mic";
                root.label = muted ? "Micrófono silenciado" : "Micrófono";
                break;
            case "brightness":
                root.icon = "sun";
                root.label = "Brillo";
                break;
            default:
                root.icon = muted || val <= 0 ? "volume-off" : (val < 0.5 ? "volume-low" : "volume-high");
                root.label = muted ? "Silenciado" : "Volumen";
        }
        root.visible = true;
        hideTimer.restart();
        root.triggered();
    }

    function dismiss(): void {
        hideTimer.stop();
        root.visible = false;
    }

    signal triggered()
}
