// Labelled usage bar: icon · label ........ value / bar (CPU, RAM, Temp, Disk)
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string icon: ""
    property string label: ""
    property string valueText: ""
    property real value: 0
    property color color: Theme.accent

    spacing: Theme.spacingXs

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Glyph {
            icon: root.icon
            size: Theme.iconSm
            color: root.color
        }
        UiText {
            Layout.fillWidth: true
            text: root.label
            size: Theme.sizeCaption + 1
            color: Theme.textSoft
        }
        UiText {
            text: root.valueText
            mono: true
            size: Theme.sizeCaption + 1
            color: Theme.text
        }
    }

    ProgressBar {
        Layout.fillWidth: true
        value: root.value
        color: root.color
    }
}
