// Rounded chip: template choice, prompt block (with its tokens) or kind tag. Keyboard: Enter/Space toggles.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property string label: ""
    property string count: ""
    property bool on: true
    property bool selected: false
    property bool struck: false
    signal clicked()
    implicitWidth: row.implicitWidth + Theme.taller.chipPad * 2
    implicitHeight: Theme.taller.chipHeight
    radius: Theme.taller.chipRadius
    color: selected ? Theme.lavender : on ? Theme.taller.chipOn : (hit.containsMouse ? Theme.taller.hover : Theme.taller.button)
    border.width: Theme.taller.buttonBorder
    border.color: activeFocus ? Theme.cyan : selected ? Theme.lavender : on ? Theme.taller.chipOnBorder : Theme.taller.border
    opacity: enabled ? 1 : Theme.taller.disabledOpacity
    activeFocusOnTab: true
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.taller.smallGap
        UiText { text: root.label; size: Theme.taller.body; color: root.selected ? Theme.islandInk : root.on ? Theme.text : Theme.textDim; font.strikeout: root.struck }
        UiText { visible: root.count.length > 0; text: root.count; mono: true; size: Theme.taller.caption; color: root.selected ? Theme.islandInk : root.on ? Theme.cyan : Theme.textDim; font.strikeout: root.struck }
    }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
