// =============================================================================
// dragon-island — Timers.qml
// Service: the time tools of «Fecha y hora» (docs/design/29-paneles-fecha.png): a countdown timer, a stopwatch and
// alarms. When a timer or an alarm is due the island says so (IslandState.notice) and a notification is sent.
// State (alarms only) in ~/.local/state/dragon-island/timers.json. One 1 s tick, only while something runs.
// =============================================================================
/**
 * Properties:
 *   - timerRunning: bool [readonly]   timerRemaining: int [readonly] (s)   timerTotal: int [readonly] (s)
 *   - stopwatchRunning: bool [readonly]   stopwatchElapsed: int [readonly] (s)
 *   - alarms: list<var> [readonly] ({ time: "07:00", on: bool }, sorted)   nextAlarm: string [readonly] ("07:00" | "")
 *
 * Functions:
 *   - startTimer(minutes: int): void    stopTimer(): void
 *   - toggleStopwatch(): void           resetStopwatch(): void
 *   - addAlarm(time: string): void ("HH:MM")   removeAlarm(time: string): void   toggleAlarm(time: string): void
 *   - format(seconds: int): string ("04:59" / "1:02:03")
 *
 * Signals:
 *   - due(kind: string, text: string) ("timer" | "alarm")
 *
 * IPC (`qs ipc call timers <fn>`): timer(minutes: int), stop(), alarm(time: string), list(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool timerRunning: false
    property int timerRemaining: 0
    property int timerTotal: 0
    property real _timerEnd: 0

    property bool stopwatchRunning: false
    property int stopwatchElapsed: 0
    property real _swStart: 0
    property int _swBase: 0

    property var alarms: []
    readonly property string nextAlarm: {
        const on = root.alarms.filter(a => a.on).map(a => a.time);
        if (on.length === 0) return "";
        const now = Clock.currentDate, cur = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
        return on.find(t => t > cur) ?? on[0];
    }
    property string _lastAlarmKey: ""

    signal due(kind: string, text: string)

    function format(sec: int): string {
        const s = Math.max(0, sec), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60;
        const p = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${p(m)}:${p(ss)}` : `${p(m)}:${p(ss)}`;
    }

    function startTimer(minutes: int): void {
        root.timerTotal = Math.max(1, minutes) * 60;
        root._timerEnd = Date.now() + root.timerTotal * 1000;
        root.timerRemaining = root.timerTotal;
        root.timerRunning = true;
    }
    function stopTimer(): void { root.timerRunning = false; root.timerRemaining = 0; }

    function toggleStopwatch(): void {
        if (root.stopwatchRunning) { root._swBase = root.stopwatchElapsed; root.stopwatchRunning = false; }
        else { root._swStart = Date.now(); root.stopwatchRunning = true; }
    }
    function resetStopwatch(): void { root.stopwatchRunning = false; root._swBase = 0; root.stopwatchElapsed = 0; }

    function _norm(t: string): string {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(t).trim());
        if (!m || Number(m[1]) > 23 || Number(m[2]) > 59) return "";
        return `${m[1].padStart(2, "0")}:${m[2]}`;
    }
    function addAlarm(time: string): void {
        const t = _norm(time);
        if (!t || root.alarms.some(a => a.time === t)) return;
        root.alarms = root.alarms.concat([{ time: t, on: true }]).sort((a, b) => a.time.localeCompare(b.time));
        _save();
    }
    function removeAlarm(time: string): void { root.alarms = root.alarms.filter(a => a.time !== time); _save(); }
    function toggleAlarm(time: string): void { root.alarms = root.alarms.map(a => a.time === time ? { time: a.time, on: !a.on } : a); _save(); }

    // ---- one tick while a timer / stopwatch runs; alarms are checked on the minute (Clock.minuteTicked) ----
    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning || root.stopwatchRunning
        onTriggered: {
            const now = Date.now();
            if (root.timerRunning) {
                root.timerRemaining = Math.max(0, Math.round((root._timerEnd - now) / 1000));
                if (root.timerRemaining === 0) {
                    root.timerRunning = false;
                    root._fire("timer", `Temporizador · ${Math.round(root.timerTotal / 60)} min`);
                }
            }
            if (root.stopwatchRunning) root.stopwatchElapsed = root._swBase + Math.floor((now - root._swStart) / 1000);
        }
    }
    Connections {
        target: Clock
        function onMinuteTicked() {
            const now = Clock.currentDate;
            const cur = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
            const key = `${Clock.todayKey} ${cur}`;
            if (root._lastAlarmKey === key) return;
            if (root.alarms.some(a => a.on && a.time === cur)) { root._lastAlarmKey = key; root._fire("alarm", `Alarma · ${cur}`); }
        }
    }

    function _fire(kind: string, text: string): void {
        root.due(kind, text);
        IslandState.notice(text, kind === "alarm" ? "alarm" : "timer", Theme.durCommandDone);
        Quickshell.execDetached(["notify-send", "-a", "Fecha y hora", "-u", "critical", "-i", "alarm-clock", text]);
    }

    // ---- state ----
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/dragon-island/timers.json`
    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(stateFile.text());
                root.alarms = (Array.isArray(d.alarms) ? d.alarms : []).filter(a => root._norm(a.time)).map(a => ({ time: root._norm(a.time), on: a.on !== false }));
            } catch (e) { root.alarms = []; }
        }
    }
    Process { id: writer }
    function _save(): void {
        writer.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2"', "sh", JSON.stringify({ alarms: root.alarms }), root.statePath]);
    }

    IpcHandler {
        target: "timers"
        function timer(minutes: int): void { root.startTimer(minutes); }
        function stop(): void { root.stopTimer(); }
        function alarm(time: string): void { root.addAlarm(time); }
        function list(): string {
            return [`timer=${root.timerRunning ? root.format(root.timerRemaining) : "-"}`, `stopwatch=${root.format(root.stopwatchElapsed)}${root.stopwatchRunning ? " (en marcha)" : ""}`,
                    `alarms=${root.alarms.map(a => `${a.time}${a.on ? "" : " (off)"}`).join(", ")}`].join("\n");
        }
    }
}
