// =============================================================================
// dragon-island — DesktopCatcher.qml
// The empty desktop's right click (docs/design/16-orbital.png). A transparent layer on the Bottom layer, one per
// monitor, namespace "dragon-desktop": under every normal window (a click on a window always reaches the window)
// and above the wallpaper (awww / mpvpaper live on Background, and awww is restarted when a video wallpaper
// ends, which would put it over a Background-layer catcher). It takes no keyboard focus, reserves no space and
// draws nothing (hyprglass excludes it in config/hypr/glass.lua). A right click opens the orbital picker around
// that point; the left click and the wheel do nothing.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win

    property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "dragon-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => Wallpaper.openOrbital(win.modelData?.name ?? "", mouse.x, mouse.y)
    }
}
