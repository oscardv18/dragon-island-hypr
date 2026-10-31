// A meter of the right island (CPU ring, RAM ring, network line): flat capsule, click = Rendimiento popover,
// its detail as a tooltip under the island while hovered.
import QtQuick
import "../.."
import "../../components"

Capsule {
    id: meter

    required property var island      // the RightIsland (openPopover, bar)
    property string tip: ""

    flat: true
    padH: Theme.spacingXs + 1
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    // only the meter that opened Rendimiento glows (the three open the same popover)
    active: island.bar.isOpen("perf") && Math.abs(ShellState.anchorCenter - (meter.mapToItem(null, meter.width / 2, 0).x + island.windowX)) < meter.width / 2
    onClicked: island.openPopover("perf", meter)
    BarTooltip { target: meter; shown: meter.hovered; text: meter.tip }
}
