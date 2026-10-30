// − value + control of the Ajustes panel (times): `value` in the unit of `step`, shown with `format(value)`.
import QtQuick
import "../.."
import "../../components"

Row {
    id: root
    property real value: 0
    property real step: 1
    property real from: 0
    property real to: 100
    property var format: v => `${v}`
    signal changed(real value)

    spacing: Theme.spacingSm
    PillButton { label: "−"; implicitHeight: 28; implicitWidth: 32; onPressed: root.changed(Math.max(root.from, root.value - root.step)) }
    UiText {
        anchors.verticalCenter: parent.verticalCenter
        width: 74
        horizontalAlignment: Text.AlignHCenter
        text: root.format(root.value)
        mono: true
    }
    PillButton { label: "+"; implicitHeight: 28; implicitWidth: 32; onPressed: root.changed(Math.min(root.to, root.value + root.step)) }
}
