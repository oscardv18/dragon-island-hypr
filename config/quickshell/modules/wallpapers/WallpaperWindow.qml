// =============================================================================
// dragon-island — WallpaperWindow.qml
// Overlay of the wallpaper picker (namespace "dragon-wallpapers"), one per monitor. Click outside / Esc
// closes; the scrim is ScrimWindow. Own namespace so hyprglass can style it on its own.
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
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-wallpapers"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: panel === "wallpapers"

    mask: open ? null : idleMask
    Region { id: idleMask }

    // Unmapped while nothing is open (and for the close animation after): an idle full-screen layer would
    // still be rendered into hyprglass' alpha mask every frame (GPU), for nothing
    visible: open || lingering.running
    Timer { id: lingering; interval: Theme.durPopover + 200 }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.close()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    onOpenChanged: { if (open) Qt.callLater(() => wallpapers.focusSearch()); else lingering.restart(); }

    WallpaperPanel {
        id: wallpapers
        anchors.fill: parent
        shown: win.open
    }
}
