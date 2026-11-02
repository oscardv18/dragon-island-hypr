// Segmented choice (Preguntar · Omitir · Reemplazar · Renombrar; Solo lectura · Lectura y escritura).
// options: [{value, label}]; Left/Right move the choice when focused.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property var options: []
    property string value: ""
    signal chosen(string value)
    implicitHeight: Theme.files.segmentHeight
    radius: Theme.files.buttonRadius
    color: Theme.files.button
    border.width: Theme.files.border
    border.color: activeFocus ? Theme.cyan : Theme.files.buttonBorder
    activeFocusOnTab: true
    readonly property int index: options.findIndex(o => o.value === value)
    Keys.onLeftPressed: if (index > 0) chosen(options[index - 1].value)
    Keys.onRightPressed: if (index < options.length - 1) chosen(options[index + 1].value)
    Row {
        anchors.fill: parent
        anchors.margins: Theme.files.thinGap
        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                width: (root.width - Theme.files.thinGap * 2) / root.options.length
                height: parent.height
                radius: root.radius - Theme.files.thinGap
                color: root.value === modelData.value ? Theme.cyan : hit.containsMouse ? Theme.files.hover : Theme.transparent
                UiText { anchors.centerIn: parent; text: modelData.label; size: Theme.files.small
                         weight: root.value === modelData.value ? Theme.weightSemiBold : Theme.weightRegular
                         color: root.value === modelData.value ? Theme.islandInk : Theme.text }
                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(modelData.value) }
            }
        }
    }
}
