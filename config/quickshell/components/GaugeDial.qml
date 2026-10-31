// The 270° dial of Rendimiento (docs/design/28-emergentes.png): a track from 7:30 to 4:30 clockwise, the value arc in
// cyan (warn past warnAt), tick marks outside it, the big percentage and a caption in the centre. `fill` (0 → 1, the
// frame's `filled`) sweeps the arc in after the rows.
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real value: 0              // 0..1
    property string label: "CPU"
    property color color: Theme.cyan
    property real warnAt: 0.85
    property real fill: 1
    property int size: Theme.hudGauge
    property real thickness: 7
    property int ticks: 28

    implicitWidth: size
    implicitHeight: size

    readonly property real _c: size / 2
    readonly property real _r: size / 2 - 14            // the arc (ticks sit outside it)
    readonly property color _stroke: value > warnAt ? Theme.warn : color
    property real _shown: Math.max(0, Math.min(1, value)) * Math.max(0, Math.min(1, fill))
    Behavior on _shown { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

    // tick marks: every 270 / ticks degrees, the lit ones in the arc colour
    Repeater {
        model: root.ticks + 1
        delegate: Rectangle {
            required property int index
            readonly property real ang: (135 + 270 * index / root.ticks) * Math.PI / 180
            readonly property bool lit: index / root.ticks <= root._shown + 0.0001 && root._shown > 0
            width: 1.5
            height: index % 7 === 0 ? 6 : 4
            radius: 0.75
            color: lit ? Theme.alpha(root._stroke, 0.9) : Theme.hudSegOff
            x: root._c + Math.cos(ang) * (root._r + 9) - width / 2
            y: root._c + Math.sin(ang) * (root._r + 9) - height / 2
            rotation: (ang * 180 / Math.PI) + 90
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: Theme.hudSegOff
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root._c; centerY: root._c; radiusX: root._r; radiusY: root._r; startAngle: 135; sweepAngle: 270 }
        }
        ShapePath {
            fillColor: Theme.transparent
            strokeColor: root._stroke
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root._c; centerY: root._c; radiusX: root._r; radiusY: root._r; startAngle: 135; sweepAngle: Math.max(0.5, 270 * root._shown) }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: Math.round(root.value * 100)
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.size * 0.24)
                font.weight: Theme.weightSemiBold
            }
            Text {
                text: "%"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Math.round(root.size * 0.11)
                anchors.baseline: parent.children[0].baseline
            }
        }
        HudCaption { anchors.horizontalCenter: parent.horizontalCenter; text: root.label }
    }
}
