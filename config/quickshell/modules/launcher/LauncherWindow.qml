// =============================================================================
// dragon-island — LauncherWindow.qml
// Overlay for the modal panels (namespace "dragon-launcher"), one per monitor: launcher, power menu,
// clipboard history, keybinds cheat-sheet. Click outside / Esc closes; the black 45 % scrim is its own window
// (ScrimWindow, namespace "dragon-scrim"): it must not share a layer with the glass (alpha mask > threshold).
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

    // Unmapped while nothing is open (and for the close animation after): an idle full-screen layer would
    // still be rendered into hyprglass' alpha mask every frame (GPU), for nothing
    // the launcher panel waits for the back ring and the planet to be mapped first (OrbitalLauncher stage)
    property bool orbitReady: true
    readonly property alias launcher: launcher
    visible: (open && (panel !== "launcher" || orbitReady)) || lingering.running
    onOpenChanged: if (!open) lingering.restart()
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
