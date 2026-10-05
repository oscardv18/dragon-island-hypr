// =============================================================================
// dragon-island — IslandState.qml
// Which content the closed Dynamic Island shows. Shared by every monitor.
// Priority (spec): OSD > incoming notification > workspace change > now playing > clock.
// =============================================================================
/**
 * Properties:
 *   - mode: string [readonly] ("osd" | "notif" | "workspace" | "media" | "clock")
 *   - notification: Notification [readonly] (the one shown in "notif" mode)
 *   - workspaceId: int [readonly] (the one shown in "workspace" mode)
 *
 * Functions:
 *   - dismissNotification(): void (hide it from the island; it stays in the center)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property var notification: null
    property bool workspaceFlash: false
    property int workspaceId: Hypr.focusedWorkspaceId

    readonly property string mode: {
        if (Osd.visible) return "osd";
        if (notification) return "notif";
        if (workspaceFlash) return "workspace";
        if (Media.hasPlayer && Media.title.length > 0) return "media";
        return "clock";
    }

    // ignore the initial workspace report at startup
    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer {
        id: notifTimer
        onTriggered: root.notification = null
    }

    Timer {
        id: wsTimer
        interval: Theme.durTransient
        onTriggered: root.workspaceFlash = false
    }

    Connections {
        target: Notifs
        function onArrived(n) {
            root.notification = n;
            const d = Notifs.popupDuration(n);   // 0 = critical, until dismissed
            if (d > 0) { notifTimer.interval = d; notifTimer.restart(); }
            else notifTimer.stop();
        }
        function onCleared() { root.dismissNotification(); }
    }

    Connections {
        target: root.notification
        ignoreUnknownSignals: true
        function onClosed() { root.dismissNotification(); }
    }

    Connections {
        target: Hypr
        function onWorkspaceChanged(id) {
            root.workspaceId = id;
            if (!root._armed) return;
            root.workspaceFlash = true;
            wsTimer.restart();
        }
    }

    function dismissNotification(): void {
        notifTimer.stop();
        root.notification = null;
    }
}
