// Small modal question of the explorer: rename, new folder, delete for good, «ya existe», passwords.
// ask({title, message, value, placeholder, password, buttons: [{label, action, primary, danger}], check: label}) →
// answered(action, value, checked). Esc = the first non-primary button (cancel).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Item {
    id: root
    property var spec: ({})
    property bool checked: false
    signal answered(string action, string value, bool checked)
    visible: false
    anchors.fill: parent
    function ask(s): void {
        spec = s; checked = false; visible = true;
        field.text = s.value ?? "";
        Qt.callLater(() => {
            if (s.input === false) box.forceActiveFocus();
            else { field.focusInput(); const dot = (s.value ?? "").lastIndexOf("."); if (s.selectStem && dot > 0) field.input.select(0, dot); }
        });
    }
    function reply(action): void { visible = false; answered(action, field.text, checked); }
    readonly property var buttons: spec.buttons ?? [{ label: "Cancelar", action: "cancel" }, { label: "Aceptar", action: "ok", primary: true }]
    Rectangle { anchors.fill: parent; radius: Theme.files.radius; color: Theme.files.scrim; MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } }
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Theme.files.promptWidth
        height: layout.implicitHeight + Theme.files.padding * 2
        radius: Theme.files.radius - Theme.files.inset
        color: Theme.files.dialog
        border.width: Theme.files.border
        border.color: Theme.files.buttonBorder
        Keys.onEscapePressed: root.reply(root.buttons.find(b => !b.primary)?.action ?? "cancel")
        Keys.onReturnPressed: root.reply(root.buttons.find(b => b.primary)?.action ?? "ok")
        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.files.padding
            spacing: Theme.files.gap
            UiText { Layout.fillWidth: true; text: root.spec.title ?? ""; mono: true; size: Theme.files.caption; font.letterSpacing: Theme.files.captionTracking; font.capitalization: Font.AllUppercase; color: Theme.textDim }
            UiText { Layout.fillWidth: true; visible: text.length > 0; text: root.spec.message ?? ""; size: Theme.files.body; color: root.spec.danger ? Theme.danger : Theme.text; wrapMode: Text.Wrap; maximumLineCount: 6 }
            FilesInput {
                id: field
                Layout.fillWidth: true
                visible: root.spec.input !== false
                placeholder: root.spec.placeholder ?? ""
                password: !!root.spec.password
                mono: !!root.spec.password
                onAccepted: root.reply(root.buttons.find(b => b.primary)?.action ?? "ok")
                onEscaped: root.reply(root.buttons.find(b => !b.primary)?.action ?? "cancel")
            }
            FilesCheck { visible: !!root.spec.check; label: root.spec.check ?? ""; checked: root.checked; onToggled: root.checked = !root.checked }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Item { Layout.fillWidth: true }
                Repeater {
                    model: root.buttons
                    delegate: FilesButton {
                        required property var modelData
                        label: modelData.label
                        primary: !!modelData.primary
                        danger: !!modelData.danger
                        onClicked: root.reply(modelData.action)
                    }
                }
            }
        }
    }
}
