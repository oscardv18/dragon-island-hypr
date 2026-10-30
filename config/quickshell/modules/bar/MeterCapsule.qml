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
    active: island.bar.isOpen("perf")
    onClicked: island.openPopover("perf", meter)
    BarTooltip { target: meter; shown: meter.hovered; text: meter.tip }
}
