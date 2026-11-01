// Checkbox row (ExtractDialog, ShareDialog, prompts).
import QtQuick
import "../.."
import "../../components"

Item {
    id: root
    property string label: ""
    property bool checked: false
    signal toggled()
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, Theme.files.row - Theme.files.inset)
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled()
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.files.inset
        Rectangle {
            width: Theme.files.rowIcon + Theme.files.thinGap
            height: width
            radius: Theme.files.chipRadius / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? Theme.cyan : Theme.transparent
            border.width: Theme.files.border
            border.color: root.activeFocus || root.checked ? Theme.cyan : Theme.textDim
            Glyph { anchors.centerIn: parent; visible: root.checked; icon: Icons.check; size: Theme.files.small; color: Theme.islandInk }
        }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: root.label; size: Theme.files.body; color: Theme.text }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}
