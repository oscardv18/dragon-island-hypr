// A band bent along a circle (the dock's semi-donut): outer arc, the screen edge, inner arc back. The circle's
// centre is `outerR` below the band's top, the base line is at y = height. Used three times with the same
// geometry: fill, light and inset rim (see DockWindow).
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    property real outerR: 360
    property real innerR: 290
    property real inset: 0                 // shrinks the band by this many px on every side (for the inner rim)
    property color fill: Theme.transparent
    property color stroke: Theme.transparent
    property real strokeWidth: 1
    property bool light: false             // vertical white gradient instead of a flat fill

    preferredRendererType: Shape.CurveRenderer

    readonly property real w: width
    readonly property real h: height
    readonly property real ro: outerR - inset
    readonly property real ri: innerR + inset
    readonly property real d: outerR - h                              // centre → base line
    readonly property real xo: Math.sqrt(Math.max(0, ro * ro - d * d))
    readonly property real xi: Math.sqrt(Math.max(0, ri * ri - d * d))

    ShapePath {
        fillColor: root.light ? Theme.transparent : root.fill
        fillGradient: root.light ? lightGradient : null
        strokeColor: root.stroke
        strokeWidth: root.strokeWidth
        startX: root.w / 2 - root.xo
        startY: root.h
        PathArc { x: root.w / 2 + root.xo; y: root.h; radiusX: root.ro; radiusY: root.ro; direction: PathArc.Clockwise }
        PathLine { x: root.w / 2 + root.xi; y: root.h }
        PathArc { x: root.w / 2 - root.xi; y: root.h; radiusX: root.ri; radiusY: root.ri; direction: PathArc.Counterclockwise }
        PathLine { x: root.w / 2 - root.xo; y: root.h }
    }

    LinearGradient {
        id: lightGradient
        x1: 0; y1: 0; x2: 0; y2: root.h
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.30) }
        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.07) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
    }
}
