// Local Git data only; watch runs exclusively while active and a project repo is selected.
// status/message/actionError/busy; repo/snapshot/diffData/history/branches/secrets; selectedPath/staged.
// activate(value,path), refresh(), select(path,staged), stage(path,value), commit(message,push),
// pull(), push(), checkout(branch), stash(operation), lazygit(). No generated commit message.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-git`
    property bool active: false
    property string repo: ""
    property string status: "unavailable"
    property string message: "Selecciona un proyecto"
    property string actionError: ""
    property bool busy: false
    property var snapshot: ({staged:[], changes:[], untracked:[], conflicts:[]})
    property var diffData: ({hunks:[]})
    property var history: []
    property var branches: []
    property var secrets: []
    property bool secretsChecked: false
    property string selectedPath: ""
    property bool staged: false
    property int _generation: 0
    property bool _refreshing: false
    property bool _pending: false
    readonly property int changeCount: (snapshot.staged?.length ?? 0) + (snapshot.changes?.length ?? 0) + (snapshot.untracked?.length ?? 0)
    Component { id: request; ToolRequest {} }
    function argv(args, path): var { return ["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', tool].concat(args).concat(["--repo",path || repo,"--json"]); }
    function call(args, callback): void {
        const generation = _generation;
        const p = request.createObject(root, {callback: r => {
            if (generation !== _generation) return;
            if (!r.ok) { status = r.error?.code === "missing_tool" ? "unavailable" : "error"; message = r.error?.message ?? "Error de Git"; }
            if (callback) callback(r);
        }});
        p.exec(argv(args));
    }
    function activate(value, path): void {
        if (active === value && repo === path) return;
        watch.running = false; _generation++; _refreshing = false; _pending = false; busy = false;
        const changed = repo !== path; repo = path; active = value;
        if (changed) { snapshot = {staged:[],changes:[],untracked:[],conflicts:[]}; diffData = {hunks:[]}; selectedPath = ""; history = []; branches = []; secrets = []; secretsChecked = false; actionError = ""; }
        if (active && repo) { status = "loading"; refresh(); watch.exec(argv(["watch"])); }
        else if (!repo) { status = "unavailable"; message = "Selecciona un proyecto"; }
    }
    function refresh(): void {
        if (!active || !repo) return;
        if (_refreshing) { _pending = true; return; }
        _refreshing = true; secretsChecked = false;
        call(["status"], r => {
            _refreshing = false;
            if (r.ok) {
                snapshot = r; status = "ok"; message = "";
                const files = (r.staged ?? []).concat(r.changes ?? []).concat(r.untracked ?? []);
                if (!files.some(f => f.path === selectedPath)) select(files[0]?.path ?? "", (r.staged ?? []).some(f => f.path === files[0]?.path));
                else select(selectedPath, staged && (r.staged ?? []).some(f => f.path === selectedPath));
                call(["log", "-n", "30"], value => { if (value.ok) history = value.log ?? []; });
                call(["branches"], value => { if (value.ok) branches = value.branches ?? []; });
                call(["check-secrets"], value => { if (value.ok) { secrets = value.secrets ?? []; secretsChecked = true; } });
            }
            if (_pending) { _pending = false; refresh(); }
        });
    }
    function select(path, prepared): void {
        selectedPath = path; staged = prepared; diffData = {hunks:[]};
        if (!active || !path) return;
        call(["diff","--path",path].concat(prepared ? ["--staged"] : []), r => { if (r.ok && selectedPath === path && staged === prepared) diffData = r; });
    }
    function mutate(args, callback): void {
        if (busy || !active || !repo) return;
        busy = true; actionError = "";
        call(args, r => {
            busy = false;
            actionError = !r.ok ? (r.error?.message ?? "Error de Git") + (r.error?.files ? " · " + r.error.files.map(f => `${f.path}:${f.line} (${f.type})`).join(", ") : "") : (r.warnings ?? []).join(" · ");
            if (callback) callback(r);
            refresh();
        });
    }
    function stage(path, value): void { mutate([value ? "stage" : "unstage", "--paths", path]); }
    function commit(message, push): void { if (message.trim()) mutate(["commit","-m",message].concat(push ? ["--push"] : [])); }
    function pull(): void { mutate(["pull","--ff-only"]); }
    function push(): void { mutate(["push"]); }
    function checkout(branch): void { mutate(["checkout",branch]); }
    function stash(operation): void { mutate(["stash", operation]); }
    function lazygit(): void {
        if (!repo) return;
        const path = repo;
        const p = request.createObject(root, {callback: r => {
            if (r.ok) Quickshell.execDetached(["ghostty", "--working-directory=" + path, "-e", "lazygit"]);
            else actionError = "lazygit no disponible: instala lazygit y Ghostty";
        }});
        p.exec(["sh","-c",'if command -v lazygit >/dev/null && command -v ghostty >/dev/null; then echo \'{"ok":true}\'; else echo \'{"ok":false}\'; fi']);
    }
    Timer { id: debounce; interval: 300; onTriggered: root.refresh() }
    Timer { interval: 2000; running: root.active && !!root.repo && !watch.running; repeat: true; onTriggered: { root.refresh(); watch.exec(root.argv(["watch"])); } }
    Process {
        id: watch
        stdout: SplitParser { onRead: line => { if (root.active) debounce.restart(); } }
    }
}
