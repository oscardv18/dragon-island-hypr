// Launcher.qml — Quickshell wrapper around LauncherView (orbital launcher on the neural core)
//
// REFERENCE IMPLEMENTATION, not yet run inside Quickshell (LauncherView itself is render-tested).
// Wire it to the project's existing pieces:
//   - open state:  ShellState.openPanel === "launcher"  (adapt if ShellState differs)
//   - app list:    replace `entries` with the existing Apps service (frecency ranking, pinned, install-panel hook)
//   - launching:   DesktopEntry.execute() ignores terminal apps & field codes → use the project's launch helper if it has one

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property bool wantOpen: ShellState.openPanel === "launcher"

    // [{ id, name, subtitle, icon }] — same shape LauncherView expects
    readonly property var entries: {
        const out = []
        const list = DesktopEntries.applications.values
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            if (e.noDisplay) continue
            out.push({
                id: e.id,
                name: e.name,
                subtitle: e.genericName || e.comment || "",
                icon: e.icon ? Quickshell.iconPath(e.icon, "application-x-executable") : ""
            })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))   // TODO: frecency order from services/Apps
        return out
    }

    function launch(id) {
        const list = DesktopEntries.applications.values
        for (let i = 0; i < list.length; i++) if (list[i].id === id) { list[i].execute(); break }
        ShellState.openPanel = ""
    }

    PanelWindow {
        id: win
        // follow the focused monitor
        screen: {
            const m = Hyprland.focusedMonitor
            return Quickshell.screens.find(s => m && s.name === m.name) ?? Quickshell.screens[0]
        }
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        visible: root.wantOpen || !view.settled
        WlrLayershell.namespace: "dragon-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wantOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LauncherView {
            id: view
            anchors.fill: parent
            apps: root.entries
            open: root.wantOpen
            onActivated: id => root.launch(id)
            onCloseRequested: ShellState.openPanel = ""
            Component.onCompleted: if (root.wantOpen) focusInput()
        }
    }
}
