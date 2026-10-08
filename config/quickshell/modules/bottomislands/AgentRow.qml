// One agent in the "Estado de IA" popover: state dot · type (+ task title) · how long it has been in this state.
// Pure visual. `elapsed` is already formatted ("" = unknown: nothing is shown).
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root

    property var agent: null
    property string elapsed: ""
    signal clicked()

    width: parent ? parent.width : 280
    height: 40
    radius: 8
    color: mouse.containsMouse ? Theme.surfaceHi : Theme.transparent

    Rectangle {
        id: dot
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: Theme.agentColor(root.agent?.state ?? "")
    }
    Column {
        x: 28
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 28 - timeText.width - 18
        UiText { width: parent.width; text: root.agent?.agent ?? root.agent?.name ?? ""; size: Theme.sizeBody; weight: Theme.weightSemiBold }
        UiText {
            width: parent.width
            text: (root.agent?.title ?? "") !== "" ? root.agent.title : Theme.agentLabel(root.agent?.state ?? "")
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }
    }
    UiText {
        id: timeText
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.elapsed
        mono: true
        size: Theme.sizeCaption + 1
        color: Theme.textSoft
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
