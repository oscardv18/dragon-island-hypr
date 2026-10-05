// =============================================================================
// dragon-island — ShellState.qml (global UI state & IPC target "shell")
// Exactly one panel is open at a time; everything opens/closes through here.
// =============================================================================
/**
 * Properties:
 *   - openPanel: string [readonly] ("none" or one of `panels`)
 *   - panelScreen: string [readonly] (monitor name where the panel opens; "" = focused monitor)
 *   - panels: list<string> [readonly]
 *   - anyOpen: bool [readonly]
 *
 * Functions:
 *   - toggle(name: string, screenName: string = ""): void
 *   - open(name: string, screenName: string = ""): void
 *   - close(): void
 *   - current(): string
 *   - isOpenOn(name: string, screenName: string): bool (true if `name` is open on that monitor)
 *
 * IPC (`qs ipc call shell <fn>`): toggle(name), open(name), close(), current()
 * IPC calls open the panel on the focused Hyprland monitor.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property var panels: ["dashboard", "perf", "wifi", "bt", "audio", "battery", "notifications", "calendar", "launcher", "power"]

    property string openPanel: "none"
    property string panelScreen: ""
    readonly property bool anyOpen: openPanel !== "none"

    function _valid(name: string): bool {
        if (panels.indexOf(name) >= 0) return true;
        console.warn(`ShellState: unknown panel "${name}"`);
        return false;
    }

    function open(name: string, screenName): void {
        if (!_valid(name)) return;
        root.panelScreen = screenName || Hyprland.focusedMonitor?.name || "";
        root.openPanel = name;
    }

    function toggle(name: string, screenName): void {
        const scr = screenName || Hyprland.focusedMonitor?.name || "";
        if (root.openPanel === name && (root.panelScreen === scr || root.panelScreen === "")) root.close();
        else root.open(name, scr);
    }

    function close(): void {
        root.openPanel = "none";
    }

    function current(): string {
        return root.openPanel;
    }

    function isOpenOn(name: string, screenName: string): bool {
        return root.openPanel === name && (root.panelScreen === "" || root.panelScreen === screenName);
    }

    // Types MUST be annotated or the functions are not registered (check with `qs ipc show`)
    IpcHandler {
        target: "shell"
        function toggle(name: string): void { root.toggle(name, ""); }
        function open(name: string): void { root.open(name, ""); }
        function close(): void { root.close(); }
        function current(): string { return root.current(); }
    }
}
