// Review of an agent's worktree (32-taller-revision), data only. Files and diffs from dragon-git, «seen» by content and
// line comments from dragon-mem. The live watch runs only while the Revisión tab is visible and «Seguir en vivo» is on.
/**
 * Properties:
 *   - active: bool (set by Taller) · live: bool («Seguir en vivo», default on) · watching: the dragon-git watch runs · status: ok|loading|unavailable|error · message
 *   - cardKey: string · card: the Mem card · candidates: cards with a worktree or an agent (review first, then doing)
 *   - repo: card.worktree or the project path · base: bool — files/diffs are against Gate.base (dragon-git `--base`)
 *   - files: [{path, status, add, del, staged, seen, changed}] — changed = seen once, content differs now
 *   - seenCount / unseenCount: int · selectedPath · diffData: {hunks:[…]} (same shape as Git.diffData)
 *   - comments: [{id, path, line, text, sent}] · reviewTokens: int (estimate of the revisar-cambios prompt) · reviewLevel
 *   - actionError
 * Functions:
 *   - activate(value) · setCard(key) · refresh() · select(path) · markSeen(path) · addComment(path, line, text)
 *   - setLive(value)
 * Comments become «sent» when Prompts reports a revisar-cambios prompt for this card (comment mark-sent).
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string gitTool: `${Quickshell.env("HOME")}/.local/bin/dragon-git`
    property bool active: false
    property bool live: true
    property string status: "unavailable"
    property string message: "Elige una tarjeta con worktree"
    property string actionError: ""
    property string cardKey: ""
    readonly property var card: Mem.cardByKey(cardKey)
    readonly property var candidates: (Mem.cards ?? []).filter(c => c.worktree || c.agent_ref)
        .sort((a, b) => (["review", "doing", "ready", "backlog", "done"].indexOf(a.col)) - (["review", "doing", "ready", "backlog", "done"].indexOf(b.col)))
    readonly property string repo: card?.worktree || Mem.project?.path || ""
    property bool base: false
    property var files: []
    property string selectedPath: ""
    property var diffData: ({ hunks: [] })
    property var comments: []
    property int reviewTokens: 0
    readonly property string reviewLevel: Prompts.levelFor(reviewTokens)
    property int _generation: 0
    readonly property bool watching: watch.running
    readonly property int seenCount: files.filter(f => f.seen).length
    readonly property int unseenCount: files.length - seenCount

    function slugArgs(): var { return Mem.selectedSlug ? ["--project", Mem.selectedSlug] : []; }
    function activate(value): void {
        if (active === value) return;
        active = value;
        if (active) { if (!cardKey || !card) cardKey = candidates[0]?.key ?? ""; refresh(); }
        _watch();
    }
    function setCard(key): void {
        if (cardKey === key) return;
        cardKey = key; _generation++;
        files = []; selectedPath = ""; diffData = { hunks: [] }; comments = []; reviewTokens = 0; actionError = "";
        if (active) refresh();
        _watch();
    }
    function setLive(value): void { live = value; _watch(); if (live && active) refresh(); }
    function _watch(): void {
        watch.running = false;
        if (active && live && repo) watch.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', gitTool, "watch", "--repo", repo, "--json"]);
    }
    onRepoChanged: _watch()
    function refresh(): void {
        if (!active) return;
        if (!card) { status = "unavailable"; message = Mem.project ? "Elige una tarjeta con worktree o agente" : "Selecciona un proyecto"; files = []; return; }
        const generation = _generation, key = cardKey;
        if (!files.length) status = "loading";
        Gate.changedFiles(repo, r => {
            if (generation !== _generation) return;
            if (!r.ok) { status = r.error?.code === "missing_tool" ? "unavailable" : "error"; message = r.error?.message ?? "No se pudo leer el worktree"; return; }
            base = !!r.base;
            Gate.seenList(key, Mem.selectedSlug, s => {
                if (generation !== _generation) return;
                const marks = {};
                for (const m of (s.ok ? s.seen : []) ?? []) marks[m.path] = m;
                files = r.files.map(f => Object.assign({}, f, { seen: !!marks[f.path]?.seen, changed: !!marks[f.path] && !marks[f.path].seen }));
                status = "ok"; message = "";
                if (!files.some(f => f.path === selectedPath)) select(files.find(f => !f.seen)?.path ?? files[0]?.path ?? "");
                else select(selectedPath);
            });
        });
        Mem.call(["comment", "list", key].concat(slugArgs()), c => { if (generation === _generation && c.ok) { comments = c.comments ?? []; estimate(); } });
    }
    function estimate(): void {
        const key = cardKey;
        Prompts.estimate({ template: "revisar-cambios", project: Mem.selectedSlug, card: key }, r => { if (r.ok && key === cardKey) reviewTokens = r.tokens ?? 0; });
    }
    Component { id: request; ToolRequest {} }
    function _git(args, callback): void { request.createObject(root, { callback: callback }).exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', gitTool].concat(args).concat(["--repo", repo, "--json"])); }
    function select(path): void {
        selectedPath = path;
        if (!path) { diffData = { hunks: [] }; return; }
        const f = files.find(x => x.path === path), generation = _generation;
        const load = staged => _git(["diff", "--path", path].concat(base ? ["--base", Gate.base] : staged ? ["--staged"] : []), r => {
            if (generation !== _generation || selectedPath !== path) return;
            if (!r.ok && base && Gate.unsupported(r)) { base = false; select(path); return; }
            if (!r.ok) { diffData = { hunks: [] }; actionError = r.error?.message ?? "No se pudo leer el diff"; return; }
            // Without --base a file that is only in the index has an empty working diff: read the staged one instead.
            if (!base && !staged && f?.staged && !(r.hunks ?? []).length && !r.binary) { load(true); return; }
            diffData = r;
        });
        load(false);
    }
    function markSeen(path): void {
        const key = cardKey;
        _git(["blob-hash", "--path", path], h => {
            if (!h.ok || !h.hash) { actionError = h.error?.message ?? "El archivo ya no existe: no se puede marcar"; return; }
            Mem.call(["seen", "set", key, "--path", path, "--hash", h.hash].concat(slugArgs()), r => {
                if (!r.ok) { actionError = r.error?.message ?? "No se pudo marcar"; return; }
                actionError = "";
                if (key === cardKey) files = files.map(f => f.path === path ? Object.assign({}, f, { seen: true, changed: false }) : f);
                if (card) Gate.evaluate(Object.assign({}, card, { events: Mem.details?.[key]?.events ?? [] }), Mem.project);
            });
        });
    }
    function addComment(path, line, text): void {
        if (!text.trim() || !cardKey) return;
        const key = cardKey;
        Mem.call(["comment", "add", key, "--path", path, "--line", String(line), "--text", text.trim()].concat(slugArgs()), r => {
            if (r.ok && key === cardKey) { comments = r.comments ?? []; estimate(); } else if (!r.ok) actionError = r.error?.message ?? "No se pudo guardar el comentario";
        });
    }
    Connections {
        target: Prompts
        function onSent(target, key, result) {
            if (key !== root.cardKey || Prompts.template !== "revisar-cambios") return;
            Mem.call(["comment", "mark-sent", key].concat(root.slugArgs()), r => { if (r.ok) root.comments = r.comments ?? []; });
        }
    }
    Timer { id: debounce; interval: 300; onTriggered: root.refresh() }
    Process {
        id: watch
        stdout: SplitParser { onRead: line => { if (root.active) debounce.restart(); } }
    }
}
