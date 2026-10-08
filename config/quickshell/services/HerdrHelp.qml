// =============================================================================
// dragon-island — HerdrHelp.qml
// Service: documentation of herdr for the "Herdr" panel (SUPER + SHIFT + A) — shortcuts, CLI commands, agent states
// =============================================================================
/**
 * Read-only: never starts or stops herdr and never writes its config. Everything comes from the installed binary, so it
 * follows the version: the default shortcuts from `herdr --default-config` (the [keys] section), the user's overrides from
 * ~/.config/herdr/config.toml, the commands from `herdr <group>` / `herdr <group> --help` (they only print usage).
 * Only the Spanish wording of each shortcut (the `labels` table below) is written by hand; an action herdr adds later
 * shows up under "Otros" with its own name.
 *
 * Properties:
 *   - available: bool [readonly] (the herdr binary exists)
 *   - loading: bool [readonly]
 *   - version: string [readonly]
 *   - prefix: string [readonly] (the prefix key in effect, "ctrl+b" by default)
 *   - keyGroups: list<var> [readonly] ({ name, rows: [{ action, text, keys: list<string> (key caps), custom: bool, unbound: bool }] })
 *   - commandGroups: list<var> [readonly] ({ name, rows: [{ usage, desc }] })
 *   - states: list<var> [readonly] ({ state, text })   (the lifecycle states herdr documents for agents)
 *
 * Functions:
 *   - refresh(): void
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string bin: Herdr.bin
    readonly property string userConfig: `${home}/.config/herdr/config.toml`

    property bool available: false
    property bool loading: false
    property string version: ""
    property string prefix: "ctrl+b"
    property var keyGroups: []
    property var commandGroups: []

    readonly property var states: [
        { state: "working", text: "El agente está trabajando." },
        { state: "blocked", text: "Herdr reconoció una pantalla de aprobación o una pregunta: espera tu respuesta." },
        { state: "done",    text: "Terminó y está listo para recibir entrada; aún no lo has visto." },
        { state: "idle",    text: "Listo para recibir entrada (ya visto)." },
        { state: "unknown", text: "Hay un agente pero herdr no puede clasificarlo con seguridad; no significa que haya terminado." }
    ]

    // action → [group, Spanish text]; the order inside a group is the order of herdr's default config
    readonly property var labels: ({
        help: ["Modo prefijo", "Ayuda"], settings: ["Modo prefijo", "Ajustes"], detach: ["Modo prefijo", "Desacoplar (la sesión sigue viva)"],
        reload_config: ["Modo prefijo", "Recargar la configuración"], open_notification_target: ["Modo prefijo", "Abrir el destino de la notificación"],
        goto: ["Modo prefijo", "Ir a… (buscador)"], toggle_sidebar: ["Modo prefijo", "Mostrar / ocultar la barra lateral"],
        remote_image_paste: ["Modo prefijo", "Pegar imagen (solo con --remote)"],
        workspace_picker: ["Workspaces", "Selector de workspaces"], new_workspace: ["Workspaces", "Nuevo workspace"],
        new_worktree: ["Workspaces", "Nuevo worktree de git"], open_worktree: ["Workspaces", "Abrir un worktree"], remove_worktree: ["Workspaces", "Quitar un worktree (pide confirmación)"],
        rename_workspace: ["Workspaces", "Renombrar el workspace"], close_workspace: ["Workspaces", "Cerrar el workspace"],
        previous_workspace: ["Workspaces", "Workspace anterior"], next_workspace: ["Workspaces", "Workspace siguiente"], switch_workspace: ["Workspaces", "Ir al workspace 1–9"],
        previous_agent: ["Agentes", "Agente anterior"], next_agent: ["Agentes", "Agente siguiente"], focus_agent: ["Agentes", "Enfocar el agente 1–9"],
        new_tab: ["Pestañas", "Nueva pestaña"], rename_tab: ["Pestañas", "Renombrar la pestaña"], previous_tab: ["Pestañas", "Pestaña anterior"],
        next_tab: ["Pestañas", "Pestaña siguiente"], move_tab_previous: ["Pestañas", "Mover la pestaña hacia el frente"], move_tab_next: ["Pestañas", "Mover la pestaña hacia atrás"],
        switch_tab: ["Pestañas", "Ir a la pestaña 1–9"], close_tab: ["Pestañas", "Cerrar la pestaña"],
        rename_pane: ["Paneles", "Renombrar el panel"], edit_scrollback: ["Paneles", "Editar el historial (scrollback)"], clear_pane: ["Paneles", "Limpiar el panel"],
        focus_pane_left: ["Paneles", "Enfocar el panel de la izquierda"], focus_pane_down: ["Paneles", "Enfocar el panel de abajo"],
        focus_pane_up: ["Paneles", "Enfocar el panel de arriba"], focus_pane_right: ["Paneles", "Enfocar el panel de la derecha"],
        cycle_pane_next: ["Paneles", "Siguiente panel"], cycle_pane_previous: ["Paneles", "Panel anterior"], last_pane: ["Paneles", "Último panel"],
        split_vertical: ["Paneles", "Dividir en vertical"], split_horizontal: ["Paneles", "Dividir en horizontal"], close_pane: ["Paneles", "Cerrar el panel"],
        zoom: ["Paneles", "Ampliar el panel a pantalla completa"], resize_mode: ["Paneles", "Modo redimensionar"],
        resize_pane_left: ["Paneles", "Redimensionar a la izquierda"], resize_pane_down: ["Paneles", "Redimensionar hacia abajo"],
        resize_pane_up: ["Paneles", "Redimensionar hacia arriba"], resize_pane_right: ["Paneles", "Redimensionar a la derecha"],
        navigate_workspace_up: ["Modo navegación", "Workspace de arriba"], navigate_workspace_down: ["Modo navegación", "Workspace de abajo"],
        navigate_pane_left: ["Modo navegación", "Panel de la izquierda"], navigate_pane_down: ["Modo navegación", "Panel de abajo"],
        navigate_pane_up: ["Modo navegación", "Panel de arriba"], navigate_pane_right: ["Modo navegación", "Panel de la derecha"]
    })
    readonly property var groupOrder: ["Modo prefijo", "Workspaces", "Agentes", "Pestañas", "Paneles", "Modo navegación", "Otros"]
    readonly property var commandGroupNames: ["workspace", "tab", "pane", "agent", "worktree", "notification", "session", "machine"]

    readonly property var _notActions: ["type", "key", "command", "width", "height", "tabs", "workspaces", "agents"]
    property var _defaults: []     // [{ action, value }] in herdr's order
    property var _user: ({})       // action → value overrides

    function refresh(): void {
        if (!available) { probe.running = true; return; }
        loading = true;
        defaults.running = true;
        commands.running = true;
        userFile.reload();
        verProc.running = true;
    }

    Process {
        id: probe
        command: ["test", "-x", root.bin]
        onExited: code => { root.available = code === 0; if (root.available) root.refresh(); }
    }
    Process {
        id: verProc
        command: [root.bin, "--version"]
        stdout: StdioCollector { onStreamFinished: root.version = text.trim() }
    }

    // ---- shortcuts: the default config's [keys] section ----
    Process {
        id: defaults
        command: [root.bin, "--default-config"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                let inKeys = false;
                for (const line of text.split("\n")) {
                    if (/^\[keys\]/.test(line)) { inKeys = true; continue; }
                    if (inKeys && /^\[[a-z]/.test(line)) break;           // next real section ([server]…)
                    if (!inKeys) continue;
                    // "# name = "value"": the defaults are commented out; the examples of [[keys.command]] / [keys.indexed] are not actions
                    const m = line.match(/^#? ?([a-z_]+) = "([^"]*)"/);
                    if (m && !root._notActions.includes(m[1])) list.push({ action: m[1], value: m[2] });
                }
                root._defaults = list;
                root._rebuildKeys();
                root.loading = false;
            }
        }
    }

    // ---- the user's overrides (only uncommented lines of their [keys] section) ----
    FileView {
        id: userFile
        path: root.userConfig
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const o = {};
            let inKeys = false;
            for (const line of text().split("\n")) {
                if (/^\s*\[/.test(line)) { inKeys = /^\s*\[keys\]/.test(line); continue; }
                if (!inKeys) continue;
                const m = line.match(/^\s*([a-z_]+)\s*=\s*"([^"]*)"/);
                if (m) o[m[1]] = m[2];
            }
            root._user = o;
            root._rebuildKeys();
        }
        onLoadFailed: { root._user = ({}); root._rebuildKeys(); }
    }

    function _caps(value: string): var {
        if (!value) return [];
        const pre = root._user.prefix || root.prefix;
        return value.split("+").map(p => {
            const k = p === "prefix" ? pre : p;
            return k.split("+").map(x => x.length === 1 ? x.toUpperCase() : x.charAt(0).toUpperCase() + x.slice(1)).join("+");
        });
    }

    function _rebuildKeys(): void {
        const def = {};
        for (const d of root._defaults) def[d.action] = d.value;
        root.prefix = root._user.prefix || def.prefix || "ctrl+b";
        const groups = {};
        const add = (action) => {
            if (action === "prefix") return;
            const lab = root.labels[action] ?? ["Otros", action];
            const value = root._user[action] !== undefined ? root._user[action] : (def[action] ?? "");
            (groups[lab[0]] = groups[lab[0]] ?? []).push({
                action, text: lab[1], keys: root._caps(value), custom: root._user[action] !== undefined && root._user[action] !== (def[action] ?? ""), unbound: value === ""
            });
        };
        for (const d of root._defaults) add(d.action);
        for (const a of Object.keys(root._user)) if (def[a] === undefined) add(a);
        root.keyGroups = root.groupOrder.filter(n => groups[n]).map(n => ({ name: n, rows: groups[n] }));
    }

    // ---- commands: usage lines + descriptions straight from the binary ----
    Process {
        id: commands
        command: ["sh", "-c", `B="$1"; shift; for g in "$@"; do echo "### $g"; "$B" "$g" --help 2>/dev/null | sed -n '/^Commands:/,/^$/p' | grep '^  ' | sed 's/^  /D /'; "$B" "$g" 2>&1 | grep '^  herdr' | sed 's/^  /U /'; done`, "sh", root.bin].concat(root.commandGroupNames)
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                let cur = null, desc = {};
                for (const line of text.split("\n")) {
                    if (line.startsWith("### ")) { cur = { name: line.slice(4), rows: [] }; desc = {}; out.push(cur); }
                    else if (cur && line.startsWith("D ")) { const m = line.slice(2).match(/^(\S+)\s{2,}(.*)$/); if (m) desc[m[1]] = m[2]; }
                    else if (cur && line.startsWith("U ")) {
                        const usage = line.slice(2);
                        const sub = usage.split(/\s+/)[2] ?? "";
                        cur.rows.push({ usage, desc: desc[sub] ?? "" });
                    }
                }
                root.commandGroups = out.filter(g => g.rows.length > 0);
            }
        }
    }

    Component.onCompleted: probe.running = true
}
