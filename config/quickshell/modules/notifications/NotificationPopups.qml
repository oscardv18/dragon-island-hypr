// Notification popups: up to 3 cards under the right island, on the focused monitor only.
// Each expires after Theme.durNotif (critical: until dismissed); hovering pauses the timer.
// While DND is on, Notifs.popups stays empty.
import QtQuick
import Quickshell
import "../.."
import "../../services"

Column {
    id: root

    property bool active: true
    readonly property int count: rep.count

    // card Rectangle of the i-th popup (for the window's blur region); `dep` = rep.count, re-evaluates the binding
    function cardAt(i: int, dep: int): Item { return rep.itemAt(i)?.cardItem ?? null; }

    width: Theme.popoverWidth
    spacing: Theme.spacingSm
    visible: active

    Repeater {
        id: rep
        model: ScriptModel {
            values: root.active ? Notifs.popups.slice(0, Theme.maxPopups) : []
            comparisonMode: ObjectComparison.Identity
        }
        delegate: Item {
            id: wrap
            required property var modelData
            readonly property Item cardItem: card
            width: root.width
            height: card.implicitHeight
            opacity: 0
            x: Theme.popoverShift * 3

            NotificationCard {
                id: card
                width: parent.width
                notification: wrap.modelData
                popup: true
            }

            Timer {
                interval: Math.max(1, Notifs.popupDuration(wrap.modelData))
                running: Notifs.popupDuration(wrap.modelData) > 0 && !card.hovered
                onTriggered: Notifs.dismissPopup(wrap.modelData)
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
