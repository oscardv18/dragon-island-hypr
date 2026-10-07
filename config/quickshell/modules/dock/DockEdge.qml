// The dock's hot zone (namespace "dragon-dock-edge"): a 3 px transparent strip on the edge, as long as the arc.
// The pointer reaching it brings the dock up (Dock.hover). Layer Top: fullscreen windows cover it.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string pos: Dock.position
    readonly property bool horizontal: pos === "bottom"

    anchors {
        bottom: pos === "bottom"
        left: pos === "left"
        right: pos === "right"
    }
    implicitWidth: horizontal ? Theme.dockWidth : Theme.dockEdge
    implicitHeight: horizontal ? Theme.dockEdge : Theme.dockWidth
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-dock-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HoverHandler { onHoveredChanged: Dock.hover(hovered) }
}
