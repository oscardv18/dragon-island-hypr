// =============================================================================
// dragon-island — ShellState.qml (Global State & IPC Target "shell")
// Controls panel visibility, popover states and keybind IPC handlers.
// =============================================================================
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Active panel state ("none" when closed)
    // Panels: "none", "dashboard", "perf", "wifi", "bt", "audio", "battery", "notifications", "calendar", "launcher", "power"
    property string openPanel: "none"

    // Toggle specific panel
    function toggle(name: string): void {
        openPanel = (openPanel === name) ? "none" : name;
    }

    // Open specific panel explicitly
    function open(name: string): void {
        openPanel = name;
    }

    // Close any open panel
    function close(): void {
        openPanel = "none";
    }

    // Query current open panel
    function current(): string {
        return openPanel;
    }

    // IPC interface for hyprland keybindings (`qs ipc call shell ...`)
    // NOTE: All arguments and return types must be explicitly annotated for Quickshell IPC registration.
    IpcHandler {
        target: "shell"

        function toggle(name: string): void {
            root.toggle(name);
        }

        function open(name: string): void {
            root.open(name);
        }

        function close(): void {
            root.close();
        }

        function current(): string {
            return root.current();
        }
    }
}
