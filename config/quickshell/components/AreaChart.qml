// Area chart of the HUD panels (Rendimiento «CPU · 60 s», Wi‑Fi traffic): a 1.5 px line over a vertical gradient that
// fades to transparent. `samples` are 0..`max` (max 0 = the largest sample). Repaints only when the samples change
// (every 2 s), never per frame. `fill` (0 → 1) reveals it from the left after the rows.
import QtQuick
import QtQuick.Shapes
import ".."

Item {
    id: root
    property var samples: []
    property real max: 100
    property color color: Theme.cyan
    property real fill: 1
    property real lineWidth: 1.5

    implicitHeight: Theme.hudChart
    implicitWidth: 200
    clip: true

    readonly property real _max: root.max > 0 ? root.max : Math.max(1, ...root.samples)
    readonly property var _pts: {
        const n = root.samples.length, w = root.width, h = root.height - root.lineWidth;
        if (n < 2 || w <= 0) return [Qt.point(0, h), Qt.point(w, h)];
        const pts = [];
        for (let i = 0; i < n; i++)
            pts.push(Qt.point(w * i / (n - 1), root.lineWidth / 2 + h * (1 - Math.min(1, root.samples[i] / root._max))));
        return pts;
    }

    Item {
        width: root.width * Math.max(0, Math.min(1, root.fill))
        height: root.height
        clip: true
        Shape {
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.transparent
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: root.height
                    GradientStop { position: 0; color: Theme.alpha(root.color, 0.32) }
                    GradientStop { position: 1; color: Theme.alpha(root.color, 0) }
                }
                PathPolyline { path: [Qt.point(0, root.height)].concat(root._pts).concat([Qt.point(root.width, root.height), Qt.point(0, root.height)]) }
            }
            ShapePath {
                fillColor: Theme.transparent
                strokeColor: root.color
                strokeWidth: root.lineWidth
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: root._pts }
            }
        }
    }
}
