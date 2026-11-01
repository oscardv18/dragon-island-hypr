// Agent data through dragon-herdr (verified API: docs/HERDR-API.md). One always-on watch --record, no CLI polling.
// status/message: ok|loading|unavailable|error; running, version, agents, workspaces, counts, longestWorking.
// agents retain the old pane/agent/workspace/since(ms) API and add id/kind/space/card/project/helper_of.
// focusAgent(a), open(), readAgent(a), markSeen(a), snooze(a,minutes), focusNext(), attentionAgents/attentionAgent.
// readText/readId are memory-only; clearRead() drops terminal output on panel close. details contains branches only.
// navigatingToAgent(): shell.qml closes overlays before focus; attention(agent,kind): became blocked or done. No approval or rejection API exists in this service.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string tool: `${home}/.local/bin/dragon-herdr`
    readonly property string windowClass: "org.dragonisland.Herdr"
    property string status: "unavailable"
    property string message: "herdr no está en marcha"
    property bool running: false
    property string version: ""
    property var agents: []
    property var workspaces: []
    property var details: ({})
    property string readId: ""
    property string readText: ""
    property string actionError: ""
    property var _seen: ({})
    property var _snoozed: ({})
    property real _now: Date.now()
    property string _lastFocused: ""
    property bool _started: false
    property bool _loaded: false
    readonly property bool active: agents.length > 0
    readonly property var counts: {
        const c = { blocked: 0, working: 0, done: 0, idle: 0, unknown: 0 };
        for (const a of agents) if (c[a.state] !== undefined) c[a.state]++;
        return c;
    }
    readonly property var longestWorking: agents.filter(a => a.state === "working").sort((a,b) => a.since-b.since)[0] ?? null
    readonly property var attentionAgents: agents.filter(a => (_snoozed[a.pane] ?? 0) <= _now &&
        (a.state === "blocked" || (a.state === "done" && _seen[a.pane] !== a.since)))
        .slice().sort((a,b) => (a.state === "blocked" ? 0 : 1)-(b.state === "blocked" ? 0 : 1) || a.since-b.since);
    readonly property var attentionAgent: attentionAgents[0] ?? null
    signal attention(var agent, string kind)
    signal navigatingToAgent()

    function init(): void { if (!_started) { _started = true; watch.running = true; } }
    function open(): void { Quickshell.execDetached([root.tool]); }
    function refresh(): void {
        Mem.callHerdr(["snapshot"], r => {
            if (!r.ok) return;
            const rows = (r.agents ?? []).map(a => {
                const old = _raw.find(x => x.id === a.id && x.state === a.state);
                return old ? Object.assign({}, a, {since: old.since}) : a;
            });
            _event(JSON.stringify(Object.assign({}, r, {t:"snapshot", agents:rows})));
        });
    }
    Connections { target: Mem; function onChanged() { root.refresh(); } }
    function focusAgent(a): void {
        if (!a) return;
        navigatingToAgent();
        root.actionError = "";
        Mem.callHerdr(["focus", a.pane || a.id], r => { if (!r.ok) root.actionError = r.error?.message ?? "No se pudo enfocar el agente"; });
    }
    function focusNext(): void {
        const list = attentionAgents;
        if (list.length === 0) return;
        // A blocked agent always takes precedence over a completed one.
        const candidates = list.filter(a => a.state === list[0].state);
        const index = candidates.findIndex(a => a.pane === _lastFocused);
        const a = candidates[(index + 1) % candidates.length];
        _lastFocused = a.pane; focusAgent(a);
    }
    function markSeen(a): void {
        if (!a) return;
        const seen = Object.assign({}, _seen); seen[a.pane] = a.since; _seen = seen;
    }
    function snooze(a, minutes): void {
        if (!a) return;
        const hidden = Object.assign({}, _snoozed); hidden[a.pane] = Date.now() + minutes * 60000; _snoozed = hidden;
        _now = Date.now();
    }
    function clearRead(): void { readId = ""; readText = ""; }
    function readAgent(a): void {
        clearRead();
        if (!a) return;
        readId = a.pane;
        const pane = a.pane;
        Mem.callHerdr(["read", pane, "--lines", "8"], r => {
            if (readId !== pane) return;
            readText = r.ok ? (r.text ?? "") : (r.error?.message ?? "No se pudo leer el panel");
        });
    }
    Timer { interval: 30000; repeat: true; running: root._started; onTriggered: root._now = Date.now() }
    function _apply(rows, spaces, source, ver): void {
        const old = {};
        for (const a of agents) old[a.pane] = a.state;
        const next = rows.map(a => Object.assign({}, a, { pane: a.id, agent: a.kind, workspace: a.space,
            workspaceId: a.space_id, since: a.since * 1000 }));
        const branches = {};
        for (const a of next) branches[a.pane] = { branch: a.branch, prompt: "" };
        details = branches;
        agents = next;
        if (!next.some(a => a.pane === readId)) clearRead();
        workspaces = spaces.map(s => ({ id: s.id, label: s.name, state: s.state, number: s.number, focused: s.focused }));
        running = source === "herdr";
        status = running ? "ok" : "unavailable";
        message = running ? "" : "herdr no está en marcha";
        version = ver || "";
        _logActivity(old, next);
        if (_loaded) for (const a of next) if (old[a.pane] !== a.state && (a.state === "blocked" || a.state === "done")) attention(a,a.state);
        _loaded = true;
    }
    property var _raw: []
    property var _spaces: []
    function _event(text): void {
        let r;
        try { r = JSON.parse(text); } catch (e) { status = "error"; message = "Respuesta inválida de dragon-herdr"; return; }
        if (r.t === "ping") return;
        if (r.t === "snapshot") {
            _raw = r.agents ?? []; _spaces = r.spaces ?? [];
            _apply(_raw, _spaces, r.source, r.version);
        } else if (r.t === "agent") {
            const next = _raw.filter(a => a.id !== (r.id || r.agent?.id));
            if (r.op !== "remove" && r.agent) next.push(r.agent);
            _raw = next; _apply(next, _spaces, "herdr", version);
        } else if (r.ok === false) { status = "error"; message = r.error?.message ?? "Error de herdr"; }
    }
    Process {
        id: watch
        command: ["sh", "-c", 'if [ -x "$0" ]; then exec "$0" watch --record; else exit 127; fi', root.tool]
        stdout: SplitParser { onRead: text => root._event(text) }
        onExited: (code, exitStatus) => {
            root.running = false;
            root.status = code === 127 ? "unavailable" : "error";
            root.message = code === 127 ? "Falta dragon-herdr. Ejecuta ./update.sh" : "Se interrumpió el observador de herdr";
            if (root._started) retry.restart();
        }
    }
    Timer { id: retry; interval: 10000; onTriggered: watch.running = true }
    IpcHandler {
        target: "herdr"
        function attention(): void { root.focusNext(); }
        function state(): string { return JSON.stringify({status:root.status,agents:root.agents,attention:root.attentionAgent,error:root.actionError}); }
    }
    property var _activityIds: ({})     // pane → activity id
    function _logActivity(old: var, next: var): void {
        const ids = root._activityIds;
        for (const a of next) {
            const was = old[a.pane];
            if (a.state === "working" && was !== "working" && ids[a.pane] === undefined) {
                ids[a.pane] = "";
                const pane = a.pane;
                Activity.add("agent", `${a.agent} · ${a.workspace}`, Activity.now(), 0, "", id => { if (root._activityIds[pane] === "") root._activityIds[pane] = id ?? ""; });
            } else if (a.state !== "working" && ids[a.pane] !== undefined) {
                Activity.end(ids[a.pane], "ok");
                delete ids[a.pane];
            }
        }
        for (const pane of Object.keys(ids))
            if (!next.some(a => a.pane === pane)) { Activity.end(ids[pane], "ok"); delete ids[pane]; }
    }

}
