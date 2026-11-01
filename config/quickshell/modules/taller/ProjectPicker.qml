// In-panel project selector and explicit project registration; no implicit writes on typing.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
Rectangle {
    id: root
    property var memory: null
    property bool creating: (memory?.projects?.length ?? 0) === 0
    property bool busy: false
    property string error: ""
    signal closeRequested()
    implicitWidth: Theme.taller.projectDialogWidth
    implicitHeight: body.implicitHeight + Theme.taller.detailPadding * 2
    radius: Theme.taller.buttonRadius
    color: Theme.taller.panel
    border.width: Theme.taller.buttonBorder
    border.color: Theme.taller.selectedBorder
    focus: visible
    Keys.onEscapePressed: e => { root.closeRequested(); e.accepted = true; }
    function createProject(): void {
        if (busy || !pathInput.text.trim()) return;
        busy = true; error = "";
        memory?.addProject(pathInput.text.trim(), nameInput.text.trim(), prefixInput.text.trim().toUpperCase(), r => {
            busy = false;
            if (r.ok) closeRequested(); else error = r.error?.message ?? "No se pudo registrar el proyecto";
        });
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.taller.detailPadding }
        spacing: Theme.taller.rowGap
        RowLayout {
            Layout.fillWidth: true
            UiText { text: "PROYECTOS"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.lavender; Layout.fillWidth: true }
            TallerButton { label: "×"; onClicked: root.closeRequested() }
        }
        ListView {
            id: projects
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Theme.taller.projectListHeight, count * (Theme.taller.buttonHeight + Theme.taller.smallGap))
            clip: true
            model: root.memory?.projects ?? []
            spacing: Theme.taller.smallGap
            delegate: TallerButton {
                required property var modelData
                width: projects.width
                label: modelData.name + (modelData.slug === root.memory?.selectedSlug ? "  ✓" : "")
                primary: modelData.slug === root.memory?.selectedSlug
                onClicked: { root.memory?.selectProject(modelData.slug); root.closeRequested(); }
            }
        }
        TallerButton { label: root.creating ? "− Ocultar alta" : "+ Añadir proyecto"; enabled: !root.busy; onClicked: { root.creating = !root.creating; if (root.creating) pathInput.focusInput(); } }
        ColumnLayout {
            visible: root.creating
            Layout.fillWidth: true
            spacing: Theme.taller.rowGap
            UiText { text: "Carpeta del proyecto"; color: Theme.textSoft; size: Theme.taller.body }
            TallerInput { id: pathInput; Layout.fillWidth: true; placeholder: "/home/usuario/Devs/proyecto"; onAccepted: root.createProject(); enabled: !root.busy }
            UiText { text: "Nombre y prefijo de tarjetas (opcionales)"; color: Theme.textDim; size: Theme.taller.caption }
            TallerInput { id: nameInput; Layout.fillWidth: true; placeholder: "Nombre del proyecto"; enabled: !root.busy }
            TallerInput { id: prefixInput; Layout.fillWidth: true; placeholder: "Prefijo, por ejemplo AX"; onAccepted: root.createProject(); enabled: !root.busy }
            TallerButton { label: root.busy ? "Registrando…" : "Registrar proyecto"; primary: true; enabled: !root.busy && pathInput.text.trim().length > 0; onClicked: root.createProject() }
        }
        UiText { Layout.fillWidth: true; visible: root.error.length > 0; text: root.error; color: Theme.danger; size: Theme.taller.body; maximumLineCount: 4; wrapMode: Text.Wrap }
    }
}
