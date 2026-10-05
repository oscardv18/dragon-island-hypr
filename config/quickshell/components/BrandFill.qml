// Rounded rectangle filled with the 135° brand gradient (accent → violet).
// QtQuick.Shapes (PathRectangle + LinearGradient): native Qt 6, no Qt5Compat / shader effects.
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    property real radius: 0
    property var stops: Theme.brandStops

    // 135°: direction (1, 1); the gradient line is long enough to reach both corners
    readonly property real _h: (width + height) / 4

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
            x1: root.width / 2 - root._h
            y1: root.height / 2 - root._h
            x2: root.width / 2 + root._h
            y2: root.height / 2 + root._h
            GradientStop { position: 0.0; color: root.stops[0] }
            GradientStop { position: 1.0; color: root.stops[root.stops.length - 1] }
        }
        PathRectangle {
            x: 0
            y: 0
            width: root.width
            height: root.height
            radius: Math.min(root.radius, root.width / 2, root.height / 2)
        }
    }
}
