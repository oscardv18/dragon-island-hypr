// Notch silhouette, drawn with ShapePath + PathArc.
//   attached (styles A, C): top edge flush with the screen, concave "ears" (inverse fillets, r = earRadius) at both
//     top corners, convex bottom corners (r = bottomRadius). The Item's width includes the ears: the body is
//     `width − 2 × earRadius` wide.
//   floating (styles B, D): a pill / rounded rectangle away from the edge: no ears, top corners r = topRadius.
// While the notch is still growing (height < radii) the radii shrink with it.
import QtQuick
import QtQuick.Shapes
import "../.."

Shape {
    id: root

    property bool attached: true
    property real earRadius: Theme.notchEarRadius
    property real bottomRadius: Theme.notchRadius
    property real topRadius: bottomRadius        // floating only
    property color color: Theme.island

    readonly property real _s: Math.max(0, Math.min(1, height / Math.max(1, (attached ? earRadius : topRadius) + bottomRadius)))
    readonly property real _ear: attached ? earRadius * _s : 0
    readonly property real _top: attached ? 0 : Math.min(topRadius * _s, width / 2, height / 2)
    readonly property real _bot: Math.min(bottomRadius * _s, Math.max(0, (width - 2 * _ear) / 2), attached ? height : height / 2)

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: Theme.transparent
        strokeWidth: -1

        startX: root._top
        startY: 0
        // top edge (flush with the screen when attached)
        PathLine { x: root.width - root._top; y: 0 }
        // floating: top-right corner (convex) · attached: zero length
        PathArc { x: root.width; y: root._top; radiusX: root._top; radiusY: root._top; direction: PathArc.Clockwise }
        // attached: right ear (concave) · floating: zero length
        PathArc { x: root.width - root._ear; y: root._top + root._ear; radiusX: root._ear; radiusY: root._ear; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root._ear; y: root.height - root._bot }
        // bottom-right corner
        PathArc { x: root.width - root._ear - root._bot; y: root.height; radiusX: root._bot; radiusY: root._bot; direction: PathArc.Clockwise }
        PathLine { x: root._ear + root._bot; y: root.height }
        // bottom-left corner
        PathArc { x: root._ear; y: root.height - root._bot; radiusX: root._bot; radiusY: root._bot; direction: PathArc.Clockwise }
        PathLine { x: root._ear; y: root._top + root._ear }
        // attached: left ear (concave) · floating: zero length
        PathArc { x: 0; y: root._top; radiusX: root._ear; radiusY: root._ear; direction: PathArc.Counterclockwise }
        // floating: top-left corner (convex)
        PathArc { x: root._top; y: 0; radiusX: root._top; radiusY: root._top; direction: PathArc.Clockwise }
    }
}
