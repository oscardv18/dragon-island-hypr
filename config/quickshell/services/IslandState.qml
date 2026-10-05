// =============================================================================
// dragon-island — IslandState.qml
// Which content the closed Dynamic Island shows. Shared by every monitor.
// Priority: OSD > workspace change > now playing > clock.
// (Notifications are shown only as popups — project decision, see HANDOFF.md.)
// =============================================================================
/**
 * Properties:
 *   - mode: string [readonly] ("osd" | "workspace" | "media" | "clock")
 *   - workspaceId: int [readonly] (the one shown in "workspace" mode)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property bool workspaceFlash: false
    property int workspaceId: Hypr.focusedWorkspaceId

    readonly property string mode: {
        if (Osd.visible) return "osd";
        if (workspaceFlash) return "workspace";
        if (Media.hasPlayer && Media.title.length > 0) return "media";
        return "clock";
    }

    // ignore the initial workspace report at startup
    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer {
        id: wsTimer
        interval: Theme.durTransient
        onTriggered: root.workspaceFlash = false
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
}
