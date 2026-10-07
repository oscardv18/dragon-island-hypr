// Crystal edge for rounded shapes (pills, capsules, discs). hyprglass derives its rim from the layer's rectangle,
// not from the shape inside it, so curved Quickshell shapes would look flat: this draws the light itself —
// a soft highlight falling from the top, a thin bright rim on the upper half (light from above) and a faint dark
// line just inside the lower edge (thickness). Put it on top of the shape's fill, same radius.
import QtQuick
import ".."

Item {
    id: root

    property real radius: width / 2
    property real strength: 1.0         // 0..1 overall

    anchors.fill: parent

    // light falling from the top
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.26 * root.strength) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.05 * root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
    // the rim all around, faint
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.transparent
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2 * root.strength)
    }
    // the bright rim, upper half only
    Item {
        width: parent.width
        height: parent.height * 0.55
        clip: true
        Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
            color: Theme.transparent
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.55 * root.strength)
        }
    }
    // thickness: a dark line just inside the lower edge
    Item {
        y: parent.height * 0.45
        width: parent.width
        height: parent.height * 0.55
        clip: true
        Rectangle {
            y: -parent.y
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 1
            width: root.width - 2
            height: root.height - 2
            radius: Math.max(0, root.radius - 1)
            color: Theme.transparent
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25 * root.strength)
        }
    }
}
