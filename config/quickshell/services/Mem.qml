// Project memory, data only. Calls dragon-mem on demand; no polling while the Taller is closed.
// status/message: ok|loading|unavailable|error; projects/cards: SQLite rows; selectedSlug/project: current project.
// refresh(), selectProject(slug), addProject(path,name,prefix,callback), logChange(key,old,new,source), call(args,callback).
// Callbacks receive the stable JSON result, including errors; no CLI output is interpreted as markup.
// fase5c (Kanban): stats (stats flow of the project) · details {key: {criteria, events}} · refreshBoard() (cards, stats and,
// when `card list` lacks criteria_total, one `card show` per card) · loadDetails(key) · addCard(title,kind,callback) ·
// moveCard(key,col,force,callback) (error wip_limit_reached is returned, never forced silently) · toggleCriterion(key,id) ·
// addCriterion(key,text) · setCard(key,fields,callback) · cardByKey(key).
// fase5c (Ajustes › Taller): setProject(slug,{wip_limit,test_cmd},callback) (`project set`; the row in `projects` is
// updated in place) · exportContext(slug,callback) (`export`: {path, bytes}, < 4 KB in <repo>/.dragon/CONTEXT.md).
// Both report errors only to their callback, never to status (a refused value must not blank the Taller).
// fase5e (punto 8): exports {slug: {path, bytes, at}} (last export per project) · every successful card change (add,
// move, set, criteria) schedules one quiet export of that project after autoExportDelay ms, so <repo>/.dragon/CONTEXT.md
// follows the current card without a click. Bursts collapse into one call; failures stay out of status.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-mem`
    property string status: "unavailable"
    property string message: "La memoria del Taller todavía no se ha cargado"
    property var projects: []
    property var cards: []
    property string selectedSlug: ""
    readonly property var project: projects.find(p => p.slug === selectedSlug) ?? null
    property bool _refreshing: false
    property var stats: null
    property var details: ({})
    property int _boardGeneration: 0
    property var exports: ({})
    readonly property int autoExportDelay: 400
    property var _exportQueue: []
    signal changed()

    Timer { id: exportTimer; interval: root.autoExportDelay; onTriggered: root._flushExports() }
    function _scheduleExport(slug): void {
        if (!slug) return;
        if (_exportQueue.indexOf(slug) < 0) _exportQueue = _exportQueue.concat([slug]);
        exportTimer.restart();
    }
    function _flushExports(): void {
        const queue = _exportQueue; _exportQueue = [];
        for (const slug of queue) exportContext(slug, null);
    }

    Component {
        id: requestComponent
        Process {
            id: proc
            property var callback: null
            property bool reportStatus: true
            property var result: null
            property bool ended: false
            property bool collected: false
            property int exitCode: 0
            function finish(): void {
                if (!ended || !collected) return;
                const r = result ?? { ok: false, error: { code: exitCode === 127 ? "missing_tool" : "invalid_response", message: "dragon-mem no está disponible. Ejecuta ./update.sh" } };
                if (!r.ok && reportStatus) { root.status = exitCode === 127 ? "unavailable" : "error"; root.message = r.error?.message ?? "Error de memoria"; }
                if (callback) callback(r);
                Qt.callLater(() => proc.destroy());
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    try { proc.result = JSON.parse(this.text); } catch (e) { proc.result = null; }
                    proc.collected = true; proc.finish();
                }
            }
            onExited: (code, exitStatus) => { proc.exitCode = code; proc.ended = true; proc.finish(); }
        }
    }
    function call(args, callback, quiet): void {
        const p = requestComponent.createObject(root, { callback: callback ?? null, reportStatus: !quiet });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', root.tool].concat(args).concat(["--json"]));
    }
    function callHerdr(args, callback): void {
        const p = requestComponent.createObject(root, { callback: callback ?? null, reportStatus: false });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', `${Quickshell.env("HOME")}/.local/bin/dragon-herdr`].concat(args).concat(["--json"]));
    }
    property bool _refreshPending: false
    function refresh(): void {
        // A refresh requested mid-flight runs again afterwards, so a write made meanwhile is never shown stale.
        if (_refreshing) { _refreshPending = true; return; }
        _refreshing = true;
        status = "loading";
        call(["project", "list"], r => {
            if (r.ok) {
                projects = r.projects ?? [];
                if (!projects.some(p => p.slug === selectedSlug)) selectedSlug = projects[0]?.slug ?? "";
                status = "ok"; message = "";
                refreshCards();
            }
            _refreshing = false;
            if (_refreshPending) { _refreshPending = false; refresh(); }
        });
    }
    function refreshCards(): void {
        if (!selectedSlug) { cards = []; return; }
        const slug = selectedSlug;
        call(["card", "list", "--project", slug], r => { if (r.ok && slug === selectedSlug) cards = r.cards ?? []; });
    }
    function selectProject(slug): void { selectedSlug = slug; details = {}; stats = null; refreshCards(); }
    function cardByKey(key): var { return cards.find(c => c.key === key) ?? null; }
    function _scope(): var { return selectedSlug ? ["--project", selectedSlug] : []; }
    function _storeDetails(key, r): void {
        if (!r.ok) return;
        const all = Object.assign({}, details);
        all[key] = { criteria: r.criteria ?? all[key]?.criteria ?? [], events: r.events ?? all[key]?.events ?? [] };
        details = all;
    }
    function loadDetails(key): void { if (key) call(["card", "show", key].concat(_scope()), r => _storeDetails(key, r)); }
    function refreshBoard(): void {
        if (!selectedSlug) { cards = []; stats = null; return; }
        const slug = selectedSlug, generation = ++_boardGeneration;
        call(["card", "list", "--project", slug], r => {
            if (!r.ok || slug !== selectedSlug || generation !== _boardGeneration) return;
            cards = r.cards ?? [];
            for (const c of cards) if (c.criteria_total === undefined || !details[c.key]) loadDetails(c.key);
        });
        call(["stats", "flow", "--project", slug], r => { if (r.ok && slug === selectedSlug) stats = r; });
    }
    function addCard(title, kind, callback): void {
        if (!selectedSlug || !title.trim()) return;
        const slug = selectedSlug;
        call(["card", "add", "--project", slug, "--title", title.trim(), "--kind", kind || "feat"], r => { if (r.ok) { refreshBoard(); _scheduleExport(slug); } if (callback) callback(r); });
    }
    function moveCard(key, col, force, callback): void {
        const slug = selectedSlug;
        call(["card", "move", key, "--to", col].concat(force ? ["--force"] : []).concat(_scope()), r => {
            if (r.ok) { refreshBoard(); loadDetails(key); changed(); _scheduleExport(slug); }
            if (callback) callback(r);
        });
    }
    function setCard(key, fields, callback): void {
        const args = ["card", "set", key].concat(_scope()), slug = selectedSlug;
        for (const k in fields) args.push("--" + k.replace(/_/g, "-"), String(fields[k]));
        call(args, r => { if (r.ok) { refreshBoard(); changed(); _scheduleExport(slug); } if (callback) callback(r); });
    }
    function toggleCriterion(key, id): void {
        const slug = selectedSlug;
        call(["card", "criteria", "toggle", key, String(id)].concat(_scope()), r => { _storeDetails(key, r); if (r.ok) _scheduleExport(slug); });
    }
    function addCriterion(key, text): void {
        if (!text.trim()) return;
        const pos = (details[key]?.criteria ?? []).length;
        const slug = selectedSlug;
        call(["card", "criteria", "add", key, "--text", text.trim(), "--pos", String(pos)].concat(_scope()), r => { _storeDetails(key, r); if (r.ok) _scheduleExport(slug); });
    }
    function addProject(path, name, prefix, callback): void {
        const args = ["project", "add", "--path", path];
        if (name) args.push("--name", name);
        if (prefix) args.push("--prefix", prefix);
        call(args, r => { if (r.ok) { selectedSlug = r.project.slug; refresh(); changed(); } if (callback) callback(r); });
    }
    function setProject(slug, fields, callback): void {
        if (!slug) return;
        const args = ["project", "set", slug];
        for (const k in fields) args.push("--" + k.replace(/_/g, "-"), String(fields[k]));
        call(args, r => {
            if (r.ok && r.project) { projects = projects.map(p => p.slug === slug ? Object.assign({}, p, r.project) : p); changed(); }
            if (callback) callback(r);
        }, true);
    }
    function exportContext(slug, callback): void {
        if (!slug) return;
        call(["export", "--project", slug], r => {
            if (r.ok) { const all = Object.assign({}, exports); all[slug] = { path: r.path, bytes: r.bytes, at: new Date() }; exports = all; }
            if (callback) callback(r);
        }, true);
    }
    function logChange(key, oldValue, newValue, source): void {
        if (JSON.stringify(oldValue) === JSON.stringify(newValue)) return;
        call(["system", "log", "add", "--key", key, "--old", JSON.stringify(oldValue), "--new", JSON.stringify(newValue), "--source", source || "settings"], r => { if (r.ok) changed(); });
    }
}
