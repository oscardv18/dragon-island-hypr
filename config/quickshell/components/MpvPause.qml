// Pauses / resumes one mpvpaper instance through its mpv IPC socket (input-ipc-server, see
// scripts/wallpapers.sh). Connects, writes one JSON command, disconnects. No mpv running = nothing happens.
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property string output: ""
    property string _pending: ""
    readonly property string socketPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/dragon-island-mpv-${output}.sock`

    function setPaused(paused: bool): void {
        root._pending = JSON.stringify({ command: ["set_property", "pause", paused] }) + "\n";
        if (sock.connected) root._send();
        else sock.connected = true;
    }

    function _send(): void {
        if (root._pending.length === 0) return;
        sock.write(root._pending);
        sock.flush();
        root._pending = "";
        closer.restart();
    }

    property Socket _sock: Socket {
        id: sock
        path: root.socketPath
        onConnectedChanged: if (connected) root._send()
        onError: root._pending = ""   // no socket: mpvpaper is not running (images, or not started yet)
    }

    property Timer _closer: Timer { id: closer; interval: 200; onTriggered: sock.connected = false }
}
