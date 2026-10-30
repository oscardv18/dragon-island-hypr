// On/off switch: cyan tint + 1 px cyan edge when on (mockup 08-ajustes), neutral track when off
import QtQuick
import ".."

Item {
    id: root
    property bool checked: false
    signal toggled()

    implicitWidth: Theme.switchWidth
    implicitHeight: Theme.switchHeight
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.text, 0.10)
        visible: !root.checked
    }

    AccentFill {
        anchors.fill: parent
        radius: height / 2
        visible: root.checked
        color: Theme.alpha(Theme.cyan, 0.30)
        border.color: Theme.alpha(Theme.cyan, 0.55)
    }

    Rectangle {
        width: root.height - Theme.knobInset * 2
        height: width
        radius: width / 2
        y: Theme.knobInset
        x: root.checked ? root.width - width - Theme.knobInset : Theme.knobInset
        color: root.checked ? Theme.text : Theme.textSoft
        Behavior on x { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.toggled()
    }
}
