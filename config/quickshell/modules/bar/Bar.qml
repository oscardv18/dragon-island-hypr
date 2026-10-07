// =============================================================================
// dragon-island — Bar.qml
// Floating bar (10 px from the top, 14 px from the sides, height 40) made of two side islands.
// Each island is its own layer window of exactly the island's size (namespace "dragon-bar"), because
// hyprglass / the compositor treat the union of several blur regions as ONE bounding box: with a single
// full-width window the gap between the islands got glass too. Per-island windows have nothing in the
// gaps, so they stay clean, and each island's blur region is just its rounded rectangle.
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

    // x (screen-local) of an item's right edge: popovers align their right edge to it
    function anchorRightOf(item, windowX: real): real {
        return item.mapToItem(null, item.width, 0).x + windowX;
    }

    function openFrom(name: string, item): void {
        const rightSide = item.Window.window === rightWindow;
        ShellState.toggleAt(name, bar.screenName, anchorRightOf(item, rightSide ? rightWindow.screenX : leftWindow.screenX));
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

        // glass / blur only behind the island, with its radius
        BackgroundEffect.blurRegion: Region { item: leftIsland; radius: Theme.barIslandRadius }

        LeftIsland {
            id: leftIsland
            bar: bar
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

        BackgroundEffect.blurRegion: Region { item: rightIsland; radius: Theme.barIslandRadius }

        RightIsland {
            id: rightIsland
            bar: bar
        }
    }
}
