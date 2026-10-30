// =============================================================================
// dragon-island — Osd.qml
// Service: on-screen display state, driven by Audio / Brightness changes (not by IPC)
// =============================================================================
/**
 * Properties:
 *   - visible: bool [readonly]
 *   - kind: string [readonly] ("volume" | "mic" | "brightness" | "capslock" | "layout")
 *   - icon: string [readonly] (semantic name: "volume-high" | "volume-low" | "volume-off" | "mic" | "mic-off" | "sun")
 *   - label: string [readonly]
 *   - device: string [readonly] (volume: the active output · mic: the active input)
 *   - capsOn: bool [readonly] (capslock: on or just turned off)
 *   - layoutFrom / layoutTo: string [readonly] (layout: "US" → "LA")
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
 * IPC (`qs ipc call osd preview <kind>`): shows an OSD without changing anything ("volume", "mic", "brightness",
 *   "capslock", "capslock-off", "layout"), to check the look.
 *
 * Changes in the first 1.5 s after startup (initial sync) are ignored.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
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
    property string device: ""
    property bool capsOn: false
    property string layoutFrom: ""
    property string layoutTo: ""

    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer {
        id: hideTimer
        interval: Theme.durOsd
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
        target: Keyboard
        function onCapsLockChanged() {
            if (!root._armed) return;
            root.kind = "capslock";
            root.capsOn = Keyboard.capsLock;
            root._present(Keyboard.capsLock ? Theme.durOsd : 800);
        }
        function onLayoutSwitched(from, to) {
            if (!root._armed) return;
            root.kind = "layout";
            root.layoutFrom = from;
            root.layoutTo = to;
            root._present(Theme.durOsdShort);
        }
    }

    function _present(ms: int): void {
        hideTimer.interval = ms;
        root.visible = true;
        hideTimer.restart();
        root.triggered();
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
        root.device = kind === "mic" ? Audio.sourceName : (kind === "volume" ? Audio.sinkName : "");
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
        root._present(Theme.durOsd);
    }

    function dismiss(): void {
        hideTimer.stop();
        root.visible = false;
    }

    signal triggered()

    IpcHandler {
        target: "osd"
        function preview(kind: string): void {
            switch (kind) {
                case "capslock": case "capslock-off":
                    root.kind = "capslock"; root.capsOn = kind === "capslock"; root._present(kind === "capslock" ? Theme.durOsd : 800); break;
                case "layout":
                    root.kind = "layout"; root.layoutFrom = Keyboard.code || "US"; root.layoutTo = Keyboard.code === "LA" ? "US" : "LA"; root._present(Theme.durOsdShort); break;
                case "brightness": root.show("brightness", Brightness.brightnessReal, false); break;
                case "mic": root.show("mic", Audio.micVolume, Audio.micMuted); break;
                default: root.show("volume", Audio.volume, Audio.muted);
            }
        }
    }
}
