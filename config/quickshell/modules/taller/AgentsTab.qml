// Agent queue grouped by herdr space, with a memory-only pane preview. Injectable service for visual tests.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Item {
    id: root
    property var service: null
    property bool shown: false
    property string selectedId: ""
    property real now: Date.now()
    readonly property var agents: service?.agents ?? []
    readonly property var selected: agents.find(a => a.pane === selectedId) ?? agents[0] ?? null
    readonly property var listRows: {
        const groups = {}, result = [];
        const rank = a => ({blocked: 0, done: 1, working: 2, idle: 3, unknown: 4})[a.state] ?? 5;
        for (const a of agents) {
            const key = a.space || a.workspace || "Sin proyecto";
            if (!groups[key]) groups[key] = [];
            groups[key].push(a);
        }
        const names = Object.keys(groups).sort((a,b) => Math.min(...groups[a].map(rank)) - Math.min(...groups[b].map(rank)) || a.localeCompare(b));
        for (const name of names) {
            const group = groups[name].slice().sort((a,b) => rank(a)-rank(b) || a.since-b.since);
            result.push({ group: true, name: name, count: group.length, state: group[0]?.state });
            const placed = {};
            function append(a) {
                if (placed[a.pane]) return;
                placed[a.pane] = true;
                result.push({ group: false, agent: a });
                for (const helper of group.filter(h => h.helper_of === a.pane)) append(helper);
            }
            for (const a of group.filter(a => !a.helper_of || !group.some(p => p.pane === a.helper_of))) append(a);
            for (const a of group) append(a);
        }
        return result;
    }
    function elapsed(a): string {
        const minutes = Math.max(0, Math.round((now - (a?.since ?? now))/60000));
        return minutes < 1 ? "ahora" : minutes < 60 ? `${minutes} min` : `${Math.floor(minutes/60)} h`;
    }
    function readSelected(): void { if (shown && selected) service?.readAgent(selected); }
    onSelectedChanged: if (selected?.pane !== service?.readId) readSelected()
    onShownChanged: { if (shown) Qt.callLater(readSelected); else service?.clearRead(); }
    Timer { interval: 30000; repeat: true; running: root.shown; onTriggered: root.now = Date.now() }
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            const items = listRows.filter(r => !r.group).map(r => r.agent);
            const i = items.findIndex(a => a.pane === selected?.pane);
            const n = Math.max(0,Math.min(items.length-1,i+(e.key === Qt.Key_Down ? 1 : -1)));
            if (items[n]) selectedId = items[n].pane;
            e.accepted = true;
        } else if (e.key === Qt.Key_Return && selected) { service?.focusAgent(selected); e.accepted = true; }
    }
    RowLayout {
        anchors.fill: parent
        spacing: Theme.taller.gap
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: root.width * Theme.taller.leftFraction
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                UiText { text: "COLA DE ATENCIÓN"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.textDim; Layout.fillWidth: true }
                UiText { text: `${root.service?.counts?.blocked ?? 0} BLOQUEADO`; color: Theme.warn; mono: true; size: Theme.taller.caption }
                UiText { text: `${root.service?.counts?.done ?? 0} LISTO`; color: Theme.ok; mono: true; size: Theme.taller.caption }
                UiText { text: `${root.service?.counts?.working ?? 0} TRABAJANDO`; color: Theme.textDim; mono: true; size: Theme.taller.caption }
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.rowGap
                model: root.listRows
                delegate: Loader {
                    required property var modelData
                    width: list.width
                    height: modelData.group ? Theme.taller.groupHeight : (modelData.agent.helper_of ? Theme.taller.helperHeight : Theme.taller.rowHeight)
                    sourceComponent: modelData.group ? groupView : agentView
                    Component {
                        id: groupView
                        RowLayout {
                            spacing: Theme.taller.rowGap
                            UiText { text: "▪ " + modelData.name; weight: Theme.weightSemiBold; size: Theme.taller.body }
                            UiText { text: `${modelData.count} AGENTES · SPACE`; color: Theme.textDim; mono: true; size: Theme.taller.caption }
                            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.taller.buttonBorder; color: Theme.taller.border }
                            UiText { text: modelData.state === "blocked" ? "BLOQUEADO" : modelData.state === "done" ? "LISTO" : modelData.state === "working" ? "TRABAJANDO" : "REPOSO"; color: Theme.agentColor(modelData.state); mono: true; size: Theme.taller.caption }
                        }
                    }
                    Component {
                        id: agentView
                        AgentListRow {
                            agent: modelData.agent
                            helper: !!agent.helper_of
                            selected: agent.pane === root.selected?.pane
                            elapsed: root.elapsed(agent)
                            seen: (root.service?._seen?.[agent.pane] ?? 0) === agent.since
                            onChosen: { root.selectedId = agent.pane; root.forceActiveFocus(); }
                            onFocusRequested: root.service?.focusAgent(agent)
                        }
                    }
                }
                UiText {
                    anchors.centerIn: parent
                    visible: root.agents.length === 0
                    text: root.service?.message || "No hay agentes activos"
                    color: Theme.textDim
                    size: Theme.taller.body
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: root.width * (1 - Theme.taller.leftFraction)
            Layout.fillHeight: true
            spacing: Theme.taller.gap
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.taller.detailsHeight
                radius: Theme.taller.buttonRadius
                color: Theme.taller.card
                border.width: Theme.taller.buttonBorder
                border.color: Theme.taller.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.detailPadding
                    spacing: Theme.taller.rowGap
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: root.selected?.branch || root.selected?.name || "Selecciona un agente"; mono: true; size: Theme.taller.heading; weight: Theme.weightSemiBold }
                        UiText { text: Theme.agentLabel(root.selected?.state ?? "unknown"); color: Theme.agentColor(root.selected?.state ?? "unknown"); size: Theme.taller.caption }
                    }
                    UiText { Layout.fillWidth: true; text: [root.selected?.space || root.selected?.workspace, root.selected?.card].filter(x => x).join(" · "); color: Theme.textDim; size: Theme.taller.caption }
                    RowLayout {
                        UiText { Layout.fillWidth: true; text: "ÚLTIMA SALIDA DEL PANEL"; mono: true; font.letterSpacing: Theme.taller.captionTracking; size: Theme.taller.caption; color: Theme.textDim }
                        TallerButton { label: "↻"; enabled: !!root.selected; onClicked: root.readSelected() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.taller.buttonRadius
                        color: Theme.taller.output
                        Flickable {
                            anchors.fill: parent
                            anchors.margins: Theme.taller.inset
                            clip: true
                            contentWidth: width
                            contentHeight: output.implicitHeight
                            UiText {
                                id: output
                                width: parent.width
                                text: root.service?.readText || (root.selected ? "Leyendo el panel…" : "La salida se muestra aquí y no se guarda")
                                mono: true
                                size: Theme.taller.mono
                                color: Theme.textSoft
                                maximumLineCount: 200
                                wrapMode: Text.WrapAnywhere
                                lineHeight: Theme.taller.lineHeight
                            }
                        }
                    }
                    RowLayout {
                        spacing: Theme.taller.smallGap
                        TallerButton { label: "Ir al panel ↵"; primary: true; enabled: !!root.selected; onClicked: root.service?.focusAgent(root.selected) }
                        TallerButton { label: "Preparar prompt"; enabled: false }
                        TallerButton { label: "Ver cambios"; enabled: false }
                        TallerButton { label: "Marcar como visto"; enabled: root.selected?.state === "done"; onClicked: root.service?.markSeen(root.selected) }
                    }
                }
            }
            UiText { Layout.fillWidth: true; visible: (root.service?.actionError ?? "").length > 0; text: root.service?.actionError ?? ""; color: Theme.danger; size: Theme.taller.body; maximumLineCount: 3; wrapMode: Text.Wrap }
            UiText { Layout.fillWidth: true; text: "ESTADOS  ● bloqueado · ● trabajando · ● listo sin ver · ● en reposo"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
            Item { Layout.fillHeight: true }
        }
    }
}
