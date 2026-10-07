// =============================================================================
// dragon-island — NotificationWindow.qml
// Notification popups (namespace "dragon-notifications"): up to 3 cards under the right bar island,
// on the focused monitor only, hidden while a panel is open. Only as big as its cards.
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

    readonly property bool isFocusedMonitor: Hypr.focusedMonitorName === "" || Hypr.focusedMonitorName === screenName
    readonly property bool panelHere: ShellState.anyOpen && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)

    anchors { top: true; right: true }
    margins.top: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap
    implicitWidth: Theme.popoverWidth + Theme.barMarginSide
    implicitHeight: Math.max(1, popups.height)
    visible: popups.active && popups.count > 0
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: popups }

    // Blur (native and hyprglass) only behind each card (up to Theme.maxPopups = 3)
    BackgroundEffect.blurRegion: Region {
        Region { item: popups.cardAt(0, popups.count); radius: Theme.rowRadius + Theme.spacingXs }
        Region { item: popups.cardAt(1, popups.count); radius: Theme.rowRadius + Theme.spacingXs }
        Region { item: popups.cardAt(2, popups.count); radius: Theme.rowRadius + Theme.spacingXs }
    }

    NotificationPopups {
        id: popups
        active: win.isFocusedMonitor && !win.panelHere
    }
}
