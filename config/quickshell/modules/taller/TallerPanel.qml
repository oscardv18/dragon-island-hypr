// Pure HUD view. Services are injected by TallerWindow; tests/qml/taller_mock.qml supplies fake data.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    property var agentService: null
    property var memService: null
    property string tab: "agentes"
    property bool shown: false
    property string notice: ""
    signal tabRequested(string name)
    signal closeRequested()
    signal projectRequested()
    readonly property var tabNames: ["agentes", "kanban", "contenedores", "git", "revision"]
    readonly property var labels: ["Agentes", "Kanban", "Contenedores", "Git", "Revisión"]
    readonly property string projectBranch: {
        const slug = memService?.selectedSlug ?? "";
        return agentService?.agents?.find(a => a.project === slug)?.branch ?? "";
    }
    implicitWidth: Theme.taller.width
    implicitHeight: Theme.taller.height
    radius: Theme.taller.radius
    color: Theme.taller.panel
    border.width: Theme.taller.buttonBorder
    border.color: Theme.taller.border
    focus: shown
    Keys.forwardTo: root.tab === "agentes" ? [agentsView] : []
    Keys.onEscapePressed: closeRequested()
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Tab && (e.modifiers & Qt.ControlModifier)) {
            const i = tabNames.indexOf(tab);
            tabRequested(tabNames[(i + (e.modifiers & Qt.ShiftModifier ? 4 : 1)) % tabNames.length]);
            e.accepted = true;
        }
    }
    FrameDecor { anchors.fill: parent; radius: root.radius }
    // Stop pointer events at the panel edge so the window's outside-click handler cannot close it.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.taller.padding
        spacing: Theme.taller.gap
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.taller.header
            spacing: Theme.taller.inset
            UiText { text: "TALLER"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.lavender }
            TallerButton {
                Layout.preferredWidth: Theme.taller.selectorWidth
                label: (root.memService?.project?.name ?? "Selecciona un proyecto") + (root.projectBranch ? " · " + root.projectBranch : "") + " ⌄"
                onClicked: root.projectRequested()
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.taller.buttonBorder; color: Theme.taller.border }
            UiText { text: root.agentService?.running ? `● HERDR ${root.agentService?.version ?? ""} · SOCKET` : "HERDR · SIN CONEXIÓN"; color: root.agentService?.running ? Theme.ok : Theme.textDim; mono: true; size: Theme.taller.caption }
            UiText { text: `DB · ${root.memService?.projects?.length ?? 0} PROYECTOS`; mono: true; size: Theme.taller.caption; color: root.memService?.status === "error" ? Theme.danger : Theme.textDim }
            TallerButton { label: "Prompt ✎ [P]"; enabled: false }
            UiText { text: "SUPER + T"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
        }
        Row {
            spacing: Theme.taller.smallGap
            Repeater {
                model: root.tabNames
                delegate: TallerButton {
                    required property string modelData
                    required property int index
                    label: root.labels[index] + (index === 0 && (root.agentService?.counts?.blocked ?? 0) > 0 ? "  " + root.agentService.counts.blocked : "")
                    primary: root.tab === modelData
                    onClicked: root.tabRequested(modelData)
                }
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            AgentsTab {
                id: agentsView
                anchors.fill: parent
                visible: root.tab === "agentes"
                service: root.agentService
                shown: root.shown && visible
            }
            UiText {
                visible: root.tab !== "agentes"
                anchors.centerIn: parent
                width: parent.width - Theme.taller.padding * 2
                horizontalAlignment: Text.AlignHCenter
                text: root.tab === "agentes" ? (root.agentService?.message || "No hay agentes activos") :
                    ({kanban: "El tablero Kanban estará disponible en el tramo 5c", contenedores: "Contenedores estará disponible en el tramo 5b", git: "Git estará disponible en el tramo 5b", revision: "Revisión estará disponible en el tramo 5c"})[root.tab]
                size: Theme.taller.heading
                color: Theme.textDim
            }
        }
        UiText {
            Layout.fillWidth: true
            visible: root.notice.length > 0 || (root.memService?.status === "error")
            text: root.notice || root.memService?.message || ""
            color: Theme.warn
            size: Theme.taller.body
        }
    }
}
