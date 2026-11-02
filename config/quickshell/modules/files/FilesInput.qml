// Text field of the explorer (breadcrumb editor, search, dialogs). Values reach a service only on `accepted`.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property string hint: ""
    property bool mono: false
    property bool password: false
    signal accepted()
    signal escaped()
    implicitHeight: Theme.files.inputHeight
    radius: Theme.files.inputRadius
    color: Theme.files.input
    border.width: Theme.files.border
    border.color: input.activeFocus ? Theme.cyan : Theme.files.buttonBorder
    function focusInput(): void { input.forceActiveFocus(); input.selectAll(); }
    Glyph {
        id: glyph
        visible: root.icon.length > 0
        icon: root.icon
        size: Theme.files.icon
        color: Theme.textDim
        anchors.left: parent.left
        anchors.leftMargin: Theme.files.inset
        anchors.verticalCenter: parent.verticalCenter
    }
    TextInput {
        id: input
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: Theme.files.inset
        anchors.right: hintChip.visible ? hintChip.left : parent.right
        anchors.rightMargin: Theme.files.inset
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        selectionColor: Theme.cyan
        selectedTextColor: Theme.islandInk
        font.family: root.mono ? Theme.fontMono : Theme.fontUi
        font.pixelSize: root.mono ? Theme.files.small : Theme.files.body
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: e => { root.escaped(); e.accepted = true; }
    }
    UiText {
        anchors.fill: input
        visible: input.text.length === 0
        text: root.placeholder
        color: Theme.textDim
        size: Theme.files.body
    }
    Rectangle {
        id: hintChip
        visible: root.hint.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.files.smallGap
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(height, hintLabel.implicitWidth + Theme.files.inset)
        height: parent.height - Theme.files.smallGap * 2
        radius: Theme.files.chipRadius / 2
        color: Theme.files.button
        border.width: Theme.files.border
        border.color: Theme.files.buttonBorder
        UiText { id: hintLabel; anchors.centerIn: parent; text: root.hint; mono: true; size: Theme.files.mono; color: Theme.textDim }
    }
}
