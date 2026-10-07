// =============================================================================
// dragon-island — Bar.qml
// Floating bar (10 px from the top, 14 px from the sides, height 40) with two side islands.
// The window spans the width, but its mask only contains the islands: the gaps (and the
// middle, where the notch lives in its own overlay) let clicks through.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: bar

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; left: true; right: true }
    margins {
        top: Theme.barMarginTop
        left: Theme.barMarginSide
        right: Theme.barMarginSide
    }
    implicitHeight: Theme.barHeight
    // reserve the bar height; windows start below it (+ gaps_out)
    exclusiveZone: Theme.barHeight
    color: Theme.transparent

    WlrLayershell.namespace: "dragon-bar"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        Region { item: leftIsland }
        Region { item: rightIsland }
    }

    // x (screen-local) of an item's right edge: popovers align their right edge to it
    function anchorRightOf(item): real {
        return item.mapToItem(null, item.width, 0).x + Theme.barMarginSide;
    }

    function openFrom(name: string, item): void {
        ShellState.toggleAt(name, bar.screenName, anchorRightOf(item));
    }

    function isOpen(name: string): bool {
        return ShellState.openPanel === name && ShellState.panelScreen === bar.screenName;
    }

    // Tell the notch where the islands end (screen x, bar margins included)
    readonly property real leftEnd: Theme.barMarginSide + leftIsland.width
    readonly property real rightStart: bar.width + Theme.barMarginSide - rightIsland.width
    onLeftEndChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    onRightStartChanged: BarMetrics.report(screenName, leftEnd, rightStart)
    Component.onCompleted: BarMetrics.report(screenName, leftEnd, rightStart)

    LeftIsland {
        id: leftIsland
        bar: bar
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // never reach the centre, where the collapsed notch sits
        maxWidth: Math.max(0, bar.width / 2 - Theme.notchReserve / 2 - Theme.barIslandGap)
    }

    RightIsland {
        id: rightIsland
        bar: bar
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
