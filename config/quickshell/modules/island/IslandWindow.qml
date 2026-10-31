// =============================================================================
// dragon-island — IslandWindow.qml
// The notch's overlay (namespace "dragon-island"): one per monitor, anchored to the top edge, as wide
// as the screen but only as tall as the expanded notch. exclusionMode Ignore, so it never moves windows.
//   mask = the notch shape only → the rest of the screen lets clicks through.
//   expanded (SUPER+D / click): HyprlandFocusGrab closes it on a click outside, Esc closes it too.
// Popovers, the launcher and notification popups live in their own windows (own namespaces).
// =============================================================================
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.notchWindowHeight
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-island"
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool expanded: ShellState.isOpenOn("dashboard", screenName)

    // hide the collapsed notch over fullscreen windows, except while it shows the OSD
    readonly property bool hidden: Hypr.fullscreenOn(screen) && !expanded && IslandState.mode !== "osd"

    // the notch shape, plus (style D, collapsed) the 3 px hot edge between the bar islands
    mask: Region {
        item: win.hidden ? null : notch.shapeItem
        Region { item: edgeStrip }
    }

    Item {
        id: edgeStrip
        readonly property bool armed: Theme.barStyle === "D" && !win.expanded   // stays while revealed: no flicker at y < 3
        x: BarMetrics.minX(win.screenName) - Theme.notchGap
        width: armed ? Math.max(0, BarMetrics.maxX(win.screenName) + Theme.notchGap - x) : 0
        height: Theme.barEdge
        HoverHandler { onHoveredChanged: BarState.hover("edge", hovered) }
    }

    // the idle sequence waits while an agent works, the recording mode is on or a video plays (services/Idle.qml)
    IdleInhibitor {
        window: win
        enabled: Idle.inhibit
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.expanded
        onCleared: if (win.expanded) ShellState.close()
    }

    // Escape closes the expanded notch
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    // notification drops (services/NotifFx.qml): this window is the only one spanning the notch and the cards
    NotifDrops {
        anchors.fill: parent
        screenName: win.screenName
        fromX: notch.shapeItem.x + notch.shapeItem.width / 2
        fromY: notch.shapeItem.y + notch.shapeItem.height
        visible: !win.hidden
        z: 1
    }

    Notch {
        id: notch
        anchors.fill: parent
        screenName: win.screenName
        open: win.expanded
        hidden: win.hidden
    }
}
