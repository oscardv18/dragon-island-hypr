// =============================================================================
// dragon-island — Hypr.qml
// Service: Hyprland Compositor State & IPC
// =============================================================================
/**
 * Properties:
 *   - usingLua: bool [readonly]
 *   - focusedWorkspaceId: int [readonly]
 *   - focusedWorkspaceName: string [readonly]
 *   - activeTitle: string [readonly]
 *   - activeClass: string [readonly]
 *   - workspaces: list<var> [readonly] (workspaces 1-5 metadata: id, name, active, occupied, urgent)
 *   - monitors: ObjectModel<HyprlandMonitor> [readonly]
 *
 * Functions:
 *   - focusWorkspace(id: int): void
 *   - moveWindowToWorkspace(id: int): void
 *   - closeActiveWindow(): void
 *   - toggleFullscreen(): void
 *   - toggleFloat(): void
 *   - dispatch(cmd: string): void
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
    readonly property string focusedWorkspaceName: Hyprland.focusedWorkspace?.name ?? "1"

    readonly property string activeTitle: Hyprland.activeToplevel?.title ?? ""
    readonly property string activeClass: Hyprland.activeToplevel?.appId ?? ""

    // Workspaces 1..5 representation for island & bar pills
    readonly property var workspaces: {
        const list = [];
        const currentActive = root.focusedWorkspaceId;
        const allWs = Hyprland.workspaces.values;
        for (let i = 1; i <= 5; i++) {
            const found = allWs.find(w => w.id === i);
            list.push({
                id: i,
                name: found ? found.name : `${i}`,
                active: (currentActive === i),
                occupied: (found !== undefined && found !== null),
                urgent: found ? found.urgent : false
            });
        }
        return list;
    }

    readonly property var monitors: Hyprland.monitors

    function dispatch(command: string): void {
        Hyprland.dispatch(command);
    }

    function focusWorkspace(id: int): void {
        if (root.usingLua) {
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
        } else {
            Hyprland.dispatch(`workspace ${id}`);
        }
    }

    function moveWindowToWorkspace(id: int): void {
        if (root.usingLua) {
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${id}" })`);
        } else {
            Hyprland.dispatch(`movetoworkspace ${id}`);
        }
    }

    function closeActiveWindow(): void {
        if (root.usingLua) {
            Hyprland.dispatch("hl.dsp.window.close()");
        } else {
            Hyprland.dispatch("killactive");
        }
    }

    function toggleFullscreen(): void {
        if (root.usingLua) {
            Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })');
        } else {
            Hyprland.dispatch("fullscreen 1");
        }
    }

    function toggleFloat(): void {
        if (root.usingLua) {
            Hyprland.dispatch('hl.dsp.window.float({ action = "toggle" })');
        } else {
            Hyprland.dispatch("togglefloating");
        }
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
