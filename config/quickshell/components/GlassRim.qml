// Crystal depth for rounded shapes (pills, capsules, discs). hyprglass derives its rim from the layer's rectangle,
// not from the shape inside it, so curved Quickshell shapes would look flat: this draws the light itself —
// a soft highlight falling from the top and a faint dark line just inside the lower edge (thickness). The contour
// itself is a GradientRing (the window-border gradient), not white. Put it on top of the shape's fill, same radius.
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
