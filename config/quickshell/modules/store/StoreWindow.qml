// =============================================================================
// dragon-island — StoreWindow.qml
// Overlay of the "Tienda" panel (namespace "dragon-store"), one per monitor: a full-screen transparent layer with the
// panel card in the middle (liquid glass by alpha, same preset as the other panels). Click outside / Esc closes;
// the scrim is ScrimWindow. Unmapped while closed.
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
    WlrLayershell.namespace: "dragon-store"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string panel: (ShellState.panelScreen === "" || ShellState.panelScreen === screenName) ? ShellState.openPanel : "none"
    readonly property bool open: panel === "store"

    mask: open ? null : idleMask
    Region { id: idleMask }

    visible: open || lingering.running
    Timer { id: lingering; interval: Theme.durPopover + 200 }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.close()
    }

    onOpenChanged: { if (open) Qt.callLater(() => panelItem.focusSearch()); else lingering.restart(); }

    StorePanel {
        id: panelItem
        anchors.fill: parent
        shown: win.open
    }
}
