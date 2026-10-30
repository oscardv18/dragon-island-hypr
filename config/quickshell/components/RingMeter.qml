// Ring meter for the bar (CPU, RAM): a 1.8 px track (white 13 %) and the value as an arc from the top, clockwise.
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    property real value: 0          // 0..1
    property color color: Theme.cyan
    property real thickness: Theme.barRingWidth
    property int size: Theme.barRing

    implicitWidth: size
    implicitHeight: size
    preferredRendererType: Shape.CurveRenderer

    // from `size`, never width / height: a Shape sizes itself from its path (binding loop)
    readonly property real _r: (size - thickness) / 2
    property real _shown: Math.max(0, Math.min(1, value))
    Behavior on _shown { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

    ShapePath {
        fillColor: Theme.transparent
        strokeColor: Theme.trackFaint
        strokeWidth: root.thickness
        PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root._r; radiusY: root._r; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        fillColor: Theme.transparent
        strokeColor: root.color
        strokeWidth: root.thickness
        capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root._r; radiusY: root._r; startAngle: -90; sweepAngle: 360 * root._shown }
    }
}
