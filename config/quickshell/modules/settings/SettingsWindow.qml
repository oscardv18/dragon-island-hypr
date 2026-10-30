// =============================================================================
// dragon-island — SettingsWindow.qml
// Overlay of the Ajustes panel (namespace "dragon-settings", glass preset dragon-panel), one per monitor, opened
// through ShellState ("settings", SUPER + F2). Click outside / Esc closes. No scrim on purpose: the bar must stay
// visible while its style is changed live. Unmapped while closed (an idle full-screen layer would still cost GPU
// in hyprglass' alpha mask, HANDOFF §7g).
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
    WlrLayershell.namespace: "dragon-settings"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: panel === "settings"

    // closed: no input at all · open: the card only, so the bar stays usable (the click-outside area is the rest)
    mask: open ? null : idleMask
    Region { id: idleMask }

    visible: open || lingering.running
    Timer { id: lingering; interval: Theme.durPopover + 200 }
    onOpenChanged: { if (open) Qt.callLater(() => keys.forceActiveFocus()); else lingering.restart(); }

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
        Keys.onPressed: e => settings.key(e)
    }

    SettingsPanel {
        id: settings
        anchors.fill: parent
        shown: win.open
    }
}
