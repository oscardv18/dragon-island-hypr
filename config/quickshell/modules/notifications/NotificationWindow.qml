// =============================================================================
// dragon-island — NotificationWindow.qml
// Notification popups (namespace "dragon-notifications"): up to 3 cards under the right bar island, on
// the focused monitor only, hidden while a panel is open. Each card is its OWN layer window, as big as
// the card: around it there is only alpha 0, so the glass / blur (alpha mask, see glass.lua) follows the
// rounded card and the 8 px between cards stays clear. Each card expires after Theme.durNotif
// (critical: until dismissed); hovering pauses the timer. While DND is on, Notifs.popups stays empty.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

Scope {
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""

    readonly property bool isFocusedMonitor: Hypr.focusedMonitorName === "" || Hypr.focusedMonitorName === screenName
    readonly property bool panelHere: ShellState.anyOpen && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)
    readonly property bool active: isFocusedMonitor && !panelHere
    readonly property real top: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap

    // card heights by notification id, to stack the windows
    property var heights: ({})
    function setHeight(id, h: real): void {
        if (heights[id] === h) return;
        const next = Object.assign({}, heights);
        next[id] = h;
        heights = next;
    }
    function offsetFor(index: int): real {
        let y = 0;
        for (let i = 0; i < index; i++) y += (heights[items[i]?.id] ?? 80) + Theme.spacingSm;
        return y;
    }

    readonly property var items: active ? Notifs.popups.slice(0, Theme.maxPopups) : []

    Variants {
        model: root.items

        delegate: PanelWindow {
            id: win

            required property var modelData
            readonly property int index: root.items.indexOf(modelData)

            screen: root.modelData
            anchors { top: true; right: true }
            margins.top: root.top + root.offsetFor(Math.max(0, index))
            implicitWidth: Theme.popoverWidth + Theme.barMarginSide
            implicitHeight: Math.max(1, card.implicitHeight)
            exclusionMode: ExclusionMode.Ignore
            color: Theme.transparent

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dragon-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region { item: wrap }

            Item {
                id: wrap
                width: Theme.popoverWidth
                height: card.implicitHeight
                opacity: 0
                x: Theme.popoverShift * 3

                NotificationCard {
                    id: card
                    width: parent.width
                    notification: win.modelData
                    popup: true
                    onImplicitHeightChanged: root.setHeight(win.modelData.id, implicitHeight)
                    Component.onCompleted: root.setHeight(win.modelData.id, implicitHeight)
                }

                Timer {
                    interval: Math.max(1, Notifs.popupDuration(win.modelData))
                    running: Notifs.popupDuration(win.modelData) > 0 && !card.hovered
                    onTriggered: Notifs.dismissPopup(win.modelData)
                }

                Component.onCompleted: enter.start()
                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: wrap; property: "opacity"; to: 1; duration: Theme.durPopover; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wrap; property: "x"; to: 0; duration: Theme.durPopover; easing.type: Easing.OutBack }
                }
            }
        }
    }
}
