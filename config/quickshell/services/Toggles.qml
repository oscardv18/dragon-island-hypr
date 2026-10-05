// =============================================================================
// dragon-island — Toggles.qml
// Service: quick toggles for the dashboard (state mirrors the owning services)
// =============================================================================
/**
 * Properties (all readonly mirrors, the owning service is the single source of truth):
 *   - wifi: bool              (Network.wifiEnabled)
 *   - wifiAvailable: bool     (there is a Wi-Fi device)
 *   - bluetooth: bool         (Bluetooth.enabled)
 *   - bluetoothAvailable: bool
 *   - dnd: bool               (Notifs.dnd)
 *   - nightLight: bool        (hyprsunset running, started by us)
 *   - isRecording: bool       (wf-recorder running)
 *   - recordingSeconds: int   (elapsed while recording)
 *
 * Functions:
 *   - toggleWifi(): void
 *   - toggleBluetooth(): void
 *   - toggleDnd(): void
 *   - toggleNightLight(): void
 *   - toggleRecording(): void        (asks for an output/region with slurp, saves to XDG Videos)
 *   - triggerScreenshot(): void      (region screenshot after the shell panels close)
 *
 * Signals:
 *   - toggleChanged(name: string, state: bool)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool wifi: Network.wifiEnabled
    readonly property bool wifiAvailable: Network.hasWifi
    readonly property bool bluetooth: Bluetooth.enabled
    readonly property bool bluetoothAvailable: Bluetooth.adapterAvailable
    readonly property bool dnd: Notifs.dnd
    readonly property bool nightLight: sunsetProc.running
    readonly property bool isRecording: recordProc.running
    property int recordingSeconds: 0

    // Night light: hyprsunset at 4500 K while the process runs
    Process {
        id: sunsetProc
        command: ["hyprsunset", "-t", "4500"]
    }

    // Screen recording: `exec` so SIGINT reaches wf-recorder and it finalizes the file
    Process {
        id: recordProc
        command: ["sh", "-c",
            "dir=$(xdg-user-dir VIDEOS 2>/dev/null); [ -n \"$dir\" ] && [ \"$dir\" != \"$HOME\" ] || dir=\"$HOME/Videos\"; " +
            "mkdir -p \"$dir\"; geom=$(slurp -o -d) || exit 0; " +
            "f=\"$dir/grabacion_$(date +%Y-%m-%d_%H-%M-%S).mp4\"; " +
            "notify-send -a dragon-island 'Grabando pantalla' \"$f\"; exec wf-recorder -g \"$geom\" -f \"$f\""]
        onExited: (code, status) => {
            root.recordingSeconds = 0;
            Quickshell.execDetached(["notify-send", "-a", "dragon-island", "Grabación finalizada", "Guardada en la carpeta Vídeos"]);
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: recordProc.running
        onTriggered: root.recordingSeconds++
    }

    function toggleWifi(): void {
        Network.toggleWifi();
        root.toggleChanged("wifi", !root.wifi);
    }

    function toggleBluetooth(): void {
        Bluetooth.togglePower();
        root.toggleChanged("bluetooth", !root.bluetooth);
    }

    function toggleDnd(): void {
        Notifs.toggleDnd();
        root.toggleChanged("dnd", Notifs.dnd);
    }

    function toggleNightLight(): void {
        sunsetProc.running = !sunsetProc.running;
        root.toggleChanged("nightLight", sunsetProc.running);
    }

    function toggleRecording(): void {
        if (recordProc.running) recordProc.signal(2); // SIGINT
        else recordProc.running = true;
        root.toggleChanged("recording", recordProc.running);
    }

    function triggerScreenshot(): void {
        // small delay so the dashboard/scrim are gone before slurp draws
        Quickshell.execDetached(["sh", "-c", "sleep 0.4; grimblast --notify copysave area"]);
    }

    signal toggleChanged(name: string, state: bool)
}
