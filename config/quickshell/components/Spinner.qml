// Small cyan spinner (working agent, running command): a quarter arc on a faint ring, turning while visible.
// With motionScale 0 it stays still.
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real size: 16
    property color color: Theme.cyan
    implicitWidth: size
    implicitHeight: size

    Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.transparent; border.width: 2; border.color: Theme.alpha(root.color, 0.18) }
    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: root.color
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 1; radiusY: radiusX; startAngle: -90; sweepAngle: 100 }
        }
        RotationAnimation on rotation {
            running: root.visible && Theme.animationsEnabled
            from: 0
            to: 360
            duration: Theme.durSpin
            loops: Animation.Infinite
        }
    }
}
