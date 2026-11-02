// Explorer in selector mode (Dragon Portal) with a simulated Files service: renders the dialogs and checks the rules of every
// kind of request (open single / multiple / folder, save, save_files, filters, choices, cancel). Fails (exit ≠ 0) when a rule breaks.
// Run by tests/portal/test_picker_ui.py (pure Theme, QML_XHR_ALLOW_FILE_READ not needed: no fixtures).
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/files"
import "../../config/quickshell/modules/files/files.js" as F

Window {
    id: win
    width: 1366
    height: 768
    visible: true
    color: Theme.bg
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    readonly property string home: "/home/oddv"
    readonly property string dir: home + "/Proyectos"
    property var results: []
    function check(cond, what) { if (!cond) throw new Error("files_picker_mock: " + what); }
    function canon(v) { return JSON.stringify(v, (k, x) => x && typeof x === "object" && typeof x.length !== "number" ? Object.keys(x).sort().reduce((o, key) => { o[key] = x[key]; return o; }, {}) : x); }
    function eq(a, b, what) { if (canon(a) !== canon(b)) throw new Error("files_picker_mock: " + what + ": «" + canon(a) + "» ≠ «" + canon(b) + "»"); }

    QtObject {
        id: fakeFiles
        property string home: win.home
        property var places: [{ id: "home", label: "Inicio", path: win.home, kind: "home" }, { id: "proyectos", label: "Proyectos", path: win.dir, kind: "project" }]
        property var clipboard: ({ mode: "", paths: [] })
        property bool composerAvailable: false
        signal folderChanged(string path)
        signal agentRequested(var paths)
        function e(name, kind, mime, extra) { return Object.assign({ name: name, kind: kind, mime: mime, size: kind === "dir" ? 0 : 20480, mtime: 1793469120, hidden: false, git: null }, extra ?? {}); }
        function list(path, opts, cb) {
            if (path !== win.dir) { cb({ ok: true, path: path, entries: [e("foto.png", "file", "image/png")], free: 499289948160, total: 1000204886016, fs: "btrfs" }); return; }
            cb({ ok: true, path: path, free: 499289948160, total: 1000204886016, fs: "btrfs", entries: [
                e("fotos", "dir", "inode/directory", { count: 12 }), e("informes", "dir", "inode/directory", { count: 3 }),
                e("foto.png", "file", "image/png"), e("logo.jpg", "file", "image/jpeg"), e("banner.PNG", "file", "image/png"),
                e("notas.txt", "file", "text/plain"), e("datos.csv", "file", "text/csv"), e("informe.pdf", "file", "application/pdf"),
                e(".oculto.png", "file", "image/png", { hidden: true }), e("-rf nota\n.txt", "file", "text/plain") ] });
        }
        function properties(path, cb) { cb({ ok: true, path: path, perms: "rw-r--r--", owner: "oddv" }); }
        function thumb(path, mtime, cb) { cb(null); }
        function open(path) { win.check(false, "a file dialog must never open files: " + path); }
        function openWith(path, app) { win.check(false, "openWith"); }
        function openWithList(path, cb) { cb({ ok: true, apps: [] }); }
        function terminalHere(path) { win.check(false, "terminalHere"); }
        function acquireWatch(p) {}
        function releaseWatch(p) {}
        function setClipboard(mode, paths) { win.check(false, "clipboard"); }
        function copyText(t) {}
        function sendToAgent(p) { win.check(false, "agent"); }
        function refreshShares() {}
    }
    QtObject {
        id: fakeOps
        property var calls: []
        property bool canUndo: false
        property string undoLabel: ""
        readonly property var active: null
        readonly property int pending: 0
        function mkdir(d, n) { calls = calls.concat([["mkdir", d, n]]); }
        function trash(p) { win.check(false, "trash in a file dialog"); }
        function remove(p) { win.check(false, "delete in a file dialog"); }
        function rename(p, n) { win.check(false, "rename in a file dialog"); }
        function copy(p, d) { win.check(false, "copy"); }
        function move(p, d) { win.check(false, "move"); }
        function undo() { win.check(false, "undo"); }
        function dismissError() {}
    }
    QtObject {
        id: fakeDevs
        property var devices: []
        property var busy: ({})
        property var errors: ({})
        property var hosts: []
        property var netMounts: []
        property var servers: []
        property bool discovering: false
        property string netStatus: "ok"
        property string netMessage: ""
        property var netBusy: ({})
        property var netErrors: ({})
        function deviceById(id) { return null; }
        function discover() {}
        function mountFor(h) { return null; }
        function hostState(h) { return "available"; }
    }

    property var panel: null
    Component {
        id: panelComponent
        FilesPanel {
            x: 71
            y: 47
            width: Theme.files.width
            height: Theme.files.height
            files: fakeFiles
            ops: fakeOps
            devices: fakeDevs
            archives: null
            initialPath: win.dir
            onPickerResult: r => win.results = win.results.concat([r])
        }
    }
    function open(request) {
        if (panel) panel.destroy();
        const base = { id: "0".repeat(32), kind: "open", title: "Elige un archivo", accept_label: "", multiple: false, directory: false, save_folder: false,
                       filters: [], current_filter: -1, choices: [], current_folder: win.dir, current_name: "", files: [] };
        panel = panelComponent.createObject(win, { picker: Object.assign(base, request) });
    }
    function shot(name) { panel.grabToImage(r => r.saveToFile(win.outDir + "/" + name)); }
    function names() { return panel.tab.shown.map(e => e.name); }
    function pick(name, mods) { panel.tab.select(panel.tab.shown.findIndex(e => e.name === name), mods ?? 0); }

    readonly property var imageFilter: ({ name: "Imágenes", patterns: [{ type: "glob", value: "*.png" }, { type: "mime", value: "image/*" }] })
    readonly property var textFilter: ({ name: "Texto", patterns: [{ type: "mime", value: "text/plain" }, { type: "glob", value: "*.csv" }] })

    Timer {
        interval: 350
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            try { run(); } catch (e) { console.error(e.message); running = false; Qt.exit(1); }
        }
        function run() {
            const p = win.panel;
            if (step === 0) win.open({ title: "Adjuntar imagen", multiple: false, filters: [win.imageFilter, win.textFilter], current_filter: 0 });
            if (step === 1) {
                const t = win.panel.tab;
                win.eq(win.names(), ["fotos", "informes", "banner.PNG", "foto.png", "logo.jpg"], "image filter keeps folders and image files, hides the rest");
                win.check(!win.panel.pickResolved.ok, "nothing selected: cannot accept");
                win.pick("fotos");
                win.eq(t.selection.length, 0, "a folder cannot be selected when asking for files");
                win.pick("foto.png");
                win.pick("logo.jpg", Qt.ControlModifier);
                win.eq(t.selection.map(e => e.name), ["logo.jpg"], "single selection ignores Ctrl");
                win.pick("foto.png"); win.pick("logo.jpg", Qt.ShiftModifier);
                win.eq(t.selection.length, 1, "single selection ignores Shift");
                t.selectAll(); win.eq(t.selection.length, 1, "select all is blocked");
                win.shot("picker-abrir.png");
            }
            if (step === 2) {
                win.panel.runAction("filter:1", null);
                                win.check(win.names().indexOf("foto.png") < 0 && win.names().indexOf("notas.txt") >= 0, "text filter shows text, hides images");
                win.panel.runAction("filter:0", null);
                win.pick("foto.png");
                win.panel.acceptPick();
                win.eq(win.results[0], { response: "accept", paths: [win.dir + "/foto.png"], filter: 0, choices: {} }, "accept result");
            }
            if (step === 3) win.open({ title: "Adjuntos", multiple: true });
            if (step === 4) {
                const t = win.panel.tab;
                win.pick("notas.txt"); win.pick("datos.csv", Qt.ControlModifier);
                win.eq(t.selection.length, 2, "multiple: Ctrl adds");
                t.selectAll(); win.eq(t.selection.length, 7, "multiple: select all picks the files, not the folders");
                win.check(win.panel.pickResolved.ok && win.panel.pickResolved.paths.length === 7, "multiple resolves every file");
                win.eq(win.panel.pickResolved.paths[0], win.dir + "/-rf nota\n.txt", "paths are folder + name, odd names intact (sorted by name)");
                win.shot("picker-varios.png");
                win.panel.state.showHidden = true;
                win.check(win.names().indexOf(".oculto.png") >= 0, "hidden files can be shown");
            }
            if (step === 5) win.open({ title: "Carpeta del proyecto", directory: true });
            if (step === 6) {
                const t = win.panel.tab;
                win.pick("foto.png");
                win.eq(t.selection.length, 0, "folder mode: a file cannot be selected");
                win.check(win.panel.pickResolved.ok, "folder mode: no selection = this folder");
                win.eq(win.panel.pickResolved.paths, [win.dir], "…and it is the folder being shown");
                win.pick("fotos");
                win.eq(win.panel.pickResolved.paths, [win.dir + "/fotos"], "folder mode: the selected folder");
                win.eq(F.pickerAcceptLabel(win.panel.picker), "Elegir", "folder label");
                win.shot("picker-carpeta.png");
            }
            if (step === 7) win.open({ kind: "save", title: "Guardar como", current_name: "informe.pdf", accept_label: "Exportar", filters: [win.textFilter], current_filter: 0 });
            if (step === 8) {
                const t = win.panel.tab;
                win.eq(win.panel.state.pickName, "informe.pdf", "proposed name");
                win.check(win.panel.pickResolved.ok, "a valid name resolves");
                win.eq(win.panel.pickResolved.paths, [win.dir + "/informe.pdf"], "folder + name");
                win.panel.acceptPick();
            }
            if (step === 9) {
                win.check(win.results.length === 1, "existing file: nothing is sent before confirming");
                win.shot("picker-reemplazar.png");
            }
            if (step === 10) {
                let pr = null; for (const c of win.panel.children) if (c.purpose !== undefined) pr = c;
                win.check(pr && pr.visible, "overwrite question is visible");
                pr.reply("cancel");
                win.check(win.results.length === 1, "cancelling the question sends nothing");
                win.panel.state.pickName = "nuevo.txt";
                win.eq(win.panel.pickResolved.paths, [win.dir + "/nuevo.txt"], "typed name");
                win.panel.acceptPick();
                win.eq(win.results[1].paths, [win.dir + "/nuevo.txt"], "new name is accepted without asking");
                win.pick("notas.txt");
                win.eq(win.panel.state.pickName, "notas.txt", "clicking a file copies its name");
                win.panel.state.pickName = "a/b";
                win.check(!win.panel.pickResolved.ok, "a name with a slash is refused");
                win.panel.state.pickName = "..";
                win.check(!win.panel.pickResolved.ok, "«..» is refused");
                win.panel.state.pickName = "fotos";
                win.panel.acceptPick();
                win.eq(win.results.length, 2, "a folder with that name is refused");
                win.eq(win.panel.pickHint, "Ya hay una carpeta con ese nombre", "…with a message");
                win.panel.state.pickName = "-rf mi\narchivo.txt";
                win.eq(win.panel.pickResolved.paths, [win.dir + "/-rf mi\narchivo.txt"], "odd names are kept byte for byte");
                win.panel.state.pickName = "informe.pdf";
            }
            if (step === 11) win.shot("picker-guardar.png");
            if (step === 12) win.open({ kind: "save_files", title: "Guardar 3 imágenes", save_folder: true, files: ["a.png", "b.png", "c.png"],
                                        choices: [{ id: "q", label: "Calidad", options: [{ id: "lo", label: "Baja" }, { id: "hi", label: "Alta" }], selected: "lo" }] });
            if (step === 13) {
                const t = win.panel.tab;
                win.pick("foto.png");
                win.eq(t.selection.length, 0, "save_files: only folders are selectable");
                win.eq(win.panel.pickResolved.paths, [win.dir], "save_files: this folder");
                win.eq(F.pickerSummary(win.panel.picker, [], win.dir, ""), "3 archivos se guardarán en Proyectos", "summary");
                win.panel.runAction("choice:q:hi", null);
                win.panel.acceptPick();
                win.eq(win.results[2], { response: "accept", paths: [win.dir], filter: null, choices: { q: "hi" } }, "save_files result with choices");
                win.shot("picker-guardar-varios.png");
            }
            if (step === 14) win.open({ title: "Cancelar" });
            if (step === 15) {
                win.panel.cancelPick();
                win.eq(win.results[3], { response: "cancel" }, "cancel result");
                // destructive actions are ignored in a file dialog (the fake services fail the check if they are called)
                win.pick("foto.png");
                win.panel.runAction("trash", null); win.panel.runAction("delete", null); win.panel.runAction("rename", null);
                win.panel.runAction("cut", null); win.panel.runAction("open", win.panel.tab.focusEntry); win.panel.runAction("terminal", null);
                win.panel.dropInto(win.dir + "/fotos", [win.dir + "/foto.png"], 0);
                win.panel.runAction("mkdir", null);
            }
            if (step === 16) { win.check(win.results.length === 4, "no extra answers"); Qt.exit(0); }
            step++;
        }
    }
}
