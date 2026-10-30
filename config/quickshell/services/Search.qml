// =============================================================================
// dragon-island — Search.qml
// Service: what the Gravity launcher is searching for, and the actions of its results (docs/design/03-busqueda.png)
// =============================================================================
/**
 * The launcher sets `text`; the first character picks the mode:
 *   (none) apps        Apps.search (sync), real matches only (the fuzzy ones when nothing else matches)
 *   =  calc            dragon-search calc       (without it: Apps.calc)
 *   >  cmd             dragon-search cmd
 *   ?  web             dragon-search web
 *   :  emoji           dragon-search emoji
 *   @  workspace       Hyprland: workspaces 1–5 by number or by the apps on them
 *   /  clip            the clipboard ring (the launcher shows it; `results` is empty here)
 * dragon-search (Codex) lives in ~/.local/bin, called by full path with --json, 80 ms after the last key; a new key
 * replaces the running call and an answer for an older query is dropped. Missing / broken: one info row, no log noise.
 *
 * Unified result: { id, title, sub, icon, kind, action, score }
 *   kind   "app" | "calc" | "cmd" | "web" | "emoji" | "workspace" | "info" | whatever dragon-search sends
 *   action { type: "app", id } | { type: "copy", value } | { type: "open-url", value } |
 *          { type: "exec", argv: [..], terminal: bool } | { type: "workspace", id } | { type: "none" }
 *   apps also carry `appId`; `icon` is a file URL for apps, a kind name otherwise.
 *
 * Properties:
 *   - text: string                 (what the field holds, prefix included)
 *   - mode: string [readonly]      ("apps" | "calc" | "cmd" | "web" | "emoji" | "workspace" | "clip")
 *   - prefix: string [readonly]    ("" or the prefix character)
 *   - query: string [readonly]     (text without the prefix, trimmed)
 *   - modes: list<var> [readonly]  ([{ prefix, mode, label }], the «MODOS» list in its order)
 *   - results: list<var> [readonly]
 *   - busy: bool [readonly]        (a dragon-search call is pending)
 *   - engineAvailable: bool [readonly] (false once a call found dragon-search missing)
 *   - appMatches: int [readonly]   (apps mode: how many apps match)
 *
 * Functions:
 *   - run(result): bool            (does its action; true when the launcher should close)
 *   - reset(): void
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string bin: `${Quickshell.env("HOME")}/.local/bin/dragon-search`
    readonly property var modes: [
        { prefix: "=", mode: "calc",      label: "Calculadora" },
        { prefix: ">", mode: "cmd",       label: "Ejecutar comando" },
        { prefix: "?", mode: "web",       label: "Buscar en la web" },
        { prefix: ":", mode: "emoji",     label: "Emoji y símbolos" },
        { prefix: "@", mode: "workspace", label: "Ir a escritorio" },
        { prefix: "/", mode: "clip",      label: "Portapapeles" }
    ]

    property string text: ""
    readonly property string prefix: {
        const c = root.text.charAt(0);
        return root.modes.some(m => m.prefix === c) ? c : "";
    }
    readonly property string mode: root.prefix === "" ? "apps" : root.modes.find(m => m.prefix === root.prefix).mode
    readonly property string query: (root.prefix === "" ? root.text : root.text.slice(1)).trim()
    readonly property bool engineMode: ["calc", "cmd", "web", "emoji"].indexOf(root.mode) >= 0

    property var engineResults: []
    property string _engineFor: ""        // "mode\tquery" the engine results belong to
    property bool busy: false
    property bool engineAvailable: true

    // ---------------------------------------------------------------- apps / workspaces (sync)
    readonly property var appResults: {
        if (root.mode !== "apps" || root.query.length === 0) return [];
        // only real matches (the text inside the name / generic name, or a keyword that starts with it); the fuzzy
        // subsequence ones only when there is no real match at all
        const q = root.query.toLowerCase();
        const all = Apps.search(root.query);
        const strong = all.filter(e => [e.name || "", e.genericName || ""].some(t => t.toLowerCase().includes(q))
                                       || (e.keywords || []).some(k => (k || "").toLowerCase().startsWith(q)));
        return (strong.length > 0 ? strong : all).map(e => {
            const wins = (Hypr.windowsByApp[e.id] || []).length;
            const sub = [e.genericName || e.comment || "", wins > 0 ? (wins === 1 ? "1 ventana" : `${wins} ventanas`) : ""].filter(x => x).join(" · ");
            return { id: `app:${e.id}`, appId: e.id, title: e.name || e.id, sub: sub, icon: Apps.iconFor(e), kind: "app",
                     action: { type: "app", id: e.id }, score: 1 };
        });
    }
    readonly property int appMatches: appResults.length

    readonly property var workspaceResults: {
        if (root.mode !== "workspace") return [];
        const q = root.query.toLowerCase();
        return Hypr.workspaces.filter(w => {
            if (q.length === 0 || `${w.id}` === q) return true;
            return Hypr.windowsOn(w.id).some(x => (x.appClass + " " + x.title).toLowerCase().includes(q));
        }).map(w => {
            const wins = Hypr.windowsOn(w.id);
            const apps = [...new Set(wins.map(x => DesktopEntries.heuristicLookup(x.appClass)?.name || x.appClass))];
            return { id: `ws:${w.id}`, title: `Escritorio ${w.id}`, sub: wins.length === 0 ? "Vacío" : apps.join(" · "),
                     icon: "workspace", kind: "workspace", action: { type: "workspace", id: w.id }, score: w.active ? 0.5 : 1 };
        });
    }

    readonly property var results: {
        switch (root.mode) {
            case "apps": return root.appResults;
            case "workspace": return root.workspaceResults;
            case "clip": return [];
            default:
                if (root._engineFor !== `${root.mode}\t${root.query}`) return [];
                return root.engineResults;
        }
    }

    // ---------------------------------------------------------------- dragon-search
    onTextChanged: {
        if (!root.engineMode) { debounce.stop(); root.busy = false; return; }
        root.busy = true;
        debounce.restart();
    }
    Timer {
        id: debounce
        interval: Theme.searchDebounce
        onTriggered: {
            if (root.query.length === 0) { root.engineResults = []; root._engineFor = `${root.mode}\t`; root.busy = false; return; }
            engine.forKey = `${root.mode}\t${root.query}`;
            // exec() replaces a call still running (the previous query)
            engine.exec(["sh", "-c", '[ -x "$1" ] || exit 3; exec "$1" "$2" "$3" --limit 8 --json 2>/dev/null',
                         "sh", root.bin, root.mode, root.query]);
        }
    }
    Process {
        id: engine
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const key = engine.forKey;
                if (key !== `${root.mode}\t${root.query}`) return;          // an older query: drop it
                let list = [];
                try {
                    const d = JSON.parse(this.text || "{}");
                    list = Array.isArray(d.results) ? d.results.filter(r => r && typeof r.title === "string") : [];
                } catch (e) { list = []; }
                root.engineResults = list;
                root._engineFor = key;
                root.busy = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 3) { root.engineAvailable = true; return; }
            root.engineAvailable = false;
            const key = engine.forKey;
            if (key !== `${root.mode}\t${root.query}`) return;
            root.engineResults = root._fallback();
            root._engineFor = key;
            root.busy = false;
        }
    }

    // without dragon-search: the calculator still works (Apps.calc), the rest says what is missing
    function _fallback(): var {
        if (root.mode === "calc") {
            const v = Apps.calc(root.query);
            return v.length > 0 ? [{ id: "calc:fallback", title: v, sub: root.query, icon: "calc", kind: "calc", action: { type: "copy", value: v }, score: 1 }] : [];
        }
        return [{ id: "info:engine", title: "Falta dragon-search", sub: "Este modo llega con ./update.sh", icon: "info", kind: "info", action: { type: "none" }, score: 0 }];
    }

    // ---------------------------------------------------------------- actions
    function run(result): bool {
        const a = result?.action;
        if (!a) return false;
        switch (a.type) {
            case "app":
                Apps.launchById(a.id);
                Usage.record(a.id);
                return true;
            case "copy":
                if (typeof a.value !== "string") return false;
                Apps.copy(a.value);
                if (result.kind === "emoji")
                    Quickshell.execDetached(["sh", "-c", '[ -x "$1" ] && exec "$1" emoji-use "$2" >/dev/null 2>&1; exit 0', "sh", root.bin, result.id]);
                return true;
            case "open-url":
                if (typeof a.value !== "string" || !/^[a-z][a-z0-9+.-]*:/i.test(a.value)) return false;
                Quickshell.execDetached(["xdg-open", a.value]);
                return true;
            case "exec": {
                const argv = Array.isArray(a.argv) ? a.argv.filter(x => typeof x === "string") : [];
                if (argv.length === 0) return false;
                if (a.terminal)
                    Quickshell.execDetached(["ghostty", "-e", "sh", "-c", '"$@"; printf "\\nPulsa Enter para cerrar... "; read _', "sh"].concat(argv));
                else
                    Quickshell.execDetached(argv);
                return true;
            }
            case "workspace":
                Hypr.focusWorkspace(a.id);
                return true;
            default:
                return false;
        }
    }

    function reset(): void {
        debounce.stop();
        root.text = "";
        root.engineResults = [];
        root._engineFor = "";
        root.busy = false;
    }
}
