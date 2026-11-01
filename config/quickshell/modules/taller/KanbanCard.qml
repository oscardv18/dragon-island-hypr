// One Kanban card: key, kind, agent badge, title, criteria bar and age. Drag positions are reported in `dragRoot`.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    property var card: ({})
    property var agent: null
    property bool selected: false
    property int criteriaDone: 0
    property int criteriaTotal: 0
    property string age: ""
    property Item dragRoot: null
    signal chosen()
    signal dragMoved(point p)
    signal dragEnded(point p)
    implicitHeight: content.implicitHeight + Theme.taller.cardPad * 2
    radius: Theme.taller.cardRadius
    color: selected ? Theme.taller.selected : (hit.containsMouse ? Theme.taller.hover : Theme.taller.card)
    border.width: Theme.taller.buttonBorder
    border.color: selected ? Theme.taller.selectedBorder : Theme.taller.border
    function kindTint(kind): color { return kind === "fix" ? Theme.taller.dangerTint : kind === "feat" ? Theme.taller.workingTint : kind === "docs" ? Theme.taller.idleTint : Theme.taller.button; }
    function kindColor(kind): color { return kind === "fix" ? Theme.danger : kind === "feat" ? Theme.cyan : kind === "docs" ? Theme.lavender : Theme.textDim; }
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.taller.cardPad
        spacing: Theme.taller.smallGap
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.smallGap
            UiText { text: root.card.key ?? ""; mono: true; size: Theme.taller.caption; color: Theme.textDim }
            Rectangle {
                implicitWidth: kind.implicitWidth + Theme.taller.chipPad
                implicitHeight: kind.implicitHeight + Theme.taller.thinGap
                radius: Theme.taller.badgeRadius
                color: root.kindTint(root.card.kind)
                border.width: Theme.taller.buttonBorder
                border.color: root.kindColor(root.card.kind)
                UiText { id: kind; anchors.centerIn: parent; text: root.card.kind ?? "feat"; mono: true; size: Theme.taller.caption; color: root.kindColor(root.card.kind) }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: !!root.agent || !!root.card.agent_ref
                implicitWidth: Theme.taller.agentBadge; implicitHeight: Theme.taller.agentBadge
                radius: Theme.taller.badgeRadius
                color: Theme.taller.button
                border.width: Theme.taller.buttonBorder
                border.color: root.agent ? Theme.agentColor(root.agent.state) : Theme.taller.border
                UiText { anchors.centerIn: parent; text: (root.agent?.kind ?? root.agent?.agent) === "codex" ? "X" : root.agent ? "C" : "·"; mono: true; size: Theme.taller.caption; color: root.agent ? Theme.agentColor(root.agent.state) : Theme.textDim }
            }
        }
        UiText { Layout.fillWidth: true; text: root.card.title ?? ""; size: Theme.taller.body; weight: Theme.weightSemiBold; wrapMode: Text.Wrap; maximumLineCount: 3 }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.rowGap
            Row {
                Layout.fillWidth: true
                spacing: Theme.taller.criteriaGap
                visible: root.criteriaTotal > 0
                Repeater {
                    model: Math.min(root.criteriaTotal, 8)
                    delegate: Rectangle {
                        required property int index
                        width: (parent.width - parent.spacing * (Math.min(root.criteriaTotal, 8) - 1)) / Math.min(root.criteriaTotal, 8)
                        height: Theme.taller.criteriaHeight
                        radius: height / 2
                        color: index < Math.round(root.criteriaDone * Math.min(root.criteriaTotal, 8) / root.criteriaTotal) ? (root.card.col === "done" || root.card.col === "review" ? Theme.ok : Theme.cyan) : Theme.taller.segmentEmpty
                    }
                }
            }
            Item { Layout.fillWidth: true; visible: root.criteriaTotal === 0 }
            UiText { text: root.age; mono: true; size: Theme.taller.caption; color: Theme.textDim }
        }
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: drag ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        property point origin
        property bool drag: false
        onPressed: m => { origin = Qt.point(m.x, m.y); drag = false; }
        onPositionChanged: m => {
            if (!pressed || !root.dragRoot) return;
            if (!drag && Math.abs(m.x - origin.x) + Math.abs(m.y - origin.y) > Theme.taller.dragThreshold) drag = true;
            if (drag) root.dragMoved(mapToItem(root.dragRoot, m.x, m.y));
        }
        onReleased: m => { if (drag && root.dragRoot) root.dragEnded(mapToItem(root.dragRoot, m.x, m.y)); }
        onClicked: if (!drag) root.chosen()
    }
}
