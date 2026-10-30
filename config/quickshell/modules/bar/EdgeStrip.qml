// Style D: the 3 px hot strip at the top edge of a bar window. It lives in the window's own input mask (§7x of the
// HANDOFF: never a separate surface) and reports to BarState, which reveals style B while anything is hovered.
import QtQuick
import "../.."
import "../../services"

Item {
    id: root
    property string source: ""
    width: Theme.barStyle === "D" ? (parent ? parent.width : 0) : 0
    height: Theme.barEdge
    HoverHandler { onHoveredChanged: BarState.hover(root.source, hovered) }
}
