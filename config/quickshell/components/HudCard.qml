// An inner card of the HUD panels (29-paneles: the current network, a connected device, the volume): faint fill,
// 1 px edge, radius 12. Children go into a column with `spacing`.
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    default property alias content: col.data
    property real padding: Theme.spacingMd
    property alias spacing: col.spacing
    property bool highlighted: false

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + padding * 2
    radius: Theme.hudCardRadius
    color: highlighted ? Theme.alpha(Theme.cyan, 0.06) : Theme.hudCard
    border.width: 1
    border.color: highlighted ? Theme.alpha(Theme.cyan, 0.35) : Theme.hudCardEdge

    ColumnLayout {
        id: col
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: Theme.spacingSm
    }
}
