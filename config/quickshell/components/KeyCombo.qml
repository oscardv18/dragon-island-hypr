// Key combination as keycaps: [SUPER] + [SHIFT] + [1–5]
import QtQuick
import ".."

Row {
    id: root
    property var keys: []          // ["SUPER", "SHIFT", "1–5"]

    spacing: Theme.spacingXs

    Repeater {
        model: root.keys
        delegate: Row {
            id: part
            required property string modelData
            required property int index
            spacing: Theme.spacingXs

            UiText {
                visible: part.index > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                size: Theme.sizeCaption
                color: Theme.textDim
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.keyCapHeight
                width: Math.max(height, label.implicitWidth + Theme.keyCapPadH * 2)
                radius: Theme.keyCapRadius
                color: Theme.surface3
                border.width: 1
                border.color: Theme.hairline

                UiText {
                    id: label
                    anchors.centerIn: parent
                    text: part.modelData
                    mono: true
                    size: Theme.sizeCaption
                    weight: Theme.weightSemiBold
                    color: Theme.textSoft
                }
            }
        }
    }
}
