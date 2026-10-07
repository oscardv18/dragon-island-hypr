// =============================================================================
// dragon-island — LauncherWindow.qml
// Overlay for the modal panels (namespace "dragon-launcher"), one per monitor: launcher, power menu,
// clipboard history, keybinds cheat-sheet. Black 45 % scrim, click outside / Esc closes.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../power"
import "../clipboard"
import "../keybinds"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: ["launcher", "power", "clipboard", "keybinds"].indexOf(panel) >= 0

    mask: open ? null : idleMask
    Region { id: idleMask }

    // Blur (native and hyprglass) only behind the visible card, not behind the whole scrim
    BackgroundEffect.blurRegion: Region {
        Region { item: launcher.frameItem; radius: Theme.popoverRadius }
        Region { item: clipboard.frameItem; radius: Theme.popoverRadius }
        Region { item: keybinds.frameItem; radius: Theme.popoverRadius }
        Region { item: power.frameItem; radius: Theme.popoverRadius }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durScrim; easing.type: Easing.OutCubic } }
    }

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

    onPanelChanged: Qt.callLater(() => {
        if (panel === "launcher") launcher.focusSearch();
        else if (panel === "clipboard") clipboard.focusSearch();
        else if (panel === "keybinds") keybinds.focusSearch();
        else if (panel === "power") power.focusMenu();
        else if (open) keys.forceActiveFocus();
    })

    Launcher {
        id: launcher
        anchors.fill: parent
        shown: win.panel === "launcher"
    }

    ClipboardPanel {
        id: clipboard
        anchors.fill: parent
        shown: win.panel === "clipboard"
    }

    KeybindsPanel {
        id: keybinds
        anchors.fill: parent
        shown: win.panel === "keybinds"
    }

    PowerMenu {
        id: power
        anchors.fill: parent
        shown: win.panel === "power"
    }
}
