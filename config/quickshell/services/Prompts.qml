// Prompt composer state, data only. Every text comes from `dragon-prompt build` (deterministic, no model) and leaves
// only through send() after the user presses «Enviar»/«Copiar». Nothing runs while the composer is closed.
/**
 * Properties:
 *   - status: ok|loading|unavailable|error · message: human text of the last tool error · actionError: last send error
 *   - templates: [{id, name, builtin}] from `dragon-prompt templates --project <slug> --json`
 *   - composerOpen: bool — the drawer is visible (TallerPanel shows it over the active tab)
 *   - mode: "send" | "start" — «start» is «Iniciar con prompt…»: the target is a new agent in a new worktree
 *   - template, project (slug), card (key or ""), extraBlocks (["tipo:arg", …]), off ([block id, …]), selectionText
 *   - result: {text, tokens, blocks:[{id,type,label,tokens,enabled,truncated,redactions,text?}], warnings:[]}
 *   - segments: [{id, label, tokens, text}] — the preview split by the `## Etiqueta` headers of result.text
 *   - redactions: int — secrets struck out in the enabled blocks · building, sending: bool
 *   - target: "herdr:<id>" | "clipboard" | "start:claude" | "start:codex" · targets: [{id, label, enabled}]
 *   - startWarning / startKind / startStep — «Iniciar»: WIP warning waiting for confirmation, chosen agent, step on screen
 *   - warnAt / highAt [readonly, Settings.tokenWarnAt / tokenHighAt]: token thresholds (green < warnAt ≤ amber < highAt ≤ red); level: ligero|medio|pesado
 * Functions:
 *   - open(opts {template, card, blocks, target, mode, selection}) · close() · refreshTemplates()
 *   - setTemplate(id) · toggleBlock(id) · addBlock("tipo:arg") · removeBlock(index) · rebuild()
 *   - send() (to `target`; "start:<kind>" runs startCard) · startCard(kind, confirmed) · copy() (clipboard) · saveTemplate(name, callback) — `dragon-mem template save`
 *   - estimate(opts, callback(result)) — one-off build for counters outside the composer (Revisión)
 *   - levelFor(tokens) · colorLevel(tokens): "ok"|"warn"|"high"
 * IPC (target "prompt"): open(template) — opens the Taller with the composer · close() · state(): JSON
 * Signals: sent(target, card, result) — delivered; started(card, result) — «Iniciar» finished (see startCard)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string tool: `${home}/.local/bin/dragon-prompt`
    property string status: "unavailable"
    property string message: "El compositor todavía no se ha abierto"
    property string actionError: ""
    property var templates: []
    property bool composerOpen: false
    property string mode: "send"
    property string template: "libre"
    property string project: ""
    property string card: ""
    property var extraBlocks: []
    property var off: []
    property string selectionText: ""
    property var result: ({ text: "", tokens: 0, blocks: [], warnings: [] })
    property bool building: false
    property bool sending: false
    property string target: "clipboard"
    property string startWarning: ""
    property string startKind: "claude"
    property string startStep: ""
    readonly property int warnAt: Settings.tokenWarnAt     // Ajustes › Taller (default 1 500 / 3 000)
    readonly property int highAt: Settings.tokenHighAt
    property int _generation: 0
    readonly property int redactions: (result.blocks ?? []).filter(b => b.enabled !== false).reduce((n, b) => n + (b.redactions ?? 0), 0)
    readonly property string level: levelFor(result.tokens ?? 0)
    readonly property var targets: {
        if (mode === "start") return [{ id: "start:claude", label: "claude · nuevo worktree", enabled: true }, { id: "start:codex", label: "codex · nuevo worktree", enabled: true }];
        const list = (Herdr.agents ?? []).filter(a => !a.helper_of).map(a => ({
            id: "herdr:" + (a.id || a.pane),
            label: `${a.kind || "agente"} · ${a.card || a.space || a.pane}` + (a.state === "blocked" ? " · espera decisión" : ""),
            enabled: a.state !== "blocked"
        }));
        return list.concat([{ id: "clipboard", label: "Portapapeles", enabled: true }]);
    }
    readonly property var segments: {
        const blocks = (result.blocks ?? []).filter(b => b.enabled !== false);
        if (blocks.every(b => typeof b.text === "string")) return blocks.map(b => ({ id: b.id, label: b.label, tokens: b.tokens, text: b.text }));
        const parts = [];
        let current = null;
        for (const line of (result.text ?? "").split("\n")) {
            if (line.startsWith("## ")) { current = { label: line.slice(3), lines: [] }; parts.push(current); }
            else if (current) current.lines.push(line);
        }
        return parts.map((p, i) => ({ id: blocks[i]?.id ?? String(i), label: blocks[i]?.label ?? p.label, tokens: blocks[i]?.tokens ?? 0, text: p.lines.join("\n").trim() }));
    }
    signal sent(string target, string card, var result)
    signal started(string card, var result)

    function levelFor(tokens): string { return tokens < warnAt ? "ligero" : tokens < highAt ? "medio" : "pesado"; }
    function colorLevel(tokens): string { return tokens < warnAt ? "ok" : tokens < highAt ? "warn" : "high"; }
    // project, card and template of a delivery, so its prompt_run is attributed (the CLI keeps no state from `build`)
    function attribution(key): var {
        return (project ? ["--project", project] : []).concat(key ? ["--card", key] : []).concat(template ? ["--template", template] : []);
    }
    function argv(args): var { return ["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', tool].concat(args).concat(["--json"]); }
    Component { id: request; ToolRequest {} }
    Component { id: stdinRequest; StdinRequest {} }
    function _failure(r): void {
        status = r.error?.code === "missing_tool" ? "unavailable" : "error";
        message = r.error?.code === "missing_tool" ? "dragon-prompt no está instalado: ejecuta ./update.sh" : (r.error?.message ?? "Error del compositor");
    }

    function open(opts): void {
        const o = opts ?? {};
        mode = o.mode === "start" ? "start" : "send";
        project = o.project ?? Mem.selectedSlug ?? "";
        card = o.card ?? "";
        template = o.template || (card ? "implementar-tarjeta" : "libre");
        extraBlocks = (o.blocks ?? []).slice();
        selectionText = o.selection ?? "";
        off = [];
        actionError = ""; startWarning = ""; startStep = "";
        result = { text: "", tokens: 0, blocks: [], warnings: [] };
        const agent = card ? (Herdr.agents ?? []).find(a => a.card === card && a.state !== "blocked") : null;
        target = o.target || (mode === "start" ? "start:claude" : agent ? "herdr:" + (agent.id || agent.pane) : "clipboard");
        composerOpen = true;
        refreshTemplates();
        rebuild();
    }
    function close(): void { composerOpen = false; _generation++; building = false; selectionText = ""; result = { text: "", tokens: 0, blocks: [], warnings: [] }; }
    function refreshTemplates(): void {
        const p = request.createObject(root, { callback: r => { if (r.ok) templates = r.templates ?? []; else _failure(r); } });
        p.exec(argv(["templates"].concat(project ? ["--project", project] : [])));
    }
    function setTemplate(id): void { if (template === id) return; template = id; off = []; rebuild(); }
    function toggleBlock(id): void {
        const next = off.slice(), i = next.indexOf(id);
        if (i >= 0) next.splice(i, 1); else next.push(id);
        off = next; debounce.restart();
    }
    function addBlock(spec): void { if (!spec) return; extraBlocks = extraBlocks.concat([spec]); rebuild(); }
    function removeBlock(index): void { const next = extraBlocks.slice(); next.splice(index, 1); extraBlocks = next; rebuild(); }
    function buildArgs(o): var {
        const args = ["build", "--template", o.template, "--project", o.project];
        if (o.card) args.push("--card", o.card);
        for (const b of o.blocks ?? []) args.push("--block", b);
        if ((o.off ?? []).length) args.push("--off", o.off.join(","));
        return args;
    }
    function _build(o, callback): void {
        const component = o.selection ? stdinRequest : request;
        const p = component.createObject(root, { callback: callback, input: o.selection ?? "" });
        p.exec(argv(buildArgs(o)));
    }
    function rebuild(): void {
        if (!composerOpen) return;
        if (!project) { status = "error"; message = "Selecciona un proyecto para componer"; return; }
        const generation = ++_generation;
        building = true;
        _build({ template: template, project: project, card: card, blocks: extraBlocks, off: off, selection: selectionText }, r => {
            if (generation !== _generation) return;
            building = false;
            if (r.ok) { result = r; status = "ok"; message = ""; } else _failure(r);
        });
    }
    function estimate(opts, callback): void {
        if (!opts?.project) return;
        _build({ template: opts.template, project: opts.project, card: opts.card ?? "", blocks: opts.blocks ?? [], off: [] }, callback);
    }
    function _deliver(destination, after): void {
        if (sending || !result.text) return;
        if (destination.startsWith("start:")) { startCard(destination.slice(6)); return; }
        sending = true; actionError = "";
        const text = result.text, key = card, snapshot = result;
        const p = stdinRequest.createObject(root, { input: text, callback: r => {
            sending = false;
            if (!r.ok) { actionError = r.error?.code === "missing_tool" ? "dragon-prompt no está instalado: ejecuta ./update.sh" : (r.error?.message ?? "No se pudo enviar"); return; }
            sent(destination, key, snapshot);
            if (after) after();
        } });
        p.exec(argv(["send", "--target", destination, "--stdin"].concat(attribution(key))));
    }
    function send(): void { _deliver(target, () => close()); }
    function copy(): void { _deliver("clipboard", null); }
    function saveTemplate(name, callback): void {
        const clean = (name ?? "").trim();
        if (!clean) return;
        const blocks = (result.blocks ?? []).map(b => ({ type: b.type, label: b.label, arg: b.arg ?? null, enabled: off.indexOf(b.id) < 0 }));
        Mem.call(["template", "save", "--name", clean, "--blocks", JSON.stringify(blocks)].concat(project ? ["--project", project] : []), r => {
            if (r.ok) refreshTemplates(); else actionError = r.error?.message ?? "No se pudo guardar la plantilla";
            if (callback) callback(r);
        });
    }
    // «Iniciar con prompt…»: only after «Enviar e iniciar». worktree add → herdr start → send (records prompt_run) →
    // card set branch/worktree/agent_ref → move to «En curso». A full WIP asks first (startWarning + startCard(kind, true)).
    function branchFor(c): string {
        const words = (c.title ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
        return `${c.kind || "feat"}/${c.key.toLowerCase()}${words ? "-" + words.slice(0, 32).replace(/-$/, "") : ""}`;
    }
    function worktreeFor(p, c): string { return `${p.path}-${c.key.toLowerCase().replace(/-/g, "")}`; }
    function _tool(name, args, callback, input): void {
        const component = input === undefined ? request : stdinRequest;
        const p = component.createObject(root, { callback: callback, input: input ?? "" });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', `${home}/.local/bin/${name}`].concat(args).concat(["--json"]));
    }
    function _stop(step, r): void {
        sending = false; startStep = "";
        actionError = `${step}: ` + (r.error?.code === "missing_tool" ? "herramienta no instalada (ejecuta ./update.sh)" : (r.error?.message ?? "error"));
    }
    function startCard(kind, confirmed): void {
        const c = Mem.cardByKey(card), p = Mem.project;
        if (!c || !p) { actionError = "Selecciona una tarjeta del proyecto"; return; }
        if (sending || !result.text) return;
        const doing = (Mem.cards ?? []).filter(x => x.col === "doing").length;
        if (!confirmed && doing >= (p.wip_limit ?? 3)) { startWarning = `«En curso» está lleno (${doing} / ${p.wip_limit ?? 3}). Iniciar otro agente supera el WIP.`; startKind = kind; return; }
        startWarning = ""; actionError = ""; sending = true;
        const text = result.text, snapshot = result, key = c.key;
        const branch = c.branch || branchFor(c), worktree = c.worktree || worktreeFor(p, c);
        const afterWorktree = () => {
            startStep = "Arrancando el agente…";
            _tool("dragon-herdr", ["start", "--cwd", worktree, "--kind", kind, "--name", key], h => {
                if (!h.ok) return _stop("Agente", h);
                startStep = "Enviando el prompt…";
                _tool("dragon-prompt", ["send", "--target", "herdr:" + h.id, "--stdin"].concat(attribution(key)), s => {
                    Mem.setCard(key, { branch: branch, worktree: worktree, agent_ref: h.id }, () => Mem.moveCard(key, "doing", true, () => {
                        sending = false; startStep = "";
                        if (!s.ok) { actionError = "El agente arrancó, pero el prompt no se pudo enviar: " + (s.error?.message ?? "error") + ". Usa «Copiar»."; return; }
                        sent("herdr:" + h.id, key, snapshot); started(key, snapshot); Herdr.refresh(); close();
                    }));
                }, text);
            });
        };
        if (c.worktree) { afterWorktree(); return; }
        startStep = "Creando el worktree…";
        _tool("dragon-git", ["worktree", "add", "--repo", p.path, "--branch", branch, "--path", worktree], w => {
            if (!w.ok) return _stop("Worktree", w);
            Mem.setCard(key, { branch: branch, worktree: worktree }, afterWorktree);
        });
    }
    Timer { id: debounce; interval: 150; onTriggered: root.rebuild() }
    IpcHandler {
        target: "prompt"
        function open(template: string): void { Taller.openComposer({ template: template }); }
        function close(): void { root.close(); }
        function state(): string { return JSON.stringify({ open: root.composerOpen, template: root.template, card: root.card, tokens: root.result.tokens ?? 0, target: root.target, status: root.status }); }
    }
}
