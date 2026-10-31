// The notification drops, drawn in the island window (dragon-island: full width, never blurred) so the drop can cross
// from the notch to a card in another window (services/NotifFx.qml). A 12 px cyan dot with a glow on a shallow curve:
// out = notch → card top (440 ms, orbita); in = card top → notch (320 ms, salida). No input.
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"

Item {
    id: root
    property string screenName: ""
    property real fromX: width / 2       // the notch's bottom centre
    property real fromY: 0

    Repeater {
        model: NotifFx.flights.filter(f => f.screen === root.screenName)
        delegate: Item {
            id: flight
            required property var modelData
            readonly property bool out: modelData.dir === "out"
            property real t: 0
            // quadratic curve: leaves the notch downwards, arrives on the card from above
            readonly property real ax: out ? root.fromX : modelData.x
            readonly property real ay: out ? root.fromY : modelData.y
            readonly property real bx: out ? modelData.x : root.fromX
            readonly property real by: out ? modelData.y : root.fromY
            readonly property real cx: out ? ax : bx
            readonly property real cy: Math.max(ay, by) + Theme.notifDropArc
            readonly property real px: (1 - t) * (1 - t) * ax + 2 * (1 - t) * t * cx + t * t * bx
            readonly property real py: (1 - t) * (1 - t) * ay + 2 * (1 - t) * t * cy + t * t * by

            RectangularShadow {
                x: flight.px - width / 2
                y: flight.py - height / 2
                width: Theme.notifDrop
                height: Theme.notifDrop
                radius: width / 2
                blur: Theme.hudBeamGlow * 1.5
                color: Theme.haloCyan
            }
            Rectangle {
                x: flight.px - width / 2
                y: flight.py - height / 2
                width: Theme.notifDrop
                height: Theme.notifDrop
                radius: width / 2
                color: Theme.cyan
            }

            NumberAnimation on t {
                from: 0; to: 1
                duration: flight.out ? Theme.durDropOut : Theme.durDropIn
                easing.type: Easing.BezierSpline
                easing.bezierCurve: flight.out ? Theme.curveOrbita : Theme.curveSalida
                onFinished: flight.out ? NotifFx.landed(flight.modelData.id) : NotifFx.home(flight.modelData.id)
            }
        }
    }
}
