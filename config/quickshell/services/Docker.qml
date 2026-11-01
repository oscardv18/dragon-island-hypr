// Local Docker data only. active gates ALL reads/streams; no process survives deactivate().
// status/message/actionError; containers/issues/metrics/history/logs; selectedId/selected; inspectText.
// activate(bool), select(id), action(start|stop|restart), inspect(), shell(), refresh().
// logs remain memory-only (max 200 rows); repeated counts update the last matching row.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-docker`
    property bool active: false
    property string status: "unavailable"
    property string message: "Docker todavía no se ha cargado"
    property string actionError: ""
    property var containers: []
    property var issues: []
    property var metrics: ({})
    property var history: ({})
    property var logs: []
    property string selectedId: ""
    readonly property var selected: containers.find(c => c.id === selectedId) ?? null
    property string inspectText: ""
    property var _requests: []
    property bool _refreshing: false
    property int _generation: 0
    property bool busy: false
    readonly property int errorCount: containers.filter(c => issues.some(i => i.container === c.id)).length
    Component { id: request; ToolRequest {} }
    function argv(args): var { return ["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', tool].concat(args); }
    function failure(r): void {
        status = r.error?.code === "docker_permission" || r.error?.code === "docker_unavailable" || r.error?.code === "missing_tool" ? "unavailable" : "error";
        message = (r.error?.message ?? "Error de Docker") + (r.error?.hint ? " · " + r.error.hint : "");
    }
    function call(args, callback): void {
        const generation = _generation;
        const p = request.createObject(root, {callback: r => {
            _requests = _requests.filter(x => x !== p);
            if (generation !== _generation || !active) return;
            if (!r.ok) failure(r);
            if (callback) callback(r);
        }});
        _requests = _requests.concat([p]); p.exec(argv(args));
    }
    function activate(value): void { active = value; }
    onActiveChanged: {
        _generation++;
        if (active) { status = "loading"; refresh(); events.running = true; }
        else {
            stats.running = false; events.running = false; logProcess.running = false;
            for (const p of _requests) { p.callback = null; p.running = false; p.destroy(); }
            _requests = []; _refreshing = false; busy = false; logs = []; metrics = {}; history = {}; inspectText = "";
        }
    }
    function refresh(): void {
        if (!active || _refreshing) return;
        _refreshing = true;
        call(["ps", "--json"], r => {
            _refreshing = false;
            if (!r.ok) { containers = []; issues = []; stats.running = false; logProcess.running = false; return; }
            containers = r.containers ?? [];
            const currentMetrics = {}, currentHistory = {};
            for (const c of containers) {
                if (c.state === "running" && metrics[c.id]) currentMetrics[c.id] = metrics[c.id];
                if (history[c.id]) currentHistory[c.id] = history[c.id];
            }
            metrics = currentMetrics; history = currentHistory;
            status = "ok"; message = containers.length ? "" : "No hay contenedores";
            if (!containers.some(c => c.id === selectedId)) select(containers[0]?.id ?? "");
            else if (!logProcess.running) startLogs();
            if (!stats.running && containers.some(c => c.state === "running")) stats.running = true;
            call(["issues", "--json"], value => { if (value.ok) issues = value.issues ?? []; });
        });
    }
    function select(id): void { selectedId = id; inspectText = ""; logs = []; startLogs(); }
    function startLogs(): void {
        logProcess.running = false;
        if (active && selectedId) logProcess.exec(argv(["logs", selectedId, "--follow", "--tail", "200"]));
    }
    function acceptLog(line): void {
        try {
            const r = JSON.parse(line);
            if (r.ok === false) { failure(r); return; }
            const rows = logs.slice();
            const last = rows[rows.length-1];
            if (last && last.ts === r.ts && last.msg === r.msg && last.level === r.level) rows[rows.length-1] = r;
            else rows.push(r);
            logs = rows.slice(-200);
        } catch (e) { }
    }
    function acceptStats(line): void {
        try {
            const r = JSON.parse(line);
            if (!r.ok) { failure(r); return; }
            if (!containers.some(c => c.id === r.id && c.state === "running")) return;
            const next = Object.assign({}, metrics); next[r.id] = r; metrics = next;
            const h = Object.assign({}, history); h[r.id] = (h[r.id] ?? []).concat([r]).slice(-30); history = h;
        } catch (e) { }
    }
    function action(verb): void {
        if (!selectedId || busy || !active) return;
        busy = true; actionError = "";
        call(["action", selectedId, verb], r => { busy = false; if (!r.ok) actionError = message; refresh(); });
    }
    function inspect(): void {
        const id = selectedId;
        if (id) call(["inspect", id, "--json"], r => { if (r.ok && id === selectedId) inspectText = JSON.stringify(r.inspect, null, 2); });
    }
    function shell(): void {
        if (!selectedId || busy) return;
        const id = selectedId;
        const p = request.createObject(root, {callback: r => {
            if (r.ok) Quickshell.execDetached(["ghostty", "-e", "docker", "exec", "-it", id, "sh"]);
            else actionError = "Shell requiere docker y Ghostty instalados";
        }});
        p.exec(["sh", "-c", 'if command -v docker >/dev/null && command -v ghostty >/dev/null; then echo \'{"ok":true}\'; else echo \'{"ok":false}\'; fi']);
    }
    Timer { interval: 2000; running: root.active; repeat: true; onTriggered: root.refresh() }
    Process { id: stats; command: root.argv(["stats", "--stream"]); stdout: SplitParser { onRead: line => { if (root.active) root.acceptStats(line); } } }
    Process { id: events; command: root.argv(["events", "--follow"]); stdout: SplitParser { onRead: line => { if (root.active) root.refresh(); } } }
    Process { id: logProcess; stdout: SplitParser { onRead: line => { if (root.active) root.acceptLog(line); } } }
}
