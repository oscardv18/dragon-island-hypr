// Footer of the explorer in selector mode (Dragon Portal): what will be chosen, the name to save, the filter and choices
// drop-downs, Cancelar and the accept button. Pure: FilesPanel owns the state and answers the signals.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: root
    property var picker: null
    property var view: null               // FilesState (filterIndex, pickName, pickChoices)
    property string summary: ""
    property string hint: ""              // why the accept button is disabled (shown instead of the summary)
    property bool canAccept: true
    signal accepted()
    signal cancelled()
    signal filterMenu(real x, real y)
    signal choiceMenu(string id, real x, real y)
    signal nameChanged(string text)
    function focusName(): void { nameInput.focusInput(); }
    // the field keeps what the user typed; a name picked from the list (save dialogs) has to reach it too
    Connections {
        target: root.view
        ignoreUnknownSignals: true
        function onPickNameChanged() { if (nameInput.text !== root.view.pickName) nameInput.text = root.view.pickName; }
    }
    implicitHeight: Theme.files.pickerBar
    radius: Theme.files.buttonRadius
    color: Theme.files.card
    border.width: Theme.files.border
    border.color: Theme.files.buttonBorder

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.files.inset
        anchors.rightMargin: Theme.files.inset
        spacing: Theme.files.inset
        FilesInput {
            id: nameInput
            visible: root.picker?.kind === "save"
            Layout.preferredWidth: Theme.files.pickerName
            Layout.preferredHeight: Theme.files.inputHeight
            placeholder: "Nombre del archivo"
            mono: true
            text: root.view?.pickName ?? ""
            onTextChanged: root.nameChanged(text)
            onAccepted: root.accepted()
            onEscaped: root.cancelled()
        }
        UiText {
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            size: Theme.files.small
            color: root.hint ? Theme.warn : Theme.textSoft
            text: root.hint || root.summary
        }
        Repeater {
            model: root.picker?.choices ?? []
            delegate: FilesButton {
                required property var modelData
                label: modelData.label + ": " + (modelData.options.find(o => o.id === (root.view?.pickChoices?.[modelData.id] ?? modelData.selected))?.label ?? "")
                onClicked: { const p = mapToItem(root, 0, 0); root.choiceMenu(modelData.id, p.x, p.y); }
            }
        }
        FilesButton {
            visible: (root.picker?.filters?.length ?? 0) > 0
            Layout.maximumWidth: Theme.files.pickerFilter
            label: root.view?.activeFilter?.name ?? "Todos los archivos"
            icon: Icons.arrowDown
            onClicked: { const p = mapToItem(root, 0, 0); root.filterMenu(p.x, p.y); }
        }
        FilesButton { label: "Cancelar"; hint: "Esc"; onClicked: root.cancelled() }
        FilesButton {
            primary: true
            enabled: root.canAccept
            label: F.pickerAcceptLabel(root.picker)
            hint: "↵"
            onClicked: root.accepted()
        }
    }
}
