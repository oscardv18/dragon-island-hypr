// Tiny live line (the bar's network line): the samples scaled to the largest one, newest on the right.
import QtQuick
import QtQuick.Shapes
import ".."

Shape {
    id: root

    property var samples: []        // numbers, oldest first
    property int capacity: 12       // points across the width
    property color color: Theme.cyan
    property real floor: 2048       // smallest full scale (bytes/s): an idle line stays flat near the bottom

    property real lineWidth: 30     // fixed size: the points never read width / height (a Shape sizes itself from its path → binding loop)
    property real lineHeight: 12
    implicitWidth: lineWidth
    implicitHeight: lineHeight
    preferredRendererType: Shape.CurveRenderer

    readonly property real _max: Math.max(floor, ...(samples.length > 0 ? samples : [0]))
    readonly property var _points: {
        const n = Math.max(2, capacity), pts = [];
        const data = samples.slice(-n);
        while (data.length < n) data.unshift(0);
        for (let i = 0; i < n; i++)
            pts.push(Qt.point(i * (lineWidth - 1) / (n - 1) + 0.5, lineHeight - 1 - (lineHeight - 2) * Math.min(1, data[i] / _max)));
        return pts;
    }

    ShapePath {
        fillColor: Theme.transparent
        strokeColor: root.color
        strokeWidth: 1.3
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root._points[0].x
        startY: root._points[0].y
        PathPolyline { path: root._points }
    }
}
