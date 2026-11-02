// Gates for «Hecho», data only: project tests through `dragon-gate`, diff files seen (dragon-git + dragon-mem seen) and
// conflicts with the base branch. Tests run only after an explicit run(); evaluate() reads, never writes.
/**
 * Properties:
 *   - status: ok|loading|unavailable|error · message
 *   - base: string — branch the worktrees are compared against ("main")
 *   - runs: {cardKey: {state: running|ok|fail|error, exit, seconds, tail:[…], lines:int, message}} (memory only)
 *   - gates: {cardKey: {tests:{state,label}, seen:{seen,total,changed,state}, conflicts:{state,label}, ready, needsConfirm}}
 *       tests.state: ok|fail|running|none|nocmd|error · seen.state: ok|pending · conflicts.state: ok|fail|unknown|loading
 *       ready: every gate green · needsConfirm: only «conflicts» is unknown (the tool lacks merge-check) — «Hecho» asks first
 *   - baseSupported / mergeCheckSupported: bool|null — whether dragon-git accepts the optional `--base`/`merge-check`
 * Functions:
 *   - run(card, project) — `dragon-gate run --project <slug> --cwd <worktree|path> --timeout 600 --json`, streamed
 *   - cancel(key) — SIGTERM to the running gate (the tool kills its process group)
 *   - evaluate(card, project) — refreshes gates[card.key]; called by Kanban when a card is shown
 *   - changedFiles(repo, callback({ok, files:[{path,status,add,del,staged}], base:bool})) — status against `base` when
 *     dragon-git supports `status --base`, otherwise the uncommitted changes (shared with Review)
 *   - seenList(key, project, callback) — `dragon-mem seen list`
 *   - testState(card) — tests gate from the last run or the last `gate` card_event
 * Signals: finished(key, result)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string tool: `${home}/.local/bin/dragon-gate`
    readonly property string gitTool: `${home}/.local/bin/dragon-git`
    property string status: "ok"
    property string message: ""
    property string base: "main"
    property var runs: ({})
    property var gates: ({})
    property var baseSupported: null
    property var mergeCheckSupported: null
    property var _procs: ({})
    signal finished(string key, var result)

    function wrap(path, args): var { return ["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', path].concat(args).concat(["--json"]); }
    function unsupported(r): bool { return !r.ok && ["invalid_response", "invalid_usage", "usage", "unknown_command"].indexOf(r.error?.code ?? "") >= 0; }
    Component { id: request; ToolRequest {} }
    function call(path, args, callback): void { request.createObject(root, { callback: callback }).exec(wrap(path, args)); }
    function _set(key, field, value): void {
        const all = Object.assign({}, gates), g = Object.assign({}, all[key] ?? {});
        g[field] = value;
        const t = g.tests?.state, s = g.seen?.state, c = g.conflicts?.state;
        g.ready = t === "ok" && s === "ok" && c === "ok";
        g.needsConfirm = t === "ok" && s === "ok" && c === "unknown";
        all[key] = g; gates = all;
    }
    function _setRun(key, value): void { const all = Object.assign({}, runs); all[key] = value; runs = all; }

    function workdir(card, project): string { return card?.worktree || project?.path || ""; }
    function changedFiles(repo, callback): void {
        if (!repo) { callback({ ok: false, files: [] }); return; }
        const plain = () => call(gitTool, ["status", "--repo", repo], r => callback(collect(r, false)));
        if (baseSupported === false) { plain(); return; }
        call(gitTool, ["status", "--repo", repo, "--base", base], r => {
            if (unsupported(r)) { baseSupported = false; plain(); return; }
            baseSupported = r.ok ? true : baseSupported;
            callback(collect(r, true));
        });
    }
    function collect(r, withBase): var {
        if (!r.ok) return { ok: false, files: [], error: r.error };
        const seen = {}, files = [];
        for (const group of ["staged", "changes", "untracked"])
            for (const f of r[group] ?? []) if (!seen[f.path]) { seen[f.path] = true; files.push(Object.assign({ staged: group === "staged" }, f)); }
        return { ok: true, files: files, base: withBase, conflicts: r.conflicts ?? [] };
    }
    function seenList(key, project, callback): void { Mem.call(["seen", "list", key].concat(project ? ["--project", project] : []), callback); }
    function testState(card, project): var {
        const live = runs[card?.key];
        if (live) return { state: live.state === "error" ? "error" : live.state, label: live.state === "running" ? `EN CURSO · ${live.lines ?? 0} L` : live.state === "ok" ? `OK · ${live.seconds ?? 0} s` : live.state === "fail" ? `FALLA · salida ${live.exit}` : (live.message || "ERROR") };
        if (project && !project.test_cmd) return { state: "nocmd", label: "SIN COMANDO" };
        const last = (card?.events ?? []).filter(e => e.kind === "gate").slice(-1)[0];
        if (!last) return { state: "none", label: "SIN EJECUTAR" };
        let data = last.data;
        try { if (typeof data === "string") data = JSON.parse(data); } catch (e) { data = {}; }
        const ok = data?.exit === 0 || data?.ok === true && data?.exit === undefined;
        return { state: ok ? "ok" : "fail", label: ok ? `OK · ${data?.seconds ?? 0} s` : `FALLA · salida ${data?.exit ?? "?"}` };
    }
    function evaluate(card, project): void {
        if (!card?.key) return;
        const key = card.key, slug = project?.slug ?? "", repo = workdir(card, project);
        _set(key, "tests", testState(card, project));
        changedFiles(repo, files => {
            seenList(key, slug, s => {
                const marks = {};
                for (const m of (s.ok ? s.seen : []) ?? []) marks[m.path] = m;
                const total = files.files.length, seen = files.files.filter(f => marks[f.path]?.seen).length;
                const changed = files.files.filter(f => marks[f.path] && !marks[f.path].seen).length;
                _set(key, "seen", { seen: seen, total: total, changed: changed, state: files.ok && seen === total ? "ok" : "pending" });
            });
            if ((files.conflicts ?? []).length) { _set(key, "conflicts", { state: "fail", label: `${files.conflicts.length} EN CONFLICTO` }); return; }
            if (!repo) { _set(key, "conflicts", { state: "unknown", label: "SIN COMPROBAR" }); return; }
            if (mergeCheckSupported === false) { _set(key, "conflicts", { state: "unknown", label: "SIN COMPROBAR" }); return; }
            _set(key, "conflicts", { state: "loading", label: "…" });
            call(gitTool, ["merge-check", "--repo", repo, "--base", base], r => {
                if (unsupported(r)) { mergeCheckSupported = false; _set(key, "conflicts", { state: "unknown", label: "SIN COMPROBAR" }); return; }
                if (!r.ok) { _set(key, "conflicts", { state: "unknown", label: r.error?.message ?? "SIN COMPROBAR" }); return; }
                mergeCheckSupported = true;
                const n = (r.conflicts ?? []).length;
                _set(key, "conflicts", n ? { state: "fail", label: `${n} EN CONFLICTO` } : { state: "ok", label: "OK" });
            });
        });
    }

    Component {
        id: runner
        Process {
            id: proc
            property string key: ""
            property var tail: []
            property int lines: 0
            property var final: null
            stdout: SplitParser {
                onRead: line => {
                    let value = null;
                    try { value = JSON.parse(line); } catch (e) { value = { t: "progress", line: line }; }
                    if (value.exit !== undefined || value.ok === false) { proc.final = value; return; }
                    const text = value.line ?? value.text ?? value.msg;
                    if (typeof text === "string") { proc.lines++; proc.tail = proc.tail.concat([text]).slice(-30); }
                    root._setRun(proc.key, { state: "running", lines: proc.lines, tail: proc.tail });
                    root._set(proc.key, "tests", root.testState({ key: proc.key }, null));
                }
            }
            onExited: (code, exitStatus) => {
                const r = proc.final ?? { ok: false, error: { code: code === 127 ? "missing_tool" : "invalid_response", message: code === 127 ? "dragon-gate no está instalado: ejecuta ./update.sh" : "Las pruebas terminaron sin resultado" } };
                const state = r.ok === false ? (r.error?.code === "no_test_cmd" ? "error" : (r.exit !== undefined ? "fail" : "error")) : (r.exit === 0 ? "ok" : "fail");
                root._setRun(proc.key, { state: state, exit: r.exit, seconds: r.seconds, tail: r.tail ?? proc.tail, lines: proc.lines, message: r.error?.message ?? "" });
                root._set(proc.key, "tests", root.testState({ key: proc.key }, null));
                const procs = Object.assign({}, root._procs); delete procs[proc.key]; root._procs = procs;
                root.finished(proc.key, r);
                Qt.callLater(() => proc.destroy());
            }
        }
    }
    function run(card, project): void {
        if (!card?.key || _procs[card.key]) return;
        const cwd = workdir(card, project);
        if (!project?.slug || !cwd) { _setRun(card.key, { state: "error", message: "Selecciona un proyecto con carpeta" }); return; }
        const p = runner.createObject(root, { key: card.key });
        const procs = Object.assign({}, _procs); procs[card.key] = p; _procs = procs;
        _setRun(card.key, { state: "running", lines: 0, tail: [] });
        _set(card.key, "tests", testState(card, null));
        p.exec(wrap(tool, ["run", "--project", project.slug, "--cwd", cwd, "--timeout", "600"]));
    }
    function cancel(key): void { if (_procs[key]) _procs[key].running = false; }
    function running(key): bool { return !!_procs[key]; }
}
