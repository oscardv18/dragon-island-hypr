// =============================================================================
// dragon-island — Tiling.qml
// Service: tiling mode of the focused workspace (dwindle ↔ scrolling) — the work is done by scripts/tiling.sh
// =============================================================================
/**
 * The mode is a per-workspace Hyprland rule saved in ~/.local/state/dragon-island/tiling.json (see scripts/tiling.sh,
 * installed as ~/.local/bin/dragon-tiling). This service only reads it (`dragon-tiling get --json`) when Hyprland says the
 * focus may have changed (workspace / focusedmon / activewindow raw events, debounced) and at start — no polling.
 *
 * Properties:
 *   - mode: string [readonly] ("dwindle" | "scrolling"; "dwindle" until known)
 *   - workspace: string [readonly] (name of the focused workspace the mode belongs to)
 *   - scrolling: bool [readonly]
 *   - label: string [readonly] ("DWINDLE" | "SCROLL")   notice: string [readonly] ("Modo dwindle" | "Modo scroll")
 *   - shortcut: string [readonly] ("SUPER + T", for tooltips)
 *
 * Functions:
 *   - toggle(): void    set(mode: string): void    refresh(): void
 *
 * Signals:
 *   - changed(string mode): the mode of the SAME workspace changed (not a workspace switch) → the notch shows a notice
 *
 * IPC (`qs ipc call tiling <fn>`): toggle(), set(mode: string), get(): string, refresh()
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property string bin: `${Quickshell.env("HOME")}/.local/bin/dragon-tiling`
    readonly property string shortcut: "SUPER + T"

    property string mode: "dwindle"
    property string workspace: ""
    readonly property bool scrolling: mode === "scrolling"
    readonly property string label: scrolling ? "SCROLL" : "DWINDLE"
    readonly property string notice: scrolling ? "Modo scroll" : "Modo dwindle"

    signal changed(string mode)

    function refresh(): void { debounce.restart(); }
    function toggle(): void { run.command = [root.bin, "toggle"]; run.running = true; }
    function set(m: string): void {
        if (m !== "dwindle" && m !== "scrolling") return;
        run.command = [root.bin, "set", m];
        run.running = true;
    }

    Timer { id: debounce; interval: 80; onTriggered: if (!reader.running) reader.running = true; else debounce.restart() }

    Process { id: run }    // the script asks us to refresh itself when it is done

    Process {
        id: reader
        command: [root.bin, "get", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try { d = JSON.parse(text); } catch (e) { return; }
                if (d.mode !== "dwindle" && d.mode !== "scrolling") return;
                const sameWs = d.workspace === root.workspace;
                const was = root.mode;
                root.workspace = d.workspace;
                root.mode = d.mode;
                if (sameWs && was !== d.mode && root._armed) root.changed(d.mode);
            }
        }
    }

    property bool _armed: false
    Timer { running: true; interval: 2000; onTriggered: root._armed = true }
    Component.onCompleted: reader.running = true

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2" || event.name === "focusedmon" || event.name === "activewindow")
                root.refresh();
        }
    }

    IpcHandler {
        target: "tiling"
        function toggle(): void { root.toggle(); }
        function set(mode: string): void { root.set(mode); }
        function get(): string { return root.mode; }
        function refresh(): void { root.refresh(); }
    }
}
