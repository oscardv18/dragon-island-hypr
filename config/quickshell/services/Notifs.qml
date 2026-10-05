// =============================================================================
// dragon-island — Notifs.qml
// Service: notification daemon (the only one in the Hyprland session), history and popups
// =============================================================================
/**
 * Properties:
 *   - dnd: bool [readonly] (Do Not Disturb: notifications are kept, no popups)
 *   - notifications: list<Notification> [readonly] (newest first)
 *   - count: int [readonly]
 *   - unreadCount: int [readonly] (arrived since the center was last opened)
 *   - hasUnread: bool [readonly]
 *   - latestNotification: Notification [readonly]
 *   - popups: list<Notification> [readonly] (currently shown as popup / island state, newest first)
 *   - maxHistory: int (oldest are expired beyond this, default 100)
 *
 * Functions:
 *   - toggleDnd(): void              setDnd(enabled: bool): void
 *   - clearAll(): void               dismiss(n: Notification): void   dismissById(id: int): void
 *   - markAllRead(): void            (call when the notification center opens)
 *   - dismissPopup(n): void          (hide the popup, keep it in the center)
 *   - invokeAction(n, action): void
 *   - isCritical(n): bool
 *   - iconFor(n): string             (image source for the notification or its app, may be "")
 *   - relativeTime(n): string        ("ahora", "hace 5 min", "16:23", "ayer")
 *   - popupDuration(n): int          (ms; 0 = until dismissed, for critical)
 *
 * Signals:
 *   - arrived(notification: var)    (not emitted while DND is on or for re-emitted notifications after reload)
 *   - cleared()
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import ".."

Singleton {
    id: root

    property bool dnd: false
    property int maxHistory: 100

    readonly property var notifications: server.trackedNotifications.values.slice().reverse()
    readonly property int count: notifications.length
    readonly property Notification latestNotification: notifications[0] ?? null

    property var _arrivals: ({})   // id → arrival time (ms)
    property real _lastRead: Date.now()
    property int _tick: 0          // bumps every 30 s so relative times re-evaluate

    readonly property int unreadCount: notifications.filter(n => (root._arrivals[n.id] ?? 0) > root._lastRead).length
    readonly property bool hasUnread: unreadCount > 0

    property var popups: []

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false // plain-text bodies; the UI also renders with Text.PlainText
        keepOnReload: true

        onNotification: n => {
            // Must be tracked or the notification is dropped immediately
            n.tracked = true;

            const arrivals = Object.assign({}, root._arrivals);
            arrivals[n.id] = Date.now();
            root._arrivals = arrivals;

            n.closed.connect(() => root.dismissPopup(n));

            const all = server.trackedNotifications.values;
            if (all.length > root.maxHistory) all[0].expire();

            if (!root.dnd && !n.lastGeneration) {
                root.popups = [n].concat(root.popups.filter(p => p !== n));
                root.arrived(n);
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root._tick++
    }

    function toggleDnd(): void { root.dnd = !root.dnd; }
    function setDnd(enabled: bool): void { root.dnd = enabled; }

    onDndChanged: if (dnd) root.popups = []

    function clearAll(): void {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        root.popups = [];
        root.cleared();
    }

    function dismiss(n): void { n?.dismiss(); }
    function dismissById(id: int): void { server.trackedNotifications.values.find(n => n.id === id)?.dismiss(); }

    function markAllRead(): void { root._lastRead = Date.now(); }

    function dismissPopup(n): void {
        if (root.popups.indexOf(n) >= 0) root.popups = root.popups.filter(p => p !== n);
    }

    function invokeAction(n, action): void {
        action?.invoke();
        root.dismissPopup(n);
    }

    function isCritical(n): bool { return n?.urgency === NotificationUrgency.Critical; }

    function popupDuration(n): int { return isCritical(n) ? 0 : Theme.durationNotif; }

    function iconFor(n): string {
        if (!n) return "";
        const img = n.image || "";
        if (img.length > 0) return img.startsWith("/") ? `file://${img}` : img;
        const icon = n.appIcon || "";
        if (icon.length === 0) return "";
        if (icon.startsWith("/")) return `file://${icon}`;
        if (icon.includes("://")) return icon;
        return Quickshell.iconPath(icon, true);
    }

    function relativeTime(n): string {
        void root._tick;
        const t = root._arrivals[n?.id];
        if (!t) return "";
        const mins = Math.floor((Date.now() - t) / 60000);
        if (mins < 1) return "ahora";
        if (mins < 60) return `hace ${mins} min`;
        const d = new Date(t);
        const today = new Date();
        if (d.toDateString() === today.toDateString()) return Qt.formatDateTime(d, "hh:mm");
        const yesterday = new Date(today.getTime() - 86400000);
        if (d.toDateString() === yesterday.toDateString()) return "ayer";
        return Qt.formatDateTime(d, "dd/MM");
    }

    signal arrived(var notification)
    signal cleared()
}
