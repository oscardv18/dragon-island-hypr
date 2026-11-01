// Project memory, data only. Calls dragon-mem on demand; no polling while the Taller is closed.
// status/message: ok|loading|unavailable|error; projects/cards: SQLite rows; selectedSlug/project: current project.
// refresh(), selectProject(slug), addProject(path,name,prefix,callback), logChange(key,old,new,source), call(args,callback).
// Callbacks receive the stable JSON result, including errors; no CLI output is interpreted as markup.
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
    signal changed()

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
    function call(args, callback): void {
        const p = requestComponent.createObject(root, { callback: callback ?? null });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', root.tool].concat(args).concat(["--json"]));
    }
    function callHerdr(args, callback): void {
        const p = requestComponent.createObject(root, { callback: callback ?? null, reportStatus: false });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', `${Quickshell.env("HOME")}/.local/bin/dragon-herdr`].concat(args).concat(["--json"]));
    }
    function refresh(): void {
        if (_refreshing) return;
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
        });
    }
    function refreshCards(): void {
        if (!selectedSlug) { cards = []; return; }
        const slug = selectedSlug;
        call(["card", "list", "--project", slug], r => { if (r.ok && slug === selectedSlug) cards = r.cards ?? []; });
    }
    function selectProject(slug): void { selectedSlug = slug; refreshCards(); }
    function addProject(path, name, prefix, callback): void {
        const args = ["project", "add", "--path", path];
        if (name) args.push("--name", name);
        if (prefix) args.push("--prefix", prefix);
        call(args, r => { if (r.ok) { selectedSlug = r.project.slug; refresh(); changed(); } if (callback) callback(r); });
    }
    function logChange(key, oldValue, newValue, source): void {
        if (JSON.stringify(oldValue) === JSON.stringify(newValue)) return;
        call(["system", "log", "add", "--key", key, "--old", JSON.stringify(oldValue), "--new", JSON.stringify(newValue), "--source", source || "settings"], r => { if (r.ok) changed(); });
    }
}
