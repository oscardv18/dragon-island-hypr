// Compact agent attention pill. Pure view; caller owns focus/snooze actions. No animation while idle.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Item {
    id: root
    property var agent: null
    property real maxWidth: Theme.taller.attentionWidth
    property real now: Date.now()
    signal focusRequested()
    signal ignoreRequested()
    implicitWidth: Math.min(Theme.taller.attentionWidth, maxWidth)
    implicitHeight: Theme.taller.attentionHeight
    readonly property bool blocked: (agent?.state ?? "blocked") === "blocked"
    readonly property color tone: blocked ? Theme.warn : Theme.ok
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.ignoreRequested(); else root.focusRequested(); }
    }
    RowLayout {
        anchors.fill: parent
        spacing: Theme.taller.rowGap
        Rectangle { implicitWidth: Theme.taller.dot; implicitHeight: width; radius: width / 2; color: root.tone }
        UiText {
            Layout.fillWidth: true
            text: `${root.agent?.kind || root.agent?.agent || "Un agente"} ${root.blocked ? "pide aprobación" : "terminó · sin ver"}${root.agent?.card ? " · " + root.agent.card : ""} · ${Math.max(0, Math.round((root.now - (root.agent?.since ?? root.now))/60000))} min`
            size: Theme.taller.body
            weight: Theme.weightMedium
        }
        Rectangle {
            implicitWidth: Theme.taller.attentionButtonWidth
            implicitHeight: Theme.taller.attentionHeight - Theme.taller.rowGap
            radius: height / 2
            color: Theme.taller.blockedTint
            border.width: Theme.taller.buttonBorder
            border.color: root.tone
            UiText { anchors.centerIn: parent; text: "Ir ↵"; size: Theme.taller.body; color: root.tone }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.focusRequested() }
        }
    }
}
