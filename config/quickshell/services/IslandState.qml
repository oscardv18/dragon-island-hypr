// =============================================================================
// dragon-island — IslandState.qml
// Which content the collapsed notch shows. Shared by every monitor.
//
// Priority, highest first (P = persistent while its condition holds · T = transient, returns on its own):
//    1  capture        P  the capture bar is open (Capture.active)
//    2  osd            T  volume, microphone, brightness, Bloq Mayús, keyboard layout (Osd, Theme.durOsd) — above
//                         recording / dropdown so a volume change while recording shows and REC comes back after it
//    3  dropdown       P  the drop-down terminal is shown: the island is its lid (Dropdown.shown)
//    4  recording      P  recording / sharing the screen (RecordingMode.active)
//    5  agentBlocked   P  a herdr agent waits for an answer (Herdr: state "blocked")
//    6  notification   T  peek of a notification (not while Notifs holds them)
//       notice         T  a short notice of the shell ("Copiada · guardada en Imágenes", "N retenidas")
//    7  idleWarn       P  the warning before locking (Idle.warning)
//    8  workspace      T  the workspace changed
//       tiling         T  the tiling mode changed
//    9  agentWorking   P  herdr agents working (Herdr.counts.working)
//   10  focus          P  focus mode (Focus.active)
//   11  commandDone    T  a long command or an agent finished (Commands.done, Herdr attention "done"), 4 s
//   12  rest           the content chosen in Settings.islandContent: "media" (now playing, else the clock),
//                      "window" (the focused window, else the clock) or "date"
// A persistent state of lower priority comes back by itself when a transient one above it ends: the mode is
// always recomputed from the conditions, transients only hold a flag while their timer runs.
// Each mode has its own width (the content's implicitWidth); Notch.qml morphs between them with its springs:
// floating (B, D) it grows sideways and down without ears, attached (A, C) it grows from the edge.
// =============================================================================
/**
 * Properties:
 *   - mode: string [readonly] (one of the modes above: "capture" | "dropdown" | "recording" | "osd" | "agentBlocked" |
 *       "notification" | "notice" | "idleWarn" | "workspace" | "tiling" | "agentWorking" | "focus" | "commandDone" |
 *       "media" | "window" | "date" | "clock")
 *   - isTransient: bool [readonly] (a transient mode is shown → the notch peeks)
 *   - workspaceId: int [readonly] (the one shown in "workspace" mode)
 *   - notification: Notification [readonly] (the one shown in "notification" mode)
 *   - tilingText: string [readonly]
 *   - blockedAgent: var [readonly] (the herdr agent waiting for an answer, or null)
 *   - workingAgents: list<var> [readonly] (herdr agents working)
 *   - done: var [readonly] ({ kind: "command" | "agent", text, ok: bool, detail } shown in "commandDone")
 *   - noticeText / noticeIcon: string [readonly] (shown in "notice")
 *
 * Functions:
 *   - notice(text: string, icon: string, ms: int): void (a short notice in the island; icon = an Icons name or "")
 *
 * IPC (`qs ipc call island preview <mode>`): shows a mode for 4 s whatever the priority, with sample data where the
 *   mode needs it ("commandDone", "commandFail", "agentBlocked", …) — to check the look; nothing else changes.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool workspaceFlash: false
    property int workspaceId: Hypr.focusedWorkspaceId
    property bool notifFlash: false
    property var notification: null
    property bool tilingFlash: false
    property string tilingText: ""
    property bool doneFlash: false
    property var done: null
    property bool noticeFlash: false
    property string noticeText: ""
    property string noticeIcon: ""

    readonly property var blockedAgent: Herdr.running ? (Herdr.agents.find(a => a.state === "blocked") ?? null) : null
    readonly property var workingAgents: Herdr.running ? Herdr.agents.filter(a => a.state === "working") : []

    property string previewMode: ""
    readonly property string mode: {
        if (previewMode.length > 0) return previewMode;
        if (Capture.active) return "capture";
        if (Osd.visible) return "osd";
        if (Dropdown.shown) return "dropdown";
        if (RecordingMode.active) return "recording";
        if (blockedAgent) return "agentBlocked";
        if (notifFlash && notification) return "notification";
        if (noticeFlash) return "notice";
        if (Idle.warning) return "idleWarn";
        if (workspaceFlash) return "workspace";
        if (tilingFlash) return "tiling";
        if (workingAgents.length > 0) return "agentWorking";
        if (Focus.active) return "focus";
        if (doneFlash && done) return "commandDone";
        switch (Settings.islandContent) {
            case "window": return Hypr.hasActiveWindow ? "window" : "clock";
            case "date":   return "date";
            default:       return Media.hasPlayer && Media.title.length > 0 ? "media" : "clock";
        }
    }
    readonly property bool isTransient: ["osd", "notification", "notice", "workspace", "tiling", "commandDone"].indexOf(mode) >= 0

    function notice(text: string, icon: string, ms: int): void {
        root.noticeText = text;
        root.noticeIcon = icon;
        root.noticeFlash = true;
        noticeTimer.interval = ms > 0 ? ms : Theme.durNotice;
        noticeTimer.restart();
    }

    Timer { id: previewTimer; interval: 4000; onTriggered: root.previewMode = "" }
    IpcHandler {
        target: "island"
        function preview(mode: string): void {
            if (mode === "commandDone" || mode === "commandFail") {
                root.done = mode === "commandDone" ? { kind: "command", text: "make test-integration", ok: true, detail: "2m14s" }
                                                   : { kind: "command", text: "make lint-go", ok: false, detail: "salida 1 · 48s" };
                mode = "commandDone";
            }
            if (mode === "notice") { root.noticeText = "Copiada · guardada en Imágenes"; root.noticeIcon = "check"; }
            root.previewMode = mode;
            previewTimer.restart();
        }
    }

    // ignore the initial workspace report at startup
    property bool _armed: false
    Timer { running: true; interval: 1500; onTriggered: root._armed = true }

    Timer { id: wsTimer; interval: Theme.durTransient; onTriggered: root.workspaceFlash = false }
    Timer { id: tilingTimer; interval: Theme.durTransient; onTriggered: root.tilingFlash = false }
    Timer { id: notifTimer; interval: Theme.durNotif; onTriggered: root.notifFlash = false }
    Timer { id: doneTimer; interval: Theme.durCommandDone; onTriggered: root.doneFlash = false }
    Timer { id: noticeTimer; interval: Theme.durNotice; onTriggered: root.noticeFlash = false }

    // the tiling mode of the workspace was switched (SUPER + T, the bar chip, IPC): "Modo scroll" / "Modo dwindle"
    Connections {
        target: Tiling
        function onChanged(mode) {
            root.tilingText = Tiling.notice;
            root.tilingFlash = true;
            tilingTimer.restart();
        }
    }

    // an agent finished and nobody is looking at it ("blocked" is persistent through blockedAgent instead)
    Connections {
        target: Herdr
        function onAttention(agent, kind) {
            if (kind !== "done") return;
            root.done = { kind: "agent", text: `${agent.workspace || agent.name} terminó`, ok: true, detail: agent.name };
            root.doneFlash = true;
            doneTimer.restart();
        }
    }

    // a long command finished (zsh hooks → qs ipc call commands finished …)
    Connections {
        target: Commands
        function onDone(cmd) {
            root.done = { kind: "command", text: cmd.command, ok: cmd.code === 0, detail: cmd.code === 0 ? Commands.formatDuration(cmd.seconds) : `salida ${cmd.code} · ${Commands.formatDuration(cmd.seconds)}` };
            root.doneFlash = true;
            doneTimer.restart();
        }
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

    // Notifs.arrived is not emitted while DND is on or while notifications are held (recording / focus mode)
    Connections {
        target: Notifs
        function onArrived(n) {
            root.notification = n;
            root.notifFlash = true;
            notifTimer.restart();
        }
    }

    // Bluetooth: a device connected / its battery dropped under 15 % (Fecha y hora timers use the same notice line)
    Connections {
        target: Bluetooth
        function onDeviceConnected(name) { if (root._armed) root.notice(`${name} conectado`, "bluetooth", Theme.durNotice); }
        function onBatteryLow(name, pct) { root.notice(`${name} · batería ${pct} %`, "batteryAlert", Theme.durNotice * 2); }
    }
}
