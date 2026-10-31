// The frame decoration shared by every HUD popover (PopoverFrame) and by the focused window (modules/frame/FrameWindow):
// a thin top line (lavender → cyan, transparent at both ends) and four cyan corner brackets, drawn over a rectangle
// with corner radius `radius`. Same component, same tokens (Theme.frame), so popovers and windows can never diverge.
//   line            draw the top line (popovers: only with the «ahumado» glass; windows: always unless «nada»)
//   brackets        draw the four corner brackets
//   bracketOpacity  their fade (popovers animate it after the unfold); `grow` 1 → 0 slides them in from outside
// Static: it repaints only when its size, position or these properties change.
import QtQuick
import ".."

Item {
    id: root

    property real radius: 0
    property bool line: true
    property bool brackets: true
    property real bracketOpacity: 1
    property real grow: 0

    GlassLight {
        cornerRadius: root.radius
        visible: root.line && root.width > 0
    }

    HudBrackets {
        anchors.fill: parent
        visible: root.brackets && root.bracketOpacity > 0.001
        opacity: root.bracketOpacity * Theme.frame.bracketAlpha
        grow: root.grow
    }
}
