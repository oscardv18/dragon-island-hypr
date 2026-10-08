// CoreIcon.qml — 24×24 stroke icon from an SVG path string (QtQuick.Shapes, no image files)
import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    property string name: ""            // key of `glyphs` below
    property string path: glyphs[name] || ""
    property color color: "#e6e8ef"
    property real stroke: 2
    property int size: 18
    implicitWidth: size; implicitHeight: size

    Shape {
        anchors.centerIn: parent
        width: 24; height: 24
        scale: icon.size / 24
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.path }
        }
    }

    // shared glyphs (lucide-style paths)
    readonly property var glyphs: ({
        arrow:   "M5 12h14M13 6l6 6-6 6",
        moon:    "M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z",
        restart: "M3 12a9 9 0 1 0 3-6.7M3 4v5h5",
        power:   "M12 2v10M18.4 6.6a9 9 0 1 1-12.8 0",
        keyboard:"M3 7h18v10H3zM7 11h.01M11 11h.01M15 11h.01M8 14h8",
        caps:    "M12 4l7 8h-4v6H9v-6H5z",
        prev:    "M19 20L9 12l10-8zM5 19V5",
        next:    "M5 4l10 8-10 8zM19 5v14",
        play:    "M6 4l14 8-14 8z",
        pause:   "M7 4h3v16H7zM14 4h3v16h-3z",
        search:  "M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.3-4.3",
        bell:    "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"
    })
}
