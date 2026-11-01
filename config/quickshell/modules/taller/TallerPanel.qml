// Pure HUD view. Services are injected by TallerWindow; tests/qml/taller_mock.qml supplies fake data.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    property var agentService: null
    property var memService: null
    property var dockerService: null
    property var gitService: null
    property var promptService: null
    property var gateService: null
    property var reviewService: null
    property var tokenService: null
    property string tab: "agentes"
    property bool shown: false
    property string notice: ""
    property bool projectsOpen: false
    signal tabRequested(string name)
    signal closeRequested()
    signal projectRequested()
    readonly property bool composerOpen: promptService?.composerOpen ?? false
    function openReview(key): void { if (key) reviewService?.setCard(key); tabRequested("revision"); }
    function openComposer(opts): void { projectsOpen = false; promptService?.open(opts ?? {}); }
    readonly property var tabNames: ["agentes", "kanban", "contenedores", "git", "revision"]
    readonly property var labels: ["Agentes", "Kanban", "Contenedores", "Git", "Revisión"]
    readonly property string projectBranch: {
        const slug = memService?.selectedSlug ?? "";
        const path = memService?.project?.path ?? "";
        const live = agentService?.agents?.find(a => a.project === slug || (path && (a.cwd === path || a.cwd?.startsWith(path + "/"))))?.branch;
        return live || memService?.project?.branch || "";
    }
    implicitWidth: Theme.taller.width
    implicitHeight: Theme.taller.height
    radius: Theme.taller.radius
    color: Theme.taller.panel
    border.width: Theme.taller.buttonBorder
    border.color: Theme.taller.border
    focus: shown
    Keys.forwardTo: root.projectsOpen || root.composerOpen ? [] : root.tab === "agentes" ? [agentsView] : root.tab === "kanban" ? [kanbanView] : []
    Keys.onEscapePressed: { if (composerOpen) { promptService.close(); forceActiveFocus(); } else if (projectsOpen) projectsOpen = false; else closeRequested(); }
    Keys.onPressed: e => {
        if (root.projectsOpen) return;
        if (e.key === Qt.Key_P && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && !root.composerOpen) {
            root.openComposer({}); e.accepted = true; return;
        }
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
                onClicked: { root.projectsOpen = !root.projectsOpen; root.projectRequested(); }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.taller.buttonBorder; color: Theme.taller.border }
            UiText { text: root.agentService?.running ? `● HERDR ${root.agentService?.version ?? ""} · SOCKET` : "HERDR · SIN CONEXIÓN"; color: root.agentService?.running ? Theme.ok : Theme.textDim; mono: true; size: Theme.taller.caption }
            UiText { text: `DB · ${root.memService?.projects?.length ?? 0} PROYECTOS`; mono: true; size: Theme.taller.caption; color: root.memService?.status === "error" ? Theme.danger : Theme.textDim }
            TallerButton { label: "Prompt ✎ [P]"; primary: root.composerOpen; enabled: !!root.promptService; onClicked: root.composerOpen ? root.promptService.close() : root.openComposer({}) }
            UiText { text: "SUPER + T"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
        }
        Row {
            spacing: Theme.taller.smallGap
            Repeater {
                model: root.tabNames
                delegate: TallerButton {
                    required property string modelData
                    required property int index
                    label: root.labels[index] + (index === 0 && (root.agentService?.counts?.blocked ?? 0) > 0 ? "  " + root.agentService.counts.blocked : index === 2 && (root.dockerService?.errorCount ?? 0) > 0 ? "  " + root.dockerService.errorCount : index === 3 && (root.gitService?.changeCount ?? 0) > 0 ? "  " + root.gitService.changeCount : index === 4 && (root.reviewService?.unseenCount ?? 0) > 0 ? "  " + root.reviewService.unseenCount : "")
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
                tokenService: root.tokenService
                shown: root.shown && visible
                onPromptRequested: opts => root.openComposer(opts)
                onReviewRequested: key => root.openReview(key)
            }
            KanbanTab {
                id: kanbanView
                anchors.fill: parent
                visible: root.tab === "kanban"
                memService: root.memService
                gateService: root.gateService
                agentService: root.agentService
                shown: root.shown && visible
                onPromptRequested: opts => root.openComposer(opts)
                onReviewRequested: key => root.openReview(key)
            }
            ReviewTab {
                anchors.fill: parent
                visible: root.tab === "revision"
                service: root.reviewService
                agentService: root.agentService
                onPromptRequested: opts => root.openComposer(opts)
            }
            ContainersTab {
                anchors.fill: parent
                visible: root.tab === "contenedores"
                service: root.dockerService
                onPromptRequested: opts => root.openComposer(opts)
            }
            GitTab {
                anchors.fill: parent
                visible: root.tab === "git"
                service: root.gitService
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
    Item {
        anchors.fill: parent
        visible: root.projectsOpen
        MouseArea { anchors.fill: parent; onClicked: root.projectsOpen = false }
        ProjectPicker {
            x: Theme.taller.padding
            y: Theme.taller.padding + Theme.taller.header + Theme.taller.rowGap
            width: Math.min(Theme.taller.projectDialogWidth, root.width - Theme.taller.padding * 2)
            height: implicitHeight
            memory: root.memService
            onCloseRequested: { root.projectsOpen = false; root.forceActiveFocus(); }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.composerOpen
        Rectangle { anchors.fill: parent; radius: root.radius; color: Theme.taller.scrim }
        MouseArea { anchors.fill: parent; onClicked: { root.promptService.close(); root.forceActiveFocus(); } }
        PromptComposer {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.taller.thinGap
            anchors.topMargin: Theme.taller.composerTop
            width: Math.min(Theme.taller.composerWidth, parent.width - Theme.taller.padding * 2)
            service: root.promptService
            onCloseRequested: { root.promptService.close(); root.forceActiveFocus(); }
        }
    }
}
