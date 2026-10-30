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
 *   - startRecording(geometry: string): void (records that area, "x,y wxh", without slurp: the capture bar's ●)
 *   - triggerScreenshot(): void      (opens the capture bar of the island)
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

    // Screen recording: `exec` so SIGINT reaches wf-recorder and it finalizes the file. $1 = a geometry from the capture
    // bar; empty = ask with slurp
    property string _recordGeom: ""
    Process {
        id: recordProc
        command: ["sh", "-c",
            "dir=$(xdg-user-dir VIDEOS 2>/dev/null); [ -n \"$dir\" ] && [ \"$dir\" != \"$HOME\" ] || dir=\"$HOME/Videos\"; " +
            "mkdir -p \"$dir\"; geom=\"$1\"; [ -n \"$geom\" ] || geom=$(slurp -o -d) || exit 0; " +
            "f=\"$dir/grabacion_$(date +%Y-%m-%d_%H-%M-%S).mp4\"; " +
            "notify-send -a dragon-island 'Grabando pantalla' \"$f\"; exec wf-recorder -g \"$geom\" -f \"$f\"", "sh", root._recordGeom]
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
        // SIGINT to wf-recorder finalizes the file; while the output picker (slurp) is still open the shell is
        // waiting on it and would ignore the signal, so slurp is closed too
        if (recordProc.running) Quickshell.execDetached(["sh", "-c", "pkill -INT -x wf-recorder; pkill -x slurp"]);
        else { root._recordGeom = ""; recordProc.running = true; }
        root.toggleChanged("recording", recordProc.running);
    }

    function startRecording(geometry: string): void {
        if (recordProc.running) return;
        root._recordGeom = geometry;
        recordProc.running = true;
        root.toggleChanged("recording", true);
    }

    // the capture bar of the island (services/Capture.qml closes the open panel first)
    function triggerScreenshot(): void { Capture.open("region"); }

    signal toggleChanged(name: string, state: bool)

    // `qs ipc call toggles record` starts / stops the screen recording (SUPER + SHIFT + R); while recording the
    // bar shows a pulsing capsule with the elapsed time, click it to stop
    IpcHandler {
        target: "toggles"
        function record(): void { root.toggleRecording(); }
        function recording(): bool { return root.isRecording; }
    }
}
