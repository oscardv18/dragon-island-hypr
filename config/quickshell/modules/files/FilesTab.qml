// One explorer tab: its folder, history, listing and selection. Pure state; it reads the folder through the injected
// Files service (`service.list`) and never runs anything itself.
import QtQuick
import "files.js" as F

QtObject {
    id: tab
    property var service: null
    property var view: null                // FilesState: sort, hidden files, search
    property string path: ""
    property var history: []
    property int historyIndex: -1
    property var entries: []
    property string status: "loading"      // loading | ok | error
    property string error: ""
    property string errorHint: ""
    property real free: -1
    property real total: -1
    property string fs: ""
    property var selected: ({})            // name → true
    property int currentIndex: -1
    property int anchorIndex: -1
    property int generation: 0
    property bool watching: false
    readonly property string title: F.basename(path)
    readonly property bool special: F.isSpecial(path)
    readonly property bool isNet: path === F.NET
    readonly property var shown: F.sortEntries(F.filterEntries(entries, view?.search ?? "", view?.showHidden ?? false),
                                               view?.sortKey ?? "name", view?.sortDesc ?? false, view?.dirsFirst ?? true)
    readonly property var selection: shown.filter(e => selected[e.name])
    readonly property var current: currentIndex >= 0 && currentIndex < shown.length ? shown[currentIndex] : null
    readonly property var focusEntry: selection.length === 1 ? selection[0] : (selection.length ? null : current)
    readonly property bool canBack: historyIndex > 0
    readonly property bool canForward: historyIndex < history.length - 1
    readonly property bool canUp: F.parent(path) !== ""

    function go(p, keepHistory): void {
        if (!p) return;
        if (!keepHistory) {
            history = history.slice(0, historyIndex + 1).concat([p]);
            historyIndex = history.length - 1;
        }
        const old = path;
        path = p;
        selected = ({});
        entries = [];
        currentIndex = -1;
        anchorIndex = -1;
        if (view) view.search = "";
        if (old !== p) _swapWatch(old, p);
        reload();
    }
    function back(): void { if (canBack) { historyIndex--; go(history[historyIndex], true); } }
    function forward(): void { if (canForward) { historyIndex++; go(history[historyIndex], true); } }
    function up(): void { if (canUp) { _pendingSelect = F.basename(path); go(F.parent(path)); } }
    property string _pendingSelect: ""

    function reload(): void {
        if (isNet) { status = "ok"; entries = []; error = ""; return; }
        const gen = ++generation;
        const p = path;
        if (!entries.length) status = "loading";
        service?.list(p, { hidden: true }, r => {
            if (gen !== generation) return;
            if (!r.ok) { status = "error"; error = r.error?.message ?? "No se pudo leer la carpeta"; errorHint = r.error?.hint ?? ""; entries = []; free = -1; total = -1; return; }
            _apply(r);
            // second, slower pass: git marks (one `dragon-git status` per repo inside the tool)
            service?.list(p, { hidden: true, git: true }, g => {
                if (gen === generation && g.ok && g.entries?.some(e => e.git)) _apply(g);
            });
        });
    }
    function _apply(r): void {
        const keep = selected, names = {};
        for (const e of r.entries ?? []) names[e.name] = true;
        const sel = {};
        for (const k in keep) if (names[k]) sel[k] = true;
        const cur = current?.name;
        entries = r.entries ?? [];
        free = r.free ?? -1; total = r.total ?? -1; fs = r.fs ?? "";
        status = "ok"; error = ""; errorHint = "";
        selected = sel;
        const want = _pendingSelect || cur;
        _pendingSelect = "";
        if (want) { const i = shown.findIndex(e => e.name === want); if (i >= 0) currentIndex = i; }
        if (currentIndex >= shown.length) currentIndex = shown.length - 1;
    }

    // ---- selection ----
    // mods: Qt.ControlModifier toggles, Qt.ShiftModifier extends from the anchor
    function select(i, mods): void {
        if (i < 0 || i >= shown.length) return;
        const name = shown[i].name;
        if (mods & Qt.ShiftModifier && anchorIndex >= 0) {
            const s = (mods & Qt.ControlModifier) ? Object.assign({}, selected) : {};
            const a = Math.min(anchorIndex, i), b = Math.max(anchorIndex, i);
            for (let k = a; k <= b; k++) s[shown[k].name] = true;
            selected = s;
        } else if (mods & Qt.ControlModifier) {
            const s = Object.assign({}, selected);
            if (s[name]) delete s[name]; else s[name] = true;
            selected = s;
            anchorIndex = i;
        } else {
            const s = {}; s[name] = true;
            selected = s;
            anchorIndex = i;
        }
        currentIndex = i;
    }
    function selectNames(names): void {
        const s = {};
        for (const n of names) s[n] = true;
        selected = s;
        const i = shown.findIndex(e => s[e.name]);
        if (i >= 0) { currentIndex = i; anchorIndex = i; }
    }
    function selectAll(): void { const s = {}; for (const e of shown) s[e.name] = true; selected = s; }
    function clearSelection(): void { selected = ({}); }
    function move(delta, mods): void {
        if (!shown.length) return;
        const i = Math.max(0, Math.min(shown.length - 1, (currentIndex < 0 ? (delta > 0 ? -1 : shown.length) : currentIndex) + delta));
        select(i, mods & Qt.ShiftModifier ? Qt.ShiftModifier : 0);
    }
    function pathOf(e): string { return F.join(path, e.name); }
    function selectedPaths(): var { return (selection.length ? selection : (current ? [current] : [])).map(e => pathOf(e)); }

    // ---- watching: only the visible tab of a visible window holds a watcher ----
    function setWatching(on): void {
        if (on === watching) return;
        watching = on;
        if (!service || special || !path) return;
        if (on) service.acquireWatch(path); else service.releaseWatch(path);
    }
    function _swapWatch(old, p): void {
        if (!watching || !service) return;
        if (old && !F.isSpecial(old)) service.releaseWatch(old);
        if (p && !F.isSpecial(p)) service.acquireWatch(p);
    }
    property Connections _changes: Connections {
        target: tab.service
        ignoreUnknownSignals: true
        function onFolderChanged(p) { if (p === tab.path) tab.reload(); }
    }
}
