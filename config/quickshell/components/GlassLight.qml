// The light edge of the «ahumado» glass (docs/design/28-emergentes.png): a 1 px line along the top of a glass shape,
// lavender → cyan, transparent at both ends. Hidden in the other glass styles (Theme.glassLight). It is the top line of
// Theme.frame: FrameDecor (popovers and windows) draws it with this same component.
// Put it inside the shape; `cornerRadius` is the shape's corner radius, so the line starts where the straight top begins.
import QtQuick
import ".."

Rectangle {
    id: root
    property real cornerRadius: 0
    property real inset: cornerRadius * Theme.frame.lineInset

    visible: Theme.glassLight
    x: inset
    y: 0
    width: Math.max(0, (parent ? parent.width : 0) - inset * 2)
    height: Theme.frame.line
    opacity: Theme.frame.lineAlpha
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.frame.lineStops[0] }
        GradientStop { position: 0.2; color: Theme.frame.lineStops[1] }
        GradientStop { position: 0.8; color: Theme.frame.lineStops[2] }
        GradientStop { position: 1.0; color: Theme.frame.lineStops[3] }
    }
}
