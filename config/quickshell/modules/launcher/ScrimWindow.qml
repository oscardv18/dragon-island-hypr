// =============================================================================
// dragon-island — ScrimWindow.qml
// Black 45 % scrim behind the modal panels (launcher, power menu, clipboard, shortcuts, wallpapers),
// namespace "dragon-scrim", one per monitor. A window of its own because hyprglass / the native blur
// work by alpha: a 45 % black fill in the panels' window would be glassed over the whole screen.
// It takes no input (empty mask): the panel windows catch the clicks.
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
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-scrim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: ["launcher", "power", "clipboard", "keybinds", "wallpapers", "store", "herdrhelp"].indexOf(panel) >= 0

    // fully hidden (surface unmapped) while nothing is open: a transparent full-screen layer costs nothing
    visible: open || scrim.opacity > 0

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durScrim; easing.type: Easing.OutCubic } }
    }
}
