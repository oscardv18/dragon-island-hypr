// =============================================================================
// dragon-island — Hypr.qml
// Service: Hyprland compositor state & dispatch (Lua dispatcher syntax on 0.55+)
// =============================================================================
/**
 * Properties:
 *   - usingLua: bool [readonly]
 *   - focusedWorkspaceId: int [readonly]
 *   - focusedMonitorName: string [readonly]
 *   - activeTitle: string [readonly]
 *   - activeClass: string [readonly] (Wayland app id, falls back to the X11/IPC class)
 *   - activeIcon: string [readonly] (image source for the active app, "" if none)
 *   - hasActiveWindow: bool [readonly]
 *   - workspaceCount: int [readonly] (numbered pills shown in the bar, 5)
 *   - workspaces: list<var> [readonly] (1..5: { id, name, active, occupied, urgent, windows, visible })
 *       active  = focused workspace; visible = shown on some monitor (multi-monitor)
 *   - monitors: ObjectModel<HyprlandMonitor> [readonly]
 *
 * Functions:
 *   - focusWorkspace(id: int): void
 *   - focusRelative(delta: int): void (next/previous existing workspace, mouse wheel)
 *   - fullscreenOn(screen): bool      (active workspace of that monitor has a fullscreen window)
 *   - moveWindowToWorkspace(id: int): void
 *   - closeActiveWindow(): void
 *   - toggleFullscreen(): void
 *   - toggleFloat(): void
 *   - dispatch(cmd: string): void
 *   - monitorFor(screen): HyprlandMonitor
 *   - refresh(): void
 *
 * Signals:
 *   - workspaceChanged(id: int)
 *   - activeWindowChanged(title: string, appClass: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool usingLua: Hyprland.usingLua
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""

    // Hyprland.activeToplevel is a HyprlandToplevel: title is native, the app id lives on its Wayland handle
    readonly property var activeToplevel: Hyprland.activeToplevel
    readonly property bool hasActiveWindow: activeToplevel !== null && activeToplevel !== undefined
    readonly property string activeTitle: activeToplevel?.title ?? ""
    readonly property string activeClass: activeToplevel?.wayland?.appId || activeToplevel?.lastIpcObject?.class || ""
    readonly property string activeIcon: {
        if (activeClass.length === 0) return "";
        const entry = DesktopEntries.heuristicLookup(activeClass);
        return Quickshell.iconPath(entry?.icon || activeClass.toLowerCase(), "application-x-executable");
    }

    readonly property int workspaceCount: 5

    readonly property var workspaces: {
        const list = [];
        const all = Hyprland.workspaces.values;
        for (let i = 1; i <= root.workspaceCount; i++) {
            const ws = all.find(w => w.id === i) ?? null;
            const windows = ws ? ws.toplevels.values.length : 0;
            list.push({
                id: i,
                name: ws ? ws.name : `${i}`,
                active: root.focusedWorkspaceId === i,
                visible: ws ? ws.active : false,
                occupied: windows > 0,
                urgent: ws ? ws.urgent : false,
                windows: windows
            });
        }
        return list;
    }

    readonly property var monitors: Hyprland.monitors

    function dispatch(command: string): void {
        Hyprland.dispatch(command);
    }

    function focusWorkspace(id: int): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.focus({ workspace = ${id} })` : `workspace ${id}`);
    }

    function focusRelative(delta: int): void {
        const target = delta > 0 ? "e+1" : "e-1";
        Hyprland.dispatch(root.usingLua ? `hl.dsp.focus({ workspace = "${target}" })` : `workspace ${target}`);
    }

    function fullscreenOn(screen): bool {
        const mon = screen ? Hyprland.monitorFor(screen) : null;
        return mon?.activeWorkspace?.hasFullscreen ?? false;
    }

    function moveWindowToWorkspace(id: int): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.window.move({ workspace = ${id} })` : `movetoworkspace ${id}`);
    }

    function closeActiveWindow(): void {
        Hyprland.dispatch(root.usingLua ? "hl.dsp.window.close()" : "killactive");
    }

    function toggleFullscreen(): void {
        Hyprland.dispatch(root.usingLua ? 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })' : "fullscreen 1");
    }

    function toggleFloat(): void {
        Hyprland.dispatch(root.usingLua ? 'hl.dsp.window.float({ action = "toggle" })' : "togglefloating");
    }

    function monitorFor(screen): var {
        return screen ? Hyprland.monitorFor(screen) : null;
    }

    function refresh(): void {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    signal workspaceChanged(id: int)
    signal activeWindowChanged(title: string, appClass: string)

    onFocusedWorkspaceIdChanged: root.workspaceChanged(root.focusedWorkspaceId)
    onActiveTitleChanged: root.activeWindowChanged(root.activeTitle, root.activeClass)
}
