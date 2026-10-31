// Signal strength as 4 rising bars (29-paneles-wifi: the current network and the nearby list). `value` 0..1.
import QtQuick
import ".."

Row {
    id: root
    property real value: 0
    property color color: Theme.cyan
    property real barHeight: 12
    spacing: 2
    readonly property int _lit: value <= 0 ? 0 : Math.max(1, Math.ceil(value * 4))
    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: 3
            height: root.barHeight * (0.4 + 0.2 * index)
            radius: 1
            color: index < root._lit ? root.color : Theme.hudSegOff
        }
    }
}
