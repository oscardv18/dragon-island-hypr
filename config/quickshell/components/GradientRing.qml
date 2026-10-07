// A contour in the window-border gradient (accent → violet → cyan), as thin as you like, around a rounded shape.
// The gradient is masked by a ring: border-only Rectangle of the same radius. `strength` fades it (0.4 = subtle).
import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property real radius: width / 2
    property real ringWidth: 1.5
    property real strength: 1.0

    anchors.fill: parent

    BorderGradient { id: source; anchors.fill: parent }

    Rectangle {
        id: ring
        anchors.fill: parent
        radius: root.radius
        color: Theme.transparent
        border.width: root.ringWidth
        border.color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
        antialiasing: true
    }

    MultiEffect {
        anchors.fill: parent
        source: source
        maskEnabled: true
        maskSource: ring
        opacity: root.strength
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
    }
}
