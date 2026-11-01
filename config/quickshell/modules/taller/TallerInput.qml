// Plain text input. Values are handed to the service only after the user submits.
import QtQuick
import "../.."
import "../../components"
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    signal accepted()
    implicitHeight: Theme.taller.inputHeight
    radius: Theme.taller.badgeRadius
    color: Theme.taller.output
    border.width: Theme.taller.buttonBorder
    border.color: input.activeFocus ? Theme.cyan : Theme.taller.border
    function focusInput(): void { input.forceActiveFocus(); }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: Theme.taller.inset
        color: Theme.text
        selectionColor: Theme.cyan
        selectedTextColor: Theme.islandInk
        font.family: Theme.fontUi
        font.pixelSize: Theme.taller.body
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        onAccepted: root.accepted()
    }
    UiText {
        anchors.fill: input
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.textDim
        size: Theme.taller.body
    }
}
