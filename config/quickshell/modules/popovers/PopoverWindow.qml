// =============================================================================
// dragon-island — PopoverWindow.qml
// Overlay for the bar capsule popovers (namespace "dragon-popover"), one per monitor.
//   nothing open → empty mask: the whole window lets clicks through
//   popover open → mask = whole window: a click outside the popover closes it, Esc too.
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
    WlrLayershell.namespace: "dragon-popover"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: ["perf", "wifi", "bt", "audio", "battery", "notifications", "calendar", "privacy"].indexOf(panel) >= 0

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

    onOpenChanged: { if (open) Qt.callLater(() => keys.forceActiveFocus()); else lingering.restart(); }

    PopoverHost {
        id: host
        anchors.fill: parent
        panel: win.panel
        screenName: win.screenName
    }
}
