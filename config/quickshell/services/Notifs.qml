// =============================================================================
// dragon-island — Notifs.qml
// Service: Desktop Notification Server & Manager
// =============================================================================
/**
 * Properties:
 *   - dnd: bool (Do Not Disturb mode)
 *   - unreadCount: int [readonly]
 *   - notifications: list<Notification> [readonly]
 *   - latestNotification: Notification [readonly]
 *
 * Functions:
 *   - toggleDnd(): void
 *   - setDnd(enabled: bool): void
 *   - clearAll(): void
 *   - dismiss(id: int): void
 *
 * Signals:
 *   - arrived(var notification)
 *   - cleared()
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property bool dnd: false

    readonly property var notifications: server.trackedNotifications.values
    readonly property int unreadCount: notifications.length
    readonly property Notification latestNotification: notifications[notifications.length - 1] ?? null

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false // Plain text bodies to prevent markup injection
        keepOnReload: true

        onNotification: n => {
            // CRITICAL GOTCHA: Must set tracked = true or notification is immediately dropped
            n.tracked = true;

            if (!root.dnd) {
                root.arrived(n);
            }
        }
    }

    function toggleDnd(): void {
        root.dnd = !root.dnd;
    }

    function setDnd(enabled: bool): void {
        root.dnd = enabled;
    }

    function clearAll(): void {
        const list = server.trackedNotifications.values.slice();
        for (const n of list) {
            n.dismiss();
        }
        root.cleared();
    }

    function dismiss(id: int): void {
        const target = server.trackedNotifications.values.find(n => n.id === id);
        if (target) {
            target.dismiss();
        }
    }

    signal arrived(var notification)
    signal cleared()
}
