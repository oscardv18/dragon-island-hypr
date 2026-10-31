// =============================================================================
// dragon-island — Focus.qml
// Service: focus mode (docs/design/09-isla.png, last card).
// =============================================================================
/**
 * Starting it: turns No molestar on, shows the bar in style D for the session (Theme.barStyle, NOT Settings.barStyle)
 * and keeps the notifications of Settings.focusMuteApps (default ["Telegram"]) without popup or peek (Notifs.holdApps).
 * Ending it (time is up, stop() or the IPC): everything goes back as it was and the island says
 * "Enfoque terminado · N notificaciones retenidas".
 *
 * Properties:
 *   - active: bool [readonly] (island state "focus")
 *   - minutes: int [readonly] (length of the current session)
 *   - remaining: int [readonly] (seconds left) · progress: real [readonly] (0 → 1)
 *   - summary: string [readonly] ("Telegram silenciado · barra mínima")
 *
 * Functions:
 *   - start(minutes: int): void      stop(): void      toggle(): void (45 min)
 *   - pause(): void   resume(): void   togglePause(): void (paused: bool [readonly]; startedAt: real [readonly], ms)
 *   Every session is logged with Activity (kind "focus") for the island's time strip.
 *
 * IPC (`qs ipc call focus <fn>`): start(minutes: int), stop(), toggle(), remaining(): int
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool active: false
    property int minutes: 45
    property real _endsAt: 0
    property int remaining: 0
    readonly property real progress: active && minutes > 0 ? 1 - remaining / (minutes * 60) : 0
    property bool _dndBefore: false

    readonly property string summary: {
        const apps = Settings.focusMuteApps;
        const muted = apps.length === 0 ? "" : (apps.length === 1 ? `${apps[0]} silenciado` : `${apps.length} apps silenciadas`);
        return [muted, "barra mínima"].filter(s => s.length > 0).join(" · ");
    }

    // pause (the isla de mando's focus card): the countdown stops, No molestar and the held apps stay
    property bool paused: false
    property int _pausedLeft: 0
    property real startedAt: 0          // ms, for the island's time strip
    property string _activityId: ""
    function pause(): void { if (!root.active || root.paused) return; root._pausedLeft = root.remaining; root.paused = true; }
    function resume(): void { if (!root.paused) return; root._endsAt = Date.now() + root._pausedLeft * 1000; root.paused = false; }
    function togglePause(): void { if (root.paused) root.resume(); else root.pause(); }

    function start(min: int): void {
        if (root.active) root._end(false);
        root.minutes = Math.max(1, min);
        root._endsAt = Date.now() + root.minutes * 60000;
        root.remaining = root.minutes * 60;
        root._dndBefore = Notifs.dnd;
        Notifs.releaseHeld();
        Notifs.holdApps = Settings.focusMuteApps;
        Notifs.setDnd(true);
        root.paused = false;
        root.startedAt = Date.now();
        root.active = true;
        Activity.add("focus", `Enfoque ${root.minutes} min`, Activity.now(), 0, "", id => root._activityId = id ?? "");
    }

    function stop(): void { if (root.active) root._end(true); }
    function toggle(): void { if (root.active) root.stop(); else root.start(45); }

    function _end(announce: bool): void {
        root.active = false;
        root.paused = false;
        Activity.end(root._activityId, "ok");
        root._activityId = "";
        Notifs.holdApps = [];
        Notifs.setDnd(root._dndBefore);
        const n = Notifs.releaseHeld();
        if (announce) IslandState.notice(n > 0 ? `Enfoque terminado · ${n} ${n === 1 ? "notificación retenida" : "notificaciones retenidas"}` : "Enfoque terminado", "check", Theme.durNotice * 2);
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        onTriggered: {
            root.remaining = Math.max(0, Math.round((root._endsAt - Date.now()) / 1000));
            if (root.remaining === 0) root._end(true);
        }
    }

    IpcHandler {
        target: "focus"
        function start(minutes: int): void { root.start(minutes); }
        function stop(): void { root.stop(); }
        function toggle(): void { root.toggle(); }
        function remaining(): int { return root.remaining; }
    }
}
