// =============================================================================
// dragon-island — Dropdown.qml
// Service: the drop-down terminal (docs/design/24-desplegable.png). bin/dragon-dropdown starts / toggles it.
// =============================================================================
/**
 * One Ghostty of class org.dragonisland.Dropdown in special:dropdown (config/hypr/rules.lua). When that special
 * workspace becomes visible (`activespecial` event) the island turns into the terminal's lid (island state
 * "dropdown"): as wide as the terminal, its bottom edge on the terminal's top edge; this service moves / resizes the
 * window so that its top edge sits exactly under the island in the current bar style and size.
 * The window is left out of the dock (Dock.qml) and never on a numbered workspace (the constellation).
 *
 * Properties:
 *   - windowClass: string [readonly] ("org.dragonisland.Dropdown")
 *   - shown: bool [readonly] (island state "dropdown")
 *   - screenName: string [readonly] (monitor where it is shown)
 *   - width / height: real [readonly] (69 % × 55 % of that monitor)
 *   - top: real [readonly] (y of the island's bottom edge = the terminal's top edge, monitor coordinates)
 *
 * Functions:
 *   - toggle(): void (runs bin/dragon-dropdown)
 */
pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string windowClass: "org.dragonisland.Dropdown"
    property bool shown: false
    property string screenName: ""
    readonly property var _mon: Hyprland.monitors.values.find(m => m.name === root.screenName) ?? Hyprland.focusedMonitor
    readonly property real width: Math.round((_mon?.width ?? 1366) / (_mon?.scale ?? 1) * 0.69)
    readonly property real height: Math.round((_mon?.height ?? 768) / (_mon?.scale ?? 1) * 0.55)
    readonly property real top: Theme.notchAttached ? Theme.notchHeight : Theme.notchTop + Theme.notchHeight

    function toggle(): void { Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/dragon-dropdown`]); }

    function _place(): void {
        const m = root._mon;
        if (!m) return;
        const w = root.width, h = root.height;
        const x = m.x + Math.round((m.width / (m.scale || 1) - w) / 2), y = m.y + root.top;
        const sel = `class:^${root.windowClass.replace(/\./g, "\\\\.")}$`;
        Hyprland.dispatch(`hl.dsp.window.resize({ x = ${w}, y = ${h}, relative = false, window = "${sel}" })`);
        Hyprland.dispatch(`hl.dsp.window.move({ x = ${x}, y = ${y}, relative = false, window = "${sel}" })`);
    }

    // "special:dropdown,eDP-1" when it shows on a monitor, ",eDP-1" when that monitor's special workspace closes
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name !== "activespecial") return;
            const at = e.data.lastIndexOf(",");
            const ws = e.data.slice(0, at), mon = e.data.slice(at + 1);
            if (ws === "special:dropdown") { root.screenName = mon; root.shown = true; placeTimer.restart(); }
            else if (mon === root.screenName) root.shown = false;
        }
    }
    // the window may still be mapping when the event arrives; placing twice is harmless
    Timer { id: placeTimer; interval: 60; onTriggered: { root._place(); placeAgain.restart(); } }
    Timer { id: placeAgain; interval: 250; onTriggered: root._place() }
    // the bar style / size changed while it is shown: the island's bottom moved
    onTopChanged: if (shown) _place()
}
