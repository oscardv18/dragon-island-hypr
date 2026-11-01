// Button of the explorer: text, icon or both; `primary` = cyan fill (Extraer aquí, Aplicar), `round` = the circular
// navigation buttons, `checked` = the active half of a toggle. Keyboard: Return / Space.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property string hint: ""              // key hint drawn as a small chip (Esc, ↵)
    property bool primary: false
    property bool checked: false
    property bool round: false
    property bool danger: false
    signal clicked()
    implicitHeight: round ? Theme.files.navButton : Theme.files.buttonHeight
    implicitWidth: round ? implicitHeight : row.implicitWidth + Theme.files.buttonPad * 2
    radius: round ? height / 2 : Theme.files.buttonRadius
    color: primary ? Theme.cyan : checked ? Theme.files.selected : hit.containsMouse && enabled ? Theme.files.buttonHover : Theme.files.button
    border.width: Theme.files.border
    border.color: activeFocus ? Theme.cyan : checked ? Theme.files.selectedBorder : primary ? Theme.transparent : Theme.files.buttonBorder
    opacity: enabled ? 1 : Theme.files.disabledOpacity
    activeFocusOnTab: true
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.files.smallGap
        Glyph {
            visible: root.icon.length > 0
            icon: root.icon
            size: Theme.files.icon
            color: root.primary ? Theme.islandInk : root.checked ? Theme.cyan : root.danger ? Theme.danger : Theme.textSoft
            anchors.verticalCenter: parent.verticalCenter
        }
        UiText {
            visible: root.label.length > 0
            text: root.label
            size: Theme.files.body
            weight: root.primary ? Theme.weightSemiBold : Theme.weightRegular
            color: root.primary ? Theme.islandInk : root.danger ? Theme.danger : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            visible: root.hint.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: hintText.implicitWidth + Theme.files.inset
            height: hintText.implicitHeight + Theme.files.thinGap
            radius: Theme.files.chipRadius / 2
            color: root.primary ? Theme.files.hintOnPrimary : Theme.files.button
            UiText { id: hintText; anchors.centerIn: parent; text: root.hint; mono: true; size: Theme.files.mono; color: root.primary ? Theme.islandInk : Theme.textDim }
        }
    }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (root.enabled) root.clicked() }
}
