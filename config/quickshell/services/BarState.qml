// =============================================================================
// dragon-island — BarState.qml
// Service: live state of the bar that several windows share (bar islands, C strip, notch).
// =============================================================================
/**
 * Style D (minimal) shows the full style B while the pointer is on the 3 px hot edge, on a bar island or on the
 * notch; every window that can be hovered reports it here. A short delay bridges the move from one surface to the
 * next (edge → island), so the bar never flickers. Each surface holds its own hot strip (§7x of the HANDOFF).
 * barAutohide (styles A / B / C): the bar dims to Theme.barDimOpacity over a maximized window of the focused
 * workspace and comes back while hovered.
 *
 * Properties:
 *   - hovered: bool [readonly] (the pointer is on some part of the bar, the hot edge included)
 *   - revealed: bool [readonly] (style D is showing style B right now; shell.qml binds Theme.barRevealed to it)
 *
 * Functions:
 *   - hover(source: string, on: bool): void (source: "edge" | "left" | "right" | "strip" | "notch")
 *   - dimmedOn(screen): bool (barAutohide is on, a maximized window covers that monitor's workspace, not hovered)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property var _hovers: ({})
    readonly property bool _anyHover: Object.keys(_hovers).some(k => _hovers[k])

    function hover(source: string, on: bool): void {
        if (!!root._hovers[source] === on) return;
        const h = Object.assign({}, root._hovers);
        h[source] = on;
        root._hovers = h;
    }

    // a short grace period after the pointer leaves (moving from one bar surface to another)
    property bool hovered: false
    on_AnyHoverChanged: {
        if (_anyHover) { leaveTimer.stop(); root.hovered = true; }
        else leaveTimer.restart();
    }
    Timer { id: leaveTimer; interval: 450; onTriggered: root.hovered = false }

    // a popover opened from the revealed bar keeps it revealed until it closes
    property bool _sticky: false
    readonly property bool revealed: Settings.barStyle === "D" && (hovered || _sticky)
    onRevealedChanged: if (!revealed) _sticky = false
    Connections {
        target: ShellState
        function onOpenPanelChanged() { root._sticky = root.revealed && ShellState.anyOpen; }
    }

    function dimmedOn(screen): bool {
        return Settings.barAutohide && Settings.barStyle !== "D" && !root.hovered && !ShellState.anyOpen && Hypr.fullscreenOn(screen);
    }
}
