// Ring meter for the bar (CPU, RAM), read as a gauge (docs/design/19-islas.png) and never as a loading spinner:
// the full ring is a fixed track (white 15 %, always visible) and the value is an arc that starts at 12 o'clock and
// grows clockwise with FLAT ends (round caps on a short arc read as a spinner). A short tick marks where it starts.
// The number shows in the centre while hovered (`showValue`) and always in the «amplia» bar size.
// Above warnAt (85 %) the arc turns warn. Thickness and size follow Settings.barSize. The value moves with the
// Estándar curve; the ring itself never spins.
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root

    property real value: 0          // 0..1
    property color color: Theme.cyan
    property real warnAt: 0.85
    property real thickness: Theme.barRingWidth
    property int size: Theme.barRing
    property bool showValue: false  // the number in the centre (the bar: hover, or always in «amplia»)
    property bool startTick: true
    readonly property color _stroke: value > warnAt ? Theme.warn : color

    implicitWidth: size
    implicitHeight: size

    // from `size`, never width / height: a Shape sizes itself from its path (binding loop)
    readonly property real _r: (size - thickness) / 2
    property real _shown: Math.max(0, Math.min(1, value))
    Behavior on _shown { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.showValue ? Theme.ringDimmed : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }

        ShapePath {
            fillColor: Theme.transparent
            strokeColor: Theme.trackFaint
            strokeWidth: root.thickness
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root._r; radiusY: root._r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: root._stroke
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root._r; radiusY: root._r; startAngle: -90; sweepAngle: Math.max(Theme.ringMinSweep, 360 * root._shown) }
        }
    }

    // where the gauge starts: a short tick across the track at 12 o'clock
    Rectangle {
        visible: root.startTick
        x: root.size / 2 - width / 2
        y: 0
        width: 1
        height: root.thickness + 1
        color: Theme.alpha(root._stroke, 0.9)
    }

    Text {
        anchors.centerIn: parent
        visible: opacity > 0.01
        opacity: root.showValue ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
        text: Math.round(root.value * 100)
        color: Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Math.max(7, Math.round((root.size - root.thickness * 2) * Theme.ringValueScale * (root.value >= 0.995 ? 0.8 : 1)))
        font.weight: Theme.weightSemiBold
    }
}
