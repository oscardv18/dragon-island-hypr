// =============================================================================
// dragon-island — IslandWindow.qml  (pattern 4: Dynamic Island in its own overlay)
// One full-screen transparent overlay per monitor. It hosts the island/dashboard, the
// popovers, the launcher, the power menu and the notification popups.
//   nothing open → mask = island shape + popups (rest of the screen is click-through)
//   panel open   → mask = null (whole window): the scrim / click-catcher closes it,
//                  keyboard focus is Exclusive so Escape closes it.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../popovers"
import "../launcher"
import "../power"
import "../notifications"
import "../clipboard"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-island"
    WlrLayershell.keyboardFocus: panelHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Panel shown on this monitor ("none" otherwise)
    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool panelHere: panel !== "none"
    readonly property bool modal: panel === "dashboard" || panel === "launcher" || panel === "power" || panel === "clipboard"
    readonly property bool isFocusedMonitor: Hypr.focusedMonitorName === "" || Hypr.focusedMonitorName === screenName

    // hide the closed island over fullscreen windows, except while it shows the OSD
    readonly property bool islandHidden: Hypr.fullscreenOn(screen) && !panelHere && IslandState.mode !== "osd"

    mask: panelHere ? null : idleMask
    Region {
        id: idleMask
        item: win.islandHidden ? null : island.shapeItem
        Region { item: popups }
    }

    // Scrim: black 45 %, only for modal panels (dashboard, launcher, power)
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: win.modal ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durScrim; easing.type: Easing.OutCubic } }
    }

    // Click outside any panel closes it (transparent for popovers)
    MouseArea {
        anchors.fill: parent
        enabled: win.panelHere
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.close()
    }

    // Keyboard: Escape closes whatever is open
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()
    }

    onPanelChanged: Qt.callLater(() => {
        if (panel === "launcher") launcher.focusSearch();
        else if (panel === "clipboard") clipboard.focusSearch();
        else if (panel === "power") power.focusMenu();
        else if (panelHere) keys.forceActiveFocus();
    })

    NotificationPopups {
        id: popups
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMarginSide
        y: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap
        active: win.isFocusedMonitor && !win.panelHere
    }

    Island {
        id: island
        anchors.fill: parent
        screenName: win.screenName
        open: win.panel === "dashboard"
        hidden: win.islandHidden
    }

    PopoverHost {
        anchors.fill: parent
        panel: win.panel
        screenName: win.screenName
    }

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

    PowerMenu {
        id: power
        anchors.fill: parent
        shown: win.panel === "power"
    }
}
