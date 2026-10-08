// =============================================================================
// dragon-island — BottomIslands.qml
// The two hidden islands at the sides of the dock (right: apps in the background · left: herdr / AI work).
// They exist only while the pointer is in their strip at the bottom edge — see BottomWindow.qml and HoverReveal.qml.
// One BottomWindow per monitor; the monitors are independent.
//
// IPC (`qs ipc call bottomislands <fn> <side>`), for tests and accessibility only — nothing is bound to a key:
//   reveal(side: string) / hide(side: string) / toggle(side: string)   side = left | right | both
//   state(): string   one line per monitor, e.g. "DP-1 left=hidden right=shown"
// =============================================================================
import Quickshell
import Quickshell.Io
import QtQuick
import "../.."
import "../../services"

Scope {
    id: root

    Variants {
        id: windows
        model: Quickshell.screens
        delegate: Component { BottomWindow {} }
    }

    function _all(action: string, side: string): void {
        for (const w of windows.instances) w.command(action, side);
    }

    IpcHandler {
        target: "bottomislands"
        function reveal(side: string): void { root._all("reveal", side); }
        function hide(side: string): void { root._all("hide", side); }
        function toggle(side: string): void { root._all("toggle", side); }
        function state(): string {
            return windows.instances.map(w => `${w.screenName} right=${w.rightPhase}`).join("\n");
        }
    }
}
