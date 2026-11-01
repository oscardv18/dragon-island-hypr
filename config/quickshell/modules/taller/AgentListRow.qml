// One agent in the Taller queue. Pure visual, no services or commands.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    property var agent: null
    property bool selected: false
    property bool seen: false
    property string elapsed: ""
    property bool helper: false
    signal chosen()
    signal focusRequested()
    readonly property string state: agent?.state ?? "unknown"
    readonly property color tone: Theme.agentColor(state)
    implicitHeight: helper ? Theme.taller.helperHeight : Theme.taller.rowHeight
    radius: Theme.taller.buttonRadius
    color: selected ? Theme.taller.selected : (hit.containsMouse ? Theme.taller.hover : Theme.taller.card)
    border.width: Theme.taller.buttonBorder
    border.color: selected ? Theme.taller.selectedBorder : Theme.transparent
    activeFocusOnTab: true
    Keys.onReturnPressed: focusRequested()
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: root.chosen() }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.taller.inset + (root.helper ? Theme.taller.rowIndent : 0)
        anchors.rightMargin: Theme.taller.inset
        spacing: Theme.taller.inset
        Rectangle { implicitWidth: Theme.taller.dot; implicitHeight: width; radius: width / 2; color: root.tone }
        Rectangle {
            implicitWidth: Theme.taller.badge; implicitHeight: width
            radius: Theme.taller.badgeRadius
            color: root.agent?.kind === "claude" ? Theme.taller.idleTint : Theme.taller.workingTint
            border.width: Theme.taller.buttonBorder
            border.color: root.agent?.kind === "claude" ? Theme.lavender : Theme.cyan
            UiText { anchors.centerIn: parent; text: root.agent?.kind === "claude" ? "C" : root.agent?.kind === "codex" ? "X" : "·"; mono: true; size: Theme.taller.body; color: Theme.lavender }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.thinGap
            UiText { Layout.fillWidth: true; text: (root.helper ? "└ ayudante: " : "") + (root.agent?.branch || root.agent?.name || "Sin rama"); mono: !root.helper; size: Theme.taller.body; weight: Theme.weightSemiBold }
            UiText { Layout.fillWidth: true; visible: !root.helper; text: [root.agent?.card, root.agent?.note || root.agent?.title || "Sin tarea"].filter(x => x).join(" · "); color: Theme.textDim; size: Theme.taller.caption }
        }
        UiText {
            Layout.maximumWidth: Theme.taller.stateWidth
            text: root.state === "blocked" ? "BLOQUEADO" : root.state === "working" ? "TRABAJANDO" : root.state === "done" ? (root.seen ? "LISTO · VISTO" : "LISTO · SIN VER") : "EN REPOSO"
            color: root.tone; mono: true; size: Theme.taller.caption
        }
        UiText { text: root.elapsed; mono: true; size: Theme.taller.caption; color: Theme.textDim }
        TallerButton { visible: root.state === "blocked"; label: "Ir ↵"; tone: Theme.warn; onClicked: root.focusRequested() }
    }
}
