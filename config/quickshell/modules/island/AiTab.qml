// IA tab of the dashboard: the agents running in herdr (state per agent, task, time in that state) and the code
// editors that are open. Data: services/Herdr.qml and services/EditorWatcher.qml. Click an agent = focus its pane,
// an editor = focus its window. herdr offline → "herdr sin conexión" (the editors still show).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    Component.onCompleted: EditorWatcher.setWatching(true)
    Component.onDestruction: EditorWatcher.setWatching(false)

    property real nowMs: Date.now()
    Timer { interval: 5000; running: root.visible; repeat: true; onTriggered: root.nowMs = Date.now() }
    function elapsed(since: real): string {
        if (!since) return "";
        const s = Math.max(0, Math.floor((root.nowMs - since) / 1000));
        if (s < 60) return `${s} s`;
        const m = Math.floor(s / 60);
        return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${m % 60} min`;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd

        // ---- agents ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingXs

            Row {
                spacing: Theme.spacingMd
                UiText {
                    visible: !Herdr.running
                    text: "herdr sin conexión"
                    color: Theme.textDim
                }
                UiText { visible: Herdr.running && Herdr.agents.length === 0; text: "Sin agentes"; color: Theme.textDim }
                Repeater {
                    model: Herdr.running ? ["working", "blocked", "done", "idle", "unknown"] : []
                    delegate: Row {
                        required property string modelData
                        visible: (Herdr.counts[modelData] ?? 0) > 0
                        spacing: 4
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Theme.agentColor(modelData) }
                        UiText { text: `${Herdr.counts[modelData] ?? 0} ${Theme.agentLabel(modelData)}`; size: Theme.sizeCaption + 1; color: Theme.textSoft }
                    }
                }
                UiText { visible: Herdr.running; text: `· ${Herdr.workspaces.length} workspaces`; size: Theme.sizeCaption + 1; color: Theme.textDim }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: agentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: agentCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: Herdr.agents
                        delegate: AgentRow {
                            required property var modelData
                            agent: modelData
                            elapsed: root.elapsed(modelData.since)
                            onClicked: Herdr.focusAgent(modelData)
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.hairline }

        // ---- editors ----
        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            spacing: Theme.spacingXs
            UiText { text: "Editores"; caption: true }
            UiText { visible: EditorWatcher.editors.length === 0; text: "Ninguno abierto"; color: Theme.textDim }
            Repeater {
                model: EditorWatcher.editors
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: edMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
                    Column {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20
                        UiText { width: parent.width; text: modelData.count > 1 ? `${modelData.name} (${modelData.count})` : modelData.name; size: Theme.sizeBody }
                        UiText { width: parent.width; text: modelData.kind === "process" ? "en una terminal" : `workspace ${modelData.workspace}`; size: Theme.sizeCaption; color: Theme.textDim }
                    }
                    MouseArea { id: edMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: modelData.toplevel ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: EditorWatcher.focus(modelData) }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
