// =============================================================================
// dragon-island — WallpaperWindow.qml
// Overlay of the wallpaper pickers (namespace "dragon-wallpapers"), one per monitor: the orbital one (panel
// "orbital", SUPER + W / right click on the desktop, no scrim) and the classic grid (panel "wallpapers", with
// ScrimWindow). Click outside / Esc closes. Own namespace so hyprglass can style it on its own. One input Region with
// one fixed item: the whole screen while open, nothing while closed.
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
    readonly property bool gridOpen: panel === "wallpapers"
    readonly property bool orbitalOpen: panel === "orbital"
    readonly property bool open: gridOpen || orbitalOpen

    mask: Region { item: maskItem }
    Item {
        id: maskItem
        width: win.open ? win.width : 0
        height: win.open ? win.height : 0
    }

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
        Keys.onEscapePressed: if (!orbital.flying) ShellState.close()
        Keys.onLeftPressed: orbital.step(-1)
        Keys.onRightPressed: orbital.step(1)
        Keys.onReturnPressed: orbital.applyKey()
        Keys.onEnterPressed: orbital.applyKey()
    }

    onOpenChanged: if (!open) lingering.restart()
    onGridOpenChanged: if (gridOpen) Qt.callLater(() => wallpapers.focusSearch())
    onOrbitalOpenChanged: if (orbitalOpen) keys.forceActiveFocus()

    WallpaperPanel {
        id: wallpapers
        anchors.fill: parent
        shown: win.gridOpen
    }

    OrbitalPicker {
        id: orbital
        anchors.fill: parent
        shown: win.orbitalOpen
        screen: win.modelData
    }
}
