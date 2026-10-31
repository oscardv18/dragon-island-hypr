// Four cyan corner brackets of the HUD frame (12 px arms, 1.5 px stroke, radius 6), inset a little from the corners.
// `grow` 1 → 0 slides them in from a few px outside while they fade in.
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property real grow: 0
    readonly property real _i: Theme.hudBracketInset - 4 * grow
    readonly property real _l: Theme.hudBracket
    readonly property real _r: Theme.hudBracketRadius

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // top-left
        ShapePath {
            fillColor: Theme.transparent; strokeColor: Theme.cyan; strokeWidth: Theme.hudBracketStroke; capStyle: ShapePath.FlatCap
            startX: root._i; startY: root._i + root._l
            PathLine { x: root._i; y: root._i + root._r }
            PathArc { x: root._i + root._r; y: root._i; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._i + root._l; y: root._i }
        }
        // top-right
        ShapePath {
            fillColor: Theme.transparent; strokeColor: Theme.cyan; strokeWidth: Theme.hudBracketStroke; capStyle: ShapePath.FlatCap
            startX: root.width - root._i - root._l; startY: root._i
            PathLine { x: root.width - root._i - root._r; y: root._i }
            PathArc { x: root.width - root._i; y: root._i + root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width - root._i; y: root._i + root._l }
        }
        // bottom-right
        ShapePath {
            fillColor: Theme.transparent; strokeColor: Theme.cyan; strokeWidth: Theme.hudBracketStroke; capStyle: ShapePath.FlatCap
            startX: root.width - root._i; startY: root.height - root._i - root._l
            PathLine { x: root.width - root._i; y: root.height - root._i - root._r }
            PathArc { x: root.width - root._i - root._r; y: root.height - root._i; radiusX: root._r; radiusY: root._r }
            PathLine { x: root.width - root._i - root._l; y: root.height - root._i }
        }
        // bottom-left
        ShapePath {
            fillColor: Theme.transparent; strokeColor: Theme.cyan; strokeWidth: Theme.hudBracketStroke; capStyle: ShapePath.FlatCap
            startX: root._i + root._l; startY: root.height - root._i
            PathLine { x: root._i + root._r; y: root.height - root._i }
            PathArc { x: root._i; y: root.height - root._i - root._r; radiusX: root._r; radiusY: root._r }
            PathLine { x: root._i; y: root.height - root._i - root._l }
        }
    }
}
