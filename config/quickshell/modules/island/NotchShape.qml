// Notch silhouette: top edge flush with the screen, concave "ears" (inverse fillets, r = earRadius)
// at both top corners, convex bottom corners (r = bottomRadius). Drawn with ShapePath + PathArc.
// The Item's width includes the ears: the body is `width − 2 × earRadius` wide.
// While the notch is still growing (height < ears + bottom radius) the radii shrink with it.
import QtQuick
import QtQuick.Shapes
import "../.."

Shape {
    id: root

    property real earRadius: Theme.notchEarRadius
    property real bottomRadius: Theme.notchRadius
    property color color: Theme.island

    readonly property real _s: Math.max(0, Math.min(1, height / Math.max(1, earRadius + bottomRadius)))
    readonly property real _ear: earRadius * _s
    readonly property real _bot: Math.min(bottomRadius * _s, Math.max(0, (width - 2 * _ear) / 2))

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: Theme.transparent
        strokeWidth: -1

        startX: 0
        startY: 0
        // top edge, flush with the screen
        PathLine { x: root.width; y: 0 }
        // right ear (concave)
        PathArc { x: root.width - root._ear; y: root._ear; radiusX: root._ear; radiusY: root._ear; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root._ear; y: root.height - root._bot }
        // bottom-right corner
        PathArc { x: root.width - root._ear - root._bot; y: root.height; radiusX: root._bot; radiusY: root._bot; direction: PathArc.Clockwise }
        PathLine { x: root._ear + root._bot; y: root.height }
        // bottom-left corner
        PathArc { x: root._ear; y: root.height - root._bot; radiusX: root._bot; radiusY: root._bot; direction: PathArc.Clockwise }
        PathLine { x: root._ear; y: root._ear }
        // left ear (concave)
        PathArc { x: 0; y: 0; radiusX: root._ear; radiusY: root._ear; direction: PathArc.Counterclockwise }
    }
}
