// =============================================================================
// dragon-island — Bar.qml
// The top bar in one of four styles (Settings.barStyle → Theme.barStyle / Theme.barLook, see Theme "Bar"):
//   A / B / D  two side islands, each its own layer window (namespace "dragon-bar"), fully transparent (alpha 0)
//              around the rounded island: hyprglass masks by alpha (mask_mode = "alpha"), so the glass has the
//              island's rounded corners and the gaps between islands stay clean (one blur region per window, §7e).
//   C          one edge-to-edge glass strip in ONE window holding both islands' content (a single shape, so it
//              is still one region per window); the side windows are unmapped meanwhile.
// Every window keeps a CONSTANT size whatever the style (Theme.barWindowHeight; the islands are placed inside
// with y): resizing a layer surface is a compositor round trip and lagged behind the animation (§7r). Switching
// styles maps / unmaps windows and changes the reserved space, nothing else.
// A 1 px transparent window ("dragon-bar-zone") only reserves the bar's space (Theme.barZone: 31 / 32 / 24 / 18)
// so tiled windows start below it; it has an empty input mask and no blur.
// Style D: each window holds its own 3 px hot strip at the top edge (in its input mask, §7x); hovering it, an
// island or the notch reveals style B (BarState.revealed) without changing the reserved space.
// barAutohide (A / B / C): over a maximized window the islands dim to Theme.barDimOpacity until hovered.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../../components"

Scope {
    id: bar

    property var modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property real screenWidth: modelData?.width ?? 0
    readonly property bool joined: Theme.barStyle === "C"
    readonly property real contentOpacity: BarState.dimmedOn(modelData) ? Theme.barDimOpacity : 1

    // Popover under a capsule. `item` is the capsule, `windowX` the screen x of the island's window, `side`
    // "right" (right island: popover's right edge on the capsule's right edge) or "left" (left edges).
    // mapToItem(null, …) is relative to the capsule's own window, hence + windowX for screen coordinates.
    function openFrom(name: string, item, side: string, windowX: real): void {
        const x = side === "left" ? item.mapToItem(null, 0, 0).x : item.mapToItem(null, item.width, 0).x;
        ShellState.toggleAt(name, bar.screenName, x + windowX, side);
    }

    function isOpen(name: string): bool {
        return ShellState.openPanel === name && ShellState.panelScreen === bar.screenName;
    }

    // Tell the notch where the islands end (screen x)
    readonly property real leftEnd: joined ? stripLeft.x + stripLeft.width : leftWindow.screenX + leftIsland.width
    readonly property real rightStart: joined ? stripRight.x : bar.screenWidth - Theme.barMarginSide - rightIsland.width
    onLeftEndChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    onRightStartChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    Component.onCompleted: BarMetrics.report(screenName, leftEnd, rightStart)

    // ---- reserves the bar's space (nothing is drawn, nothing is clickable) ----
    PanelWindow {
        screen: bar.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 1
        exclusiveZone: Theme.barZone
        color: Theme.transparent
        mask: Region {}
        WlrLayershell.namespace: "dragon-bar-zone"
        WlrLayershell.layer: WlrLayer.Top
    }

    // ---- side islands (A, B, D) ----
    // The island windows keep a CONSTANT size (the most their island can ever need) and are transparent around it:
    // the input mask is the island itself (plus the D hot strip), and hyprglass takes its shape from the alpha,
    // so the empty part of the window costs nothing and shows nothing.
    readonly property real leftWindowWidth: Math.max(1, (bar.screenWidth - Theme.barMarginSide * 2) / 2 - Theme.notchReserve / 2 - Theme.barIslandGap)
    readonly property real rightWindowWidth: Math.max(1, Math.round(bar.screenWidth * 0.47))

    PanelWindow {
        id: leftWindow
        screen: bar.modelData
        visible: !bar.joined
        readonly property real screenX: Theme.barMarginSide

        anchors { top: true; left: true }
        margins { left: Theme.barMarginSide }
        implicitWidth: bar.leftWindowWidth
        implicitHeight: Theme.barWindowHeight
        mask: Region {
            item: leftIsland
            Region { item: leftEdge }
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparent

        WlrLayershell.namespace: "dragon-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Caffeine: keeps the session from going idle (hypridle / screen off) while enabled
        IdleInhibitor {
            window: leftWindow
            enabled: Caffeine.enabled && leftWindow.visible
        }

        EdgeStrip { id: leftEdge; source: "edge-left" }

        GlassShadow {
            x: leftIsland.x; y: leftIsland.y; width: leftIsland.width; height: leftIsland.height
            radius: leftIsland.radius
            blur: Theme.glassShadowBlurSm
            opacity: leftIsland.opacity
        }

        LeftIsland {
            id: leftIsland
            bar: bar
            y: Theme.barMarginTop
            windowX: leftWindow.screenX
            live: !bar.joined
            opacity: bar.contentOpacity
            // never reach the centre, where the collapsed notch sits
            maxWidth: Math.max(0, (bar.screenWidth - Theme.barMarginSide * 2) / 2 - Theme.notchReserve / 2 - Theme.barIslandGap)
            HoverHandler { onHoveredChanged: BarState.hover("left", hovered) }
        }
    }

    PanelWindow {
        id: rightWindow
        screen: bar.modelData
        visible: !bar.joined
        readonly property real screenX: bar.screenWidth - Theme.barMarginSide - bar.rightWindowWidth

        anchors { top: true; right: true }
        margins { right: Theme.barMarginSide }
        implicitWidth: bar.rightWindowWidth
        implicitHeight: Theme.barWindowHeight
        mask: Region {
            item: rightIsland
            Region { item: rightEdge }
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparent

        WlrLayershell.namespace: "dragon-bar"
        WlrLayershell.layer: WlrLayer.Top

        EdgeStrip { id: rightEdge; source: "edge-right" }

        GlassShadow {
            x: rightIsland.x; y: rightIsland.y; width: rightIsland.width; height: rightIsland.height
            radius: rightIsland.radius
            blur: Theme.glassShadowBlurSm
            opacity: rightIsland.opacity
        }

        RightIsland {
            id: rightIsland
            bar: bar
            y: Theme.barMarginTop
            anchors.right: parent.right
            windowX: rightWindow.screenX
            opacity: bar.contentOpacity
            // the room the left island and the collapsed notch leave it
            maxWidth: Math.max(0, bar.screenWidth - Theme.barMarginSide * 2 - leftIsland.width - Theme.notchSideReserve)
            HoverHandler { onHoveredChanged: BarState.hover("right", hovered) }
        }
    }

    // ---- C: one edge-to-edge glass strip with both islands inside ----
    PanelWindow {
        id: stripWindow
        screen: bar.modelData
        visible: bar.joined

        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.barWindowHeight
        mask: Region { item: strip }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparent

        WlrLayershell.namespace: "dragon-bar"
        WlrLayershell.layer: WlrLayer.Top

        IdleInhibitor {
            window: stripWindow
            enabled: Caffeine.enabled && stripWindow.visible
        }

        Rectangle {
            id: strip
            width: parent.width
            height: Theme.barHeight
            color: Theme.glassBg
            opacity: bar.contentOpacity
            Behavior on opacity { NumberAnimation { duration: Theme.durStd } }
            HoverHandler { onHoveredChanged: BarState.hover("strip", hovered) }

            // no bottom line (pulido: the bar has no white outline any more); «ahumado» keeps the light edge on top
            GlassLight { cornerRadius: 0 }

            LeftIsland {
                id: stripLeft
                bar: bar
                bare: true
                live: bar.joined
                x: Theme.spacingSm
                windowX: 0
                maxWidth: Math.max(0, bar.screenWidth / 2 - Theme.notchReserve / 2 - Theme.spacingSm)
            }

            RightIsland {
                id: stripRight
                bar: bar
                bare: true
                x: parent.width - width - Theme.spacingSm
                windowX: 0
                maxWidth: Math.max(0, bar.screenWidth - Theme.spacingSm * 2 - stripLeft.width - Theme.notchSideReserve)
            }
        }
    }
}
