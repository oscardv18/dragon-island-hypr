// =============================================================================
// dragon-island — Toggles.qml
// Service: Quick System Toggles (Wi-Fi, Bluetooth, DND, Night Light, Record)
// =============================================================================
/**
 * Properties:
 *   - wifi: bool
 *   - bluetooth: bool
 *   - dnd: bool
 *   - nightLight: bool
 *   - isRecording: bool
 *
 * Functions:
 *   - toggleWifi(): void
 *   - toggleBluetooth(): void
 *   - toggleDnd(): void
 *   - toggleNightLight(): void
 *   - toggleRecording(): void
 *   - triggerScreenshot(): void
 *
 * Signals:
 *   - toggleChanged(name: string, state: bool)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "."

Singleton {
    id: root

    property bool wifi: Network.wifiEnabled
    property bool bluetooth: Bluetooth.enabled
    property bool dnd: Notifs.dnd
    property bool nightLight: false
    property bool isRecording: false

    // Night light process via hyprsunset
    Process {
        id: sunsetProc
        command: ["hyprsunset", "-t", "4500"]
    }

    // Screen recording process via wf-recorder
    Process {
        id: recordProc
        onStarted: root.isRecording = true
        onExited: root.isRecording = false
    }

    function toggleWifi(): void {
        Network.toggleWifi();
        root.wifi = Network.wifiEnabled;
        root.toggleChanged("wifi", root.wifi);
    }

    function toggleBluetooth(): void {
        Bluetooth.togglePower();
        root.bluetooth = Bluetooth.enabled;
        root.toggleChanged("bluetooth", root.bluetooth);
    }

    function toggleDnd(): void {
        Notifs.toggleDnd();
        root.dnd = Notifs.dnd;
        root.toggleChanged("dnd", root.dnd);
    }

    function toggleNightLight(): void {
        root.nightLight = !root.nightLight;
        if (root.nightLight) {
            sunsetProc.running = true;
        } else {
            sunsetProc.running = false;
        }
        root.toggleChanged("nightLight", root.nightLight);
    }

    function toggleRecording(): void {
        if (recordProc.running) {
            recordProc.signal(2); // SIGINT
        } else {
            const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
            recordProc.exec(["sh", "-c", `wf-recorder -f ~/Videos/recording_${timestamp}.mp4`]);
        }
    }

    function triggerScreenshot(): void {
        Quickshell.execDetached(["grimblast", "--notify", "copysave", "area"]);
    }

    signal toggleChanged(name: string, state: bool)
}
