// A fixed-width bell slot: unread count stays visible with DND, without polling or idle animation.
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
    Accessible.role: Accessible.Button
    Accessible.name: `${dnd ? "No molestar" : "Notificaciones"} · ${unread} sin leer`

    Item {
        width: Theme.barBellContentWidth
        height: Theme.barCapsuleHeight
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
