// =============================================================================
// dragon-island — Bar.qml
// Floating bar (10 px from the top, 14 px from the sides, height 40) made of two side islands.
// Each island is its own layer window of exactly the island's size (namespace "dragon-bar"), fully
// transparent (alpha 0) around the rounded island: hyprglass masks by alpha (mask_mode = "alpha"), so the
// glass has the island's rounded corners and the gaps between islands stay clean. No BackgroundEffect
// blurRegion: a Wayland region can only be rectangles, which left square tips at the corners.
// A third, 1 px high transparent window ("dragon-bar-zone") only reserves the bar's space so tiled
// windows start below it; it has an empty input mask and no blur.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

Scope {
    id: bar

    property var modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property real screenWidth: modelData?.width ?? 0

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
    readonly property real leftEnd: leftWindow.screenX + leftIsland.width
    readonly property real rightStart: rightWindow.screenX
    onLeftEndChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    onRightStartChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    Component.onCompleted: BarMetrics.report(screenName, leftEnd, rightStart)

    // ---- reserves the bar's space (nothing is drawn, nothing is clickable) ----
    PanelWindow {
        screen: bar.modelData
        anchors { top: true; left: true; right: true }
        margins { top: Theme.barMarginTop; left: Theme.barMarginSide; right: Theme.barMarginSide }
        implicitHeight: 1
        exclusiveZone: Theme.barHeight
        color: Theme.transparent
        mask: Region {}
        WlrLayershell.namespace: "dragon-bar-zone"
        WlrLayershell.layer: WlrLayer.Top
    }

    // ---- left island ----
    PanelWindow {
        id: leftWindow
        screen: bar.modelData
        readonly property real screenX: Theme.barMarginSide

        anchors { top: true; left: true }
        margins { top: Theme.barMarginTop; left: Theme.barMarginSide }
        implicitWidth: leftIsland.width
        implicitHeight: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparent

        WlrLayershell.namespace: "dragon-bar"
        WlrLayershell.layer: WlrLayer.Top

        LeftIsland {
            id: leftIsland
            bar: bar
            windowX: leftWindow.screenX
            // never reach the centre, where the collapsed notch sits
            maxWidth: Math.max(0, (bar.screenWidth - Theme.barMarginSide * 2) / 2 - Theme.notchReserve / 2 - Theme.barIslandGap)
        }
    }

    // ---- right island ----
    PanelWindow {
        id: rightWindow
        screen: bar.modelData
        readonly property real screenX: bar.screenWidth - Theme.barMarginSide - rightIsland.width

        anchors { top: true; right: true }
        margins { top: Theme.barMarginTop; right: Theme.barMarginSide }
        implicitWidth: rightIsland.width
        implicitHeight: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparent

        WlrLayershell.namespace: "dragon-bar"
        WlrLayershell.layer: WlrLayer.Top

        RightIsland {
            id: rightIsland
            bar: bar
            windowX: rightWindow.screenX
        }
    }
}
