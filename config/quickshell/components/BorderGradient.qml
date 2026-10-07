// The window-border gradient (accent → violet → cyan, 135°) as a plain fill, to be used as the source of a mask
// (see GradientRing). Hidden by itself: it needs layer.enabled to be a mask / effect source.
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    readonly property real _h: (width + height) / 4

    preferredRendererType: Shape.CurveRenderer
    visible: false
    layer.enabled: true

    ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
            x1: root.width / 2 - root._h
            y1: root.height / 2 - root._h
            x2: root.width / 2 + root._h
            y2: root.height / 2 + root._h
            GradientStop { position: 0.0; color: Theme.borderStops[0] }
            GradientStop { position: 0.5; color: Theme.borderStops[1] }
            GradientStop { position: 1.0; color: Theme.borderStops[2] }
        }
        PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
    }
}
