// =============================================================================
// dragon-island — Keyboard.qml
// Service: active keyboard layout (kb_layout "us,latam" in config/hypr/input.lua)
// =============================================================================
/**
 * Properties:
 *   - layoutName: string [readonly] (xkb description, e.g. "English (US)", "Spanish (Latin American)")
 *   - code: string [readonly] ("US" | "LA", otherwise the first two letters of the name; "" until known)
 *
 * Functions:
 *   - next(): void   (hyprctl switchxkblayout all next)
 *
 * Follows Hyprland's `activelayout` event (data: "<keyboard>,<layout name>"); the initial value
 * comes from the main keyboard in `hyprctl -j devices`.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string layoutName: ""

    readonly property string code: {
        const n = root.layoutName.toLowerCase();
        if (n.length === 0) return "";
        if (n.includes("latin")) return "LA";
        if (n.includes("(us)")) return "US";
        return root.layoutName.slice(0, 2).toUpperCase();
    }

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(this.text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main && root.layoutName.length === 0) root.layoutName = main.active_keymap ?? "";
                } catch (e) {
                    console.warn(`Keyboard: could not read hyprctl devices: ${e}`);
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            // "<keyboard name>,<layout name>": the layout name may itself contain commas
            const at = event.data.indexOf(",");
            if (at >= 0) root.layoutName = event.data.slice(at + 1);
        }
    }
}
