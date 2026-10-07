// =============================================================================
// dragon-island — IslandState.qml
// Which content the collapsed notch shows. Shared by every monitor.
// Priority: OSD > notification > workspace change > now playing > clock.
// Transient states (OSD, notification, workspace) are shown as a "peek" of the notch and
// return on their own.
// =============================================================================
/**
 * Properties:
 *   - mode: string [readonly] ("osd" | "notification" | "workspace" | "media" | "clock")
 *   - isTransient: bool [readonly] (mode is osd / notification / workspace → the notch peeks)
 *   - workspaceId: int [readonly] (the one shown in "workspace" mode)
 *   - notification: Notification [readonly] (the one shown in "notification" mode)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property bool workspaceFlash: false
    property int workspaceId: Hypr.focusedWorkspaceId
    property bool notifFlash: false
    property var notification: null

    readonly property string mode: {
        if (Osd.visible) return "osd";
        if (notifFlash && notification) return "notification";
        if (workspaceFlash) return "workspace";
        if (Media.hasPlayer && Media.title.length > 0) return "media";
        return "clock";
    }
    readonly property bool isTransient: mode === "osd" || mode === "notification" || mode === "workspace"

    // ignore the initial workspace report at startup
    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer {
        id: wsTimer
        interval: Theme.durTransient
        onTriggered: root.workspaceFlash = false
    }

    Timer {
        id: notifTimer
        interval: Theme.durNotif
        onTriggered: root.notifFlash = false
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

    // Notifs.arrived is not emitted while DND is on; critical ones stay until dismissed as popups,
    // but the peek always returns on its own.
    Connections {
        target: Notifs
        function onArrived(n) {
            root.notification = n;
            root.notifFlash = true;
            notifTimer.restart();
        }
    }
}
