// Ring meter for the bar (CPU, RAM): a 1.8 px track (white 13 %) and the value as an arc from the top, clockwise.
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    property real value: 0          // 0..1
    property color color: Theme.cyan
    property real thickness: 1.8
    property int size: 15

    implicitWidth: size
    implicitHeight: size
    preferredRendererType: Shape.CurveRenderer

    readonly property real _r: (Math.min(width, height) - thickness) / 2
    property real _shown: Math.max(0, Math.min(1, value))
    Behavior on _shown { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

    ShapePath {
        fillColor: Theme.transparent
        strokeColor: Qt.rgba(1, 1, 1, 0.13)
        strokeWidth: root.thickness
        PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root._r; radiusY: root._r; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        fillColor: Theme.transparent
        strokeColor: root.color
        strokeWidth: root.thickness
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root._r; radiusY: root._r; startAngle: -90; sweepAngle: 360 * root._shown }
    }
}
