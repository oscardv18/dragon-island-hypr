// IA tab of the Nook (docs/design/17-agentes.png): sub-tabs Agentes · Comandos · Editores.
//   Agentes   one card per herdr agent (AgentRow): waiting (warn card, what it waits for, Aprobar / Rechazar for the
//             agent kinds with a known prompt, else Responder), working (cyan spinner, observed time), finished (✓)
//   Comandos  long shell commands from services/Commands.qml: running (spinner, elapsed) and recently finished
//   Editores  the open code editors (services/EditorWatcher.qml), as before
// SUPER + ALT + A opens the Nook straight on this tab (ShellState.openNook("ia")).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string sub: "agents"     // "agents" | "commands" | "editors"
    Component.onCompleted: EditorWatcher.setWatching(true)
    Component.onDestruction: EditorWatcher.setWatching(false)

    property real nowMs: Date.now()
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.nowMs = Date.now() }
    function ago(since: real): string {
        if (!since) return "";
        const s = Math.max(0, Math.floor((root.nowMs - since) / 1000));
        if (s < 60) return `hace ${s} s`;
        const m = Math.floor(s / 60);
        return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${m % 60} min`;
    }

    // waiting first, then working, then the rest
    readonly property var agents: Herdr.agents.slice().sort((a, b) => {
        const rank = st => st === "blocked" ? 0 : (st === "working" ? 1 : (st === "done" ? 2 : 3));
        return rank(a.state) - rank(b.state);
    })

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingSm

        // ---- sub-tabs + shortcut hint ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { key: "agents",   label: "Agentes",  n: Herdr.agents.length },
                    { key: "commands", label: "Comandos", n: Commands.running.length + Commands.recent.length },
                    { key: "editors",  label: "Editores", n: EditorWatcher.editors.length }
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool current: root.sub === modelData.key
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: chipRow.implicitWidth + Theme.spacingMd * 2
                    radius: 8
                    color: current ? Theme.hoverOverlay : (chipMouse.containsMouse ? Theme.alpha(Theme.text, 0.04) : Theme.transparent)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs
                        UiText { text: chip.modelData.label; weight: chip.current ? Theme.weightSemiBold : Theme.weightRegular; color: chip.current ? Theme.text : Theme.textDim }
                        UiText { visible: chip.modelData.n > 0; text: `${chip.modelData.n}`; color: Theme.textDim }
                    }
                    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.sub = chip.modelData.key }
                }
            }
            Item { Layout.fillWidth: true }
            UiText { text: "Super + Alt + A"; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width
                spacing: Theme.spacingXs

                // ---- agents ----
                UiText { visible: root.sub === "agents" && !Herdr.running; text: "herdr sin conexión"; color: Theme.textDim }
                UiText { visible: root.sub === "agents" && Herdr.running && Herdr.agents.length === 0; text: "Sin agentes"; color: Theme.textDim }
                Repeater {
                    model: root.sub === "agents" ? root.agents : []
                    delegate: AgentRow {
                        required property var modelData
                        width: body.width
                        agent: modelData
                        detail: Herdr.details[modelData.pane] ?? null
                        elapsed: root.ago(modelData.since)
                        canAnswer: Herdr.canAnswer(modelData)
                        onClicked: Herdr.focusAgent(modelData)
                        onViewTerminal: Herdr.focusAgent(modelData)
                        onApprove: Herdr.approve(modelData)
                        onReject: Herdr.reject(modelData)
                    }
                }

                // ---- commands ----
                UiText { visible: root.sub === "commands" && Commands.running.length + Commands.recent.length === 0; text: `Los comandos de ${Settings.longCommandSeconds} s o más aparecen aquí`; color: Theme.textDim }
                Repeater {
                    model: root.sub === "commands" ? Commands.running.map(c => Object.assign({ live: true }, c)).concat(Commands.recent) : []
                    delegate: Rectangle {
                        id: cmdRow
                        required property var modelData
                        width: body.width
                        height: 44
                        radius: Theme.rowRadius
                        color: Theme.alpha(Theme.text, 0.035)
                        readonly property bool live: modelData.live === true
                        readonly property bool ok: modelData.code === 0
                        Spinner { visible: cmdRow.live; x: 12; anchors.verticalCenter: parent.verticalCenter }
                        Glyph {
                            visible: !cmdRow.live
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            icon: cmdRow.ok ? Icons.check : Icons.close
                            size: Theme.iconMd
                            color: cmdRow.ok ? Theme.ok : Theme.error
                        }
                        Column {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 90
                            UiText { width: parent.width; text: cmdRow.modelData.command; mono: true; weight: Theme.weightMedium }
                            UiText { width: parent.width; text: cmdRow.modelData.cwd.replace(Quickshell.env("HOME"), "~"); size: Theme.sizeCaption; color: Theme.textDim }
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            mono: true
                            size: Theme.sizeCaption + 1
                            color: cmdRow.live || cmdRow.ok ? Theme.textSoft : Theme.error
                            text: cmdRow.live ? Commands.formatDuration((root.nowMs - cmdRow.modelData.since) / 1000)
                                              : (cmdRow.ok ? Commands.formatDuration(cmdRow.modelData.seconds) : `salida ${cmdRow.modelData.code} · ${Commands.formatDuration(cmdRow.modelData.seconds)}`)
                        }
                    }
                }

                // ---- editors (as before) ----
                UiText { visible: root.sub === "editors" && EditorWatcher.editors.length === 0; text: "Ningún editor abierto"; color: Theme.textDim }
                Repeater {
                    model: root.sub === "editors" ? EditorWatcher.editors : []
                    delegate: Rectangle {
                        required property var modelData
                        width: body.width
                        height: 40
                        radius: Theme.rowRadius
                        color: edMouse.containsMouse ? Theme.hoverOverlay : Theme.alpha(Theme.text, 0.035)
                        Column {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24
                            UiText { width: parent.width; text: modelData.count > 1 ? `${modelData.name} (${modelData.count})` : modelData.name }
                            UiText { width: parent.width; text: modelData.kind === "process" ? "en una terminal" : `escritorio ${modelData.workspace}`; size: Theme.sizeCaption; color: Theme.textDim }
                        }
                        MouseArea { id: edMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: modelData.toplevel ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: EditorWatcher.focus(modelData) }
                    }
                }
            }
        }
    }
}
