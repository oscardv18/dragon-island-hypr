// Text button with Taller tokens, keyboard focus and an explicit disabled state.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property string label: ""
    property bool primary: false
    property color tone: Theme.cyan
    signal clicked()
    implicitWidth: labelText.implicitWidth + Theme.taller.buttonPad * 2
    implicitHeight: Theme.taller.buttonHeight
    radius: Theme.taller.buttonRadius
    color: primary ? tone : (hit.containsMouse ? Theme.taller.hover : Theme.taller.button)
    border.width: Theme.taller.buttonBorder
    border.color: activeFocus ? Theme.cyan : Theme.taller.border
    opacity: enabled ? 1 : Theme.taller.disabledOpacity
    activeFocusOnTab: true
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    UiText { id: labelText; anchors.centerIn: parent; width: Math.min(implicitWidth, root.width - Theme.taller.buttonPad * 2); horizontalAlignment: Text.AlignHCenter; text: root.label; size: Theme.taller.body; color: root.primary ? Theme.islandInk : Theme.text }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
