// =============================================================================
// dragon-island — FileOps.qml (file operation queue of the explorer). Data only.
// Every operation is `dragon-files op … --json-progress` (PLAN-FASE-5 §5.7); archives use run() with their own args.
// Transfers (copy, move, delete, extract, create) run one after another; quick ones (rename, mkdir, trash, link)
// start at once so a long copy never blocks them. Cancel = SIGTERM (the tool cleans up).
// =============================================================================
/**
 * Properties:
 *   - queue: var ([{id, kind, sources, dest, count, index, pct, file, bps, state: queued|running|conflict|done|error|
 *       cancelled, error: {code, message, hint}|null, conflict: {file, dest}|null, result}])
 *   - transfers: var [readonly] — the queue without quick operations
 *   - active: var [readonly] — the transfer the status bar shows (running, else the first in conflict/queued), or null
 *   - pending: int [readonly] — transfers not finished yet
 *   - lastError: var — the last failed operation (until dismissed)
 *   - canUndo: bool · undoLabel: string — the last move/rename can be reverted
 *
 * Functions:
 *   - copy(paths, dest) · move(paths, dest) · trash(paths) · remove(paths) (permanent, passes --confirm: the view
 *       asks first) · rename(path, newName) · mkdir(dir, name) · link(paths, dest)
 *   - emptyTrash() · restore(uris) — `trash empty --confirm` / `trash restore <uri…>` (the view asks first)
 *   - run(kind, args, extra {sources, dest, count, input, callback}) — any `--json-progress` command (Archives)
 *   - cancel(id) · answer(id, choice: skip|overwrite|rename, all: bool) — reply to a conflict question
 *   - undo() · dismissError() · clearFinished()
 *
 * Stream (one JSON per line): {"t":"progress","pct","file","bps","index","count"} · {"t":"conflict","file","dest"}
 *   (the tool waits for one stdin line {"answer","all"}) · {"t":"done","moved":[{"from","to"}]} · {"t":"error","error"}
 * Signals: finished(var op) — after done, error or cancel
 * =============================================================================
 */
pragma Singleton
import Quickshell
import QtQuick
import "../modules/files/files.js" as F

Singleton {
    id: root
    property var queue: []
    property var lastError: null
    property var _undo: null
    property int _seq: 0
    property var _procs: ({})
    // derived lists are recomputed when the queue changes (not as bindings: handlers update the queue while a
    // binding would still be evaluating, which Qt reports as a loop)
    property var transfers: []
    property var active: null
    property int pending: 0
    onQueueChanged: {
        const t = queue.filter(o => _isTransfer(o.kind));
        transfers = t;
        active = t.find(o => o.state === "running" || o.state === "conflict") ?? t.find(o => o.state === "queued") ?? null;
        pending = t.filter(o => o.state === "queued" || o.state === "running" || o.state === "conflict").length;
    }
    readonly property bool canUndo: _undo !== null
    readonly property string undoLabel: _undo?.label ?? ""
    signal finished(var op)

    Component { id: requestComponent; FilesRequest {} }

    function _isTransfer(kind): bool { return ["copy", "move", "delete", "extract", "create"].indexOf(kind) >= 0; }
    function _set(id, patch): void { queue = queue.map(o => o.id === id ? Object.assign({}, o, patch) : o); }
    function _get(id): var { return queue.find(o => o.id === id) ?? null; }

    function copy(paths, dest): void { _enqueue("copy", ["op", "copy"].concat(paths, ["--dest", dest, "--conflict", "ask"]), { sources: paths, dest: dest }); }
    function move(paths, dest): void { _enqueue("move", ["op", "move"].concat(paths, ["--dest", dest, "--conflict", "ask"]), { sources: paths, dest: dest }); }
    function trash(paths): void { _enqueue("trash", ["op", "trash"].concat(paths), { sources: paths }); }
    function remove(paths): void { _enqueue("delete", ["op", "delete"].concat(paths, ["--confirm"]), { sources: paths }); }
    function rename(path, newName): void { _enqueue("rename", ["op", "rename", path, "--name", newName], { sources: [path], dest: F.join(F.parent(path), newName) }); }
    function mkdir(dir, name): void { _enqueue("mkdir", ["op", "mkdir", dir, "--name", name], { dest: F.join(dir, name) }); }
    function link(paths, dest): void { _enqueue("link", ["op", "link"].concat(paths, ["--dest", dest]), { sources: paths, dest: dest }); }
    function emptyTrash(): void { _enqueue("delete", ["trash", "empty", "--confirm"], { sources: [F.TRASH] }); }
    function restore(uris): void { _enqueue("move", ["trash", "restore"].concat(uris), { sources: uris }); }
    function run(kind, args, extra): int { return _enqueue(kind, args, extra ?? {}); }

    function _enqueue(kind, args, extra): int {
        const id = ++_seq;
        const op = { id: id, kind: kind, args: args, sources: extra.sources ?? [], dest: extra.dest ?? "", count: extra.count ?? (extra.sources?.length ?? 1),
                     index: 0, pct: 0, file: "", bps: 0, state: "queued", error: null, conflict: null, result: null,
                     input: extra.input ?? "", callback: extra.callback ?? null };
        queue = queue.concat([op]);
        if (_isTransfer(kind)) _pump(); else _start(op);
        return id;
    }
    function _pump(): void {
        if (transfers.some(o => o.state === "running" || o.state === "conflict")) return;
        const next = transfers.find(o => o.state === "queued");
        if (next) _start(next);
    }
    function _start(op): void {
        const p = requestComponent.createObject(root, { args: op.args.concat(["--json-progress"]), stream: true, keepStdin: true, input: op.input });
        const procs = Object.assign({}, _procs); procs[op.id] = p; _procs = procs;
        _set(op.id, { state: "running", input: "" });
        p.event.connect(ev => {
            if (ev.t === "progress") _set(op.id, { pct: ev.pct ?? 0, file: ev.file ?? "", bps: ev.bps ?? 0, index: ev.index ?? 0, count: ev.count ?? _get(op.id).count, state: "running" });
            else if (ev.t === "conflict") _set(op.id, { state: "conflict", conflict: { file: ev.file ?? "", dest: ev.dest ?? "" } });
        });
        p.done.connect(r => _finish(op.id, r));
        p.start();
    }
    function _finish(id, r): void {
        const procs = Object.assign({}, _procs); delete procs[id]; _procs = procs;
        const op = _get(id);
        if (!op) return;
        const state = r.ok ? "done" : (r.error?.code === "cancelled" ? "cancelled" : "error");
        _set(id, { state: state, pct: r.ok ? 100 : op.pct, error: r.ok ? null : r.error, conflict: null, result: r });
        const done = _get(id);
        if (state === "error") lastError = done;
        if (r.ok && (op.kind === "move" || op.kind === "rename")) _rememberUndo(op, r);
        if (op.callback) op.callback(r);
        finished(done);
        // finished entries leave the queue after a moment; errors stay until dismissed
        if (state !== "error") Qt.callLater(() => { queue = queue.filter(o => o.id !== id); });
        _pump();
    }
    function cancel(id): void {
        const p = _procs[id];
        if (p) p.cancel();
        else if (_get(id)?.state === "queued") { _set(id, { state: "cancelled" }); queue = queue.filter(o => o.id !== id); }
    }
    function answer(id, choice, all): void {
        const p = _procs[id];
        if (!p) return;
        p.answer({ answer: choice, all: !!all });
        _set(id, { state: "running", conflict: null });
    }
    function dismissError(): void {
        if (lastError) queue = queue.filter(o => o.id !== lastError.id);
        lastError = null;
    }
    function clearFinished(): void { queue = queue.filter(o => o.state === "queued" || o.state === "running" || o.state === "conflict"); }

    // ---- undo: the last move or rename, when the tool reported where everything ended up ----
    function _rememberUndo(op, r): void {
        const pairs = (r.moved ?? []).filter(m => m.from && m.to);
        if (!pairs.length) { _undo = null; return; }
        _undo = { label: (op.kind === "rename" ? "Deshacer renombrar " : "Deshacer mover ") + F.basename(pairs[0].from) + (pairs.length > 1 ? " y " + (pairs.length - 1) + " más" : ""), pairs: pairs };
    }
    function undo(): void {
        const u = _undo;
        if (!u) return;
        _undo = null;
        // group by original folder: same name → move back; different name → rename after moving back
        const groups = {};
        for (const m of u.pairs) {
            const dir = F.parent(m.from);
            (groups[dir] = groups[dir] ?? []).push(m);
        }
        for (const dir in groups) {
            const same = groups[dir].filter(m => F.basename(m.to) === F.basename(m.from) && F.parent(m.to) !== dir);
            const renamed = groups[dir].filter(m => F.parent(m.to) === dir);
            if (same.length) _enqueue("move", ["op", "move"].concat(same.map(m => m.to), ["--dest", dir, "--conflict", "ask"]), { sources: same.map(m => m.to), dest: dir });
            for (const m of renamed) _enqueue("rename", ["op", "rename", m.to, "--name", F.basename(m.from)], { sources: [m.to], dest: m.from });
        }
    }
}
