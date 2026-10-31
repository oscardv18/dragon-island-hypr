// =============================================================================
// dragon-island — Overview.qml
// Service: the workspaces overview, SUPER + Tab (docs/design/11-escritorios.png)
// =============================================================================
/**
 * The overview is the ShellState panel "overview" (one panel at a time, the scrim behind it); this service holds its
 * keyboard choice and the actions, the window (modules/overview/) only draws.
 *
 * Properties:
 *   - shown: bool [readonly]
 *   - selected: int [readonly] (1–5: the card the keyboard is on; starts on the focused workspace)
 *   - wallpaper: string [readonly] (file URL of the current wallpaper frame, the background of every card)
 *
 * Functions:
 *   - toggle(): void   open(): void   close(): void
 *   - select(ws: int): void   step(delta: int): void
 *   - go(ws: int): void (focus that workspace and close)
 *   - move(address: string, ws: int): void (that window to workspace ws without following it: movetoworkspacesilent)
 *
 * IPC (`qs ipc call overview <fn>`): toggle(), open(), close()
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property bool shown: ShellState.openPanel === "overview"
    property int selected: 1
    readonly property string wallpaper: `file://${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/dragon-island/current-wallpaper`

    function open(): void {
        Hypr.refresh();                    // fresh geometry (hyprctl clients) for the window rectangles
        root.selected = Math.max(1, Math.min(Hypr.workspaceCount, Hypr.focusedWorkspaceId));
        ShellState.open("overview", "");
    }
    function close(): void { if (root.shown) ShellState.close(); }
    function toggle(): void { if (root.shown) root.close(); else root.open(); }

    function select(ws: int): void { root.selected = Math.max(1, Math.min(Hypr.workspaceCount, ws)); }
    function step(delta: int): void { root.select(root.selected + delta); }

    function go(ws: int): void {
        root.close();
        Hypr.focusWorkspace(ws);
    }

    function move(address: string, ws: int): void {
        if (!address || ws < 1) return;
        Hypr.moveWindowSilent(address, ws);
        refreshLater.restart();
    }
    // the moved window's new place shows once Hyprland has done it
    Timer { id: refreshLater; interval: 120; onTriggered: Hypr.refresh() }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
}
