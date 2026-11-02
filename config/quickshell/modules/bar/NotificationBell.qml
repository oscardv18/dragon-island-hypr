// The bell: with nothing unread it is just the icon (the slot closes up); with unread notifications the slot opens for the count,
// which stays visible with DND. Only the island content changes width (the bar window never does); no polling, no idle animation.
import QtQuick
import "../.."
import "../../services"
import "../../components"

Capsule {
    id: bell
    required property var island
    objectName: "notificationBell"
    anchors.verticalCenter: parent.verticalCenter
    flat: true
    padH: Theme.spacingXs
    readonly property int unread: Notifs.unreadCount
    readonly property bool dnd: Toggles.dnd
    readonly property string countLabel: unread > Theme.barBellCountLimit ? `${Theme.barBellCountLimit}+` : `${unread}`
    active: island.bar.isOpen("notifications")
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Toggles.toggleDnd();
        else if (mouse.button === Qt.LeftButton) island.openPopover("notifications", bell);
    }
    Accessible.role: Accessible.Button
    Accessible.name: `${dnd ? "No molestar" : "Notificaciones"} · ${unread} sin leer`

    Item {
        width: bell.unread > 0 ? Theme.barBellContentWidth : Theme.iconSm
        height: Theme.barCapsuleHeight
        objectName: "notificationBellContent"
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Glyph {
            objectName: "notificationBellGlyph"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.iconSm
            icon: bell.dnd ? Icons.bellOff : Icons.bell
            color: bell.dnd ? Theme.muted : Theme.textSoft
        }
        Rectangle {
            objectName: "notificationBellBadge"
            anchors.right: parent.right
            y: Theme.barBellBadgeInset
            width: Theme.barBellBadgeWidth
            height: Theme.barBellBadgeHeight
            radius: height / 2
            visible: bell.unread > 0
            color: bell.dnd ? Theme.surfaceHi : Theme.lavender
            UiText {
                objectName: "notificationBellCount"
                anchors.centerIn: parent
                text: bell.countLabel
                size: Theme.barBellBadgeFont
                mono: true
                weight: Theme.weightSemiBold
                color: bell.dnd ? Theme.textSoft : Theme.lavenderInk
            }
        }
    }
    BarTooltip {
        target: bell
        shown: bell.hovered && !bell.active
        text: `${bell.dnd ? "No molestar · " : ""}${bell.unread} sin leer · Clic: notificaciones · Derecho: No molestar`
    }
}
