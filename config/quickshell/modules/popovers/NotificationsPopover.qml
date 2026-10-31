// Notificaciones (SUPER + N, the bell marker of the clock, «Notificaciones» in Fecha y hora): the notification
// centre in the HUD frame — No molestar, the cards (single or grouped), «Borrar todo» and the pending updates.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"
import "../notifications"

PopoverFrame {
    id: root
    title: Notifs.count > 0 ? `Notificaciones · ${Notifs.count}` : "Notificaciones"
    popWidth: Theme.hudWidth

    onOpened: { Notifs.markAllRead(); Updates.refresh(); }
    onClosed: Notifs.markAllRead()

    NotificationsColumn { Layout.fillWidth: true; framed: true }
}
