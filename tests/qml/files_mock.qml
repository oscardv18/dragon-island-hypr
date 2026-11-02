// Pure explorer view with simulated services fed by tests/qml/fixtures/files-*.json (the dragon-files contract,
// PLAN-FASE-5 §5.7). No processes, no real folders. render-mocks.sh supplies a pure Theme and allows the fixture reads
// (QML_XHR_ALLOW_FILE_READ=1). Fails (exit ≠ 0) when a helper of files.js or a view state is wrong.
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
    readonly property real fixedNow: 1793469120 * 1000          // 2026-10-31 17:52 UTC, the fixtures' «now»
    readonly property string home: "/home/oddv"
    readonly property string docs: home + "/Proyectos/arxnet-erp/docs"

    function fixture(name) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("fixtures/" + name), false);
        xhr.send();
        if (!xhr.responseText) throw new Error("fixture missing: " + name);
        return JSON.parse(xhr.responseText);
    }
    function check(cond, what) { if (!cond) throw new Error("files_mock: " + what); }
    function eq(a, b, what) { if (a !== b) throw new Error("files_mock: " + what + ": «" + a + "» ≠ «" + b + "»"); }

    // ---- simulated Files service: same members the views use ----
    QtObject {
        id: files
        property string home: win.home
        property var places: win.fixture("files-places.json").places
        property var clipboard: ({ mode: "", paths: [] })
        property bool composerAvailable: false
        property var opened: []
        property var watched: ({})
        readonly property var listings: ({})
        signal folderChanged(string path)
        signal agentRequested(var paths)
        function list(path, opts, cb) {
            const map = { [win.docs]: "files-ls-docs.json", [win.home + "/Descargas"]: "files-ls-descargas.json" };
            if (map[path]) { const r = win.fixture(map[path]); if (!opts?.git) for (const e of r.entries) e.git = null; cb(r); }
            else if (path === "/sin-herramienta") cb({ ok: false, error: { code: "missing_tool", message: "dragon-files no está instalado", hint: "Ejecuta ./update.sh" } });
            else if (path === "trash:///") cb({ ok: true, path: path, entries: [{ name: "viejo.txt", kind: "file", size: 120, mtime: 1793469120 - 86400, mime: "text/plain", hidden: false, uri: "trash:///viejo.txt" }], free: -1, total: -1 });
            else if (path === win.home + "/privado") cb({ ok: false, error: { code: "permission_denied", message: "No tienes permiso para abrir «privado»", hint: "Pide acceso al propietario o ábrela como administrador" } });
            else cb({ ok: true, path: path, entries: [], free: 499289948160, total: 1000204886016, fs: "btrfs" });
        }
        function properties(path, cb) {
            if (path.endsWith("foto-evento.jpg")) cb(win.fixture("files-props-foto.json"));
            else if (path === win.docs) cb(win.fixture("files-props-docs.json"));
            else cb({ ok: true, path: path, perms: "rw-r--r--", owner: "oddv" });
        }
        function openWithList(path, cb) { cb({ ok: true, apps: [{ id: "org.gnome.Loupe.desktop", name: "Imágenes", default: true }, { id: "gimp.desktop", name: "GIMP" }] }); }
        function openWith(path, app) { opened = opened.concat([app + ":" + path]); }
        function terminalHere(path) { opened = opened.concat(["term:" + path]); }
        function thumb(path, mtime, cb) { cb(path.endsWith(".jpg") || path.endsWith(".svg") ? Qt.resolvedUrl("../../sddm/dragon-core/background.jpg").toString().replace("file://", "") : null); }
        function open(path) { opened = opened.concat([path]); }
        function acquireWatch(p) { const w = Object.assign({}, watched); w[p] = (w[p] ?? 0) + 1; watched = w; }
        function releaseWatch(p) { const w = Object.assign({}, watched); w[p]--; if (!w[p]) delete w[p]; watched = w; }
        property var shares: [{ path: win.home + "/Proyectos/arxnet-erp", name: "arxnet-erp", rw: false, guest: false }]
        property var shareCalls: []
        function refreshShares() {}
        function shareStatus(p, cb) { cb(p === win.home ? win.fixture("files-share-forbidden.json") : win.fixture("files-share-status.json")); }
        function shareEnable(p, n, rw, g, cb) { shareCalls = shareCalls.concat([["enable", p, n, rw, g]]); cb(p === win.home ? win.fixture("files-share-forbidden.json") : { ok: true, addresses: { smb: "smb://dragonos/" + n, unc: "\\\\dragonos\\" + n } }); }
        function shareDisable(p, n, cb) { shareCalls = shareCalls.concat([["disable", p, n]]); cb({ ok: true }); }
        function setClipboard(mode, paths) { clipboard = { mode: mode, paths: paths }; }
        function copyText(t) {}
        function sendToAgent(p) {}
    }

    // ---- simulated FileOps: records calls, shows the fixture's progress / conflict events ----
    QtObject {
        id: ops
        property var queue: []
        property var calls: []
        property var lastError: null
        property bool canUndo: false
        property string undoLabel: ""
        readonly property var active: queue[0] ?? null
        readonly property int pending: queue.length
        function _rec(kind, a, b) { calls = calls.concat([[kind, a, b]]); }
        function copy(p, d) { _rec("copy", p, d); }
        function move(p, d) { _rec("move", p, d); }
        function trash(p) { _rec("trash", p); }
        function remove(p) { _rec("delete", p); }
        function rename(p, n) { _rec("rename", p, n); }
        function mkdir(d, n) { _rec("mkdir", d, n); }
        function answer(id, c, all) { _rec("answer", c, all); queue = queue.map(o => Object.assign({}, o, { state: "running", conflict: null })); }
        function cancel(id) { _rec("cancel", id); queue = []; }
        function dismissError() { lastError = null; }
        function undo() { _rec("undo"); }
        function restore(u) { _rec("restore", u); }
        function emptyTrash() { _rec("emptyTrash"); }
        function feed(ev) {
            const base = queue[0] ?? { id: 1, kind: "copy", dest: "/run/media/oddv/KINGSTON/fotos", count: 5, state: "running" };
            if (ev.t === "progress") queue = [Object.assign({}, base, { pct: ev.pct, file: ev.file, index: ev.index, count: ev.count, state: "running" })];
            if (ev.t === "conflict") queue = [Object.assign({}, base, { state: "conflict", conflict: { file: ev.file, dest: ev.dest } })];
        }
    }
    // ---- simulated Devices ----
    QtObject {
        id: devs
        property var devices: win.fixture("files-devices.json").devices.filter(d => !d.hidden)
        property var busy: ({})
        property var errors: ({})
        property var calls: []
        function deviceById(id) { return devices.find(d => d.id === id) ?? null; }
        property var hosts: []
        property var netMounts: win.fixture("files-net-mounts.json").mounts
        property var servers: win.fixture("files-net-saved.json").servers
        property bool discovering: true
        property string netStatus: "ok"
        property string netMessage: ""
        property var netBusy: ({})
        property var netErrors: ({})
        function discover() { hosts = win.fixture("files-net-discover.json").hosts; }
        function mountFor(h) { return netMounts.find(m => m.host === h.name || m.address === h.address) ?? null; }
        function hostState(h) {
            if (h.protocol === "ipp") return "printer";
            if (mountFor(h)) return "connected";
            if (servers.some(s => s.uri.indexOf("//" + h.address) >= 0 && h.name === "vps-prod")) return "saved";
            return "available";
        }
        function shares(host, cb) { cb(win.fixture("files-net-shares-" + host + ".json")); }
        function connect(uri, user, pass, save, cb) {
            calls = calls.concat([["connect", uri, user ?? "", (pass ?? "").length, !!save]]);
            if (!pass) { netErrors = { [uri]: { code: "auth_required", message: "El servidor pide usuario y contraseña" } }; cb({ ok: false, error: netErrors[uri] }); }
            else { netErrors = ({}); cb({ ok: true, mountpoint: "/run/user/1000/gvfs/x" }); }
        }
        function unmountNet(uri) { calls = calls.concat([["unmountNet", uri]]); }
        function saveServer(uri, name) { calls = calls.concat([["save", uri, name]]); }
        function mount(id, cb) { calls = calls.concat([["mount", id]]); }
        function unmount(id) { calls = calls.concat([["unmount", id]]); }
        function eject(id) { calls = calls.concat([["eject", id]]); }
        function unlock(id, pass, cb) {
            calls = calls.concat([["unlock", id, pass.length]]);
            if (pass !== "correcta") { errors = { [id]: "Contraseña incorrecta" }; cb({ ok: false, error: { code: "bad_passphrase", message: "Contraseña incorrecta" } }); }
        }
    }
    // ---- simulated Archives ----
    QtObject {
        id: arch
        readonly property var formats: ["ZIP", "7Z", "RAR", "TAR.GZ", "TAR.XZ", "TAR.ZST", "TAR.BZ2", "ISO", "DEB", "RPM", "APPIMAGE", "CAB", "LHA"]
        property var cache: ({})
        property var tests: ({})
        property var calls: []
        function loading(p) { return false; }
        function info(p, cb) {
            if (!cache[p]) { const c = Object.assign({}, cache); c[p] = p.endsWith("backup-2026-10.zip") ? win.fixture("files-archive-backup.json") : { error: { message: "No es un archivo comprimido válido" } }; cache = c; }
            if (cb) cb(cache[p]);
        }
        function test(p, cb) { const t = Object.assign({}, tests); t[p] = "ok"; tests = t; }
        function extract(p, dest, o, cb) {
            calls = calls.concat([["extract", p, dest, o]]);
            ops.queue = [{ id: 9, kind: "extract", dest: dest, count: 1, state: "running", pct: 64, file: "src/facturas/filtros.ts", bps: 88080384 }];
            if (!o.password && p.endsWith(".7z")) cb({ ok: false, error: { code: "password_required", message: "El archivo está cifrado" } });
            return 9;
        }
        function create(fmt, out, paths) { calls = calls.concat([["create", fmt, out, paths]]); return 10; }
    }
    function opEvents() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("fixtures/files-op-progress.jsonl"), false); xhr.send();
        return xhr.responseText.trim().split("\n").map(l => JSON.parse(l));
    }

    FilesPanel {
        id: panel
        x: 71
        y: 47
        width: Theme.files.width
        height: Theme.files.height
        files: files
        ops: ops
        devices: devs
        archives: arch
        initialPath: win.docs
        now: win.fixedNow
    }

    function unitChecks() {
        eq(F.formatSize(48.2 * 1048576), "48,2 MB", "formatSize MB");
        eq(F.formatSize(312 * 1048576), "312 MB", "formatSize ≥100");
        eq(F.formatSize(18 * 1024), "18 KB", "formatSize KB");
        eq(F.formatSize(499289948160), "465 GB", "formatSize GB");
        eq(F.formatCapacity(1000204886016), "1 TB", "formatCapacity TB");
        eq(F.formatCapacity(32015679488), "32 GB", "formatCapacity GB");
        eq(F.typeLabel({ name: "datos.tar.zst", kind: "file" }), "tar + zstd", "typeLabel compound");
        eq(F.typeLabel({ name: "x", kind: "dir" }), "Carpeta", "typeLabel dir");
        eq(F.archiveStem("release-2.4.tar.gz"), "release-2.4", "archiveStem");
        eq(F.extractDest(win.docs + "/backup-2026-10.zip", true), win.docs + "/backup-2026-10/", "extractDest own folder");
        eq(F.displayPath(win.docs, win.home), "~/Proyectos/arxnet-erp/docs", "displayPath");
        eq(F.expandPath("~/a/../b/./c", win.home, "/"), win.home + "/b/c", "expandPath");
        eq(F.expandPath("sub", win.home, "/tmp"), "/tmp/sub", "expandPath relative");
        eq(F.crumbs(win.docs, win.home).map(c => c.label).join(" › "), "~ › Proyectos › arxnet-erp › docs", "crumbs");
        eq(F.parent("/"), "", "parent of root");
        eq(F.parent("/a"), "/", "parent of top");
        const day = 86400;
        eq(F.relTime(1793469120 - day, win.fixedNow), "ayer", "relTime ayer");
        eq(F.relTime(1793469120 - 3 * day, win.fixedNow), "hace 3 d", "relTime días");
        eq(F.relTime(1793469120 - 15 * day, win.fixedNow), "hace 2 sem", "relTime semanas");
        const s = F.sortEntries([{ name: "b", kind: "file", size: 1 }, { name: "a10", kind: "file", size: 9 }, { name: "a9", kind: "file", size: 5 }, { name: "z", kind: "dir" }], "name", false, true);
        eq(s.map(e => e.name).join(","), "z,a9,a10,b", "natural sort, folders first");
        eq(F.sortEntries(s, "size", true, false).map(e => e.name).join(","), "a10,a9,b,z", "size sort desc");
        eq(F.filterEntries([{ name: ".x", hidden: true }, { name: "Foto" }], "fo", false).length, 1, "filter + hidden");
        eq(F.selectionSummary([{ kind: "file", size: 48.2 * 1048576 }], 12), "1 de 12 elementos seleccionado · 48,2 MB", "selection summary");
        const tree = F.archiveTree([{ path: "src/a.ts", size: 1 }, { path: "src/b/c.ts", size: 1 }, { path: "docs/", is_dir: true },
                                    { path: "docs/x.md", size: 1 }, { path: "README.md", size: 4096 }], 5);
        eq(tree.lines.map(l => l.label + "=" + l.value).join(" "), "docs/=1 src/=2 README.md=4 KB", "archiveTree");
        const devs = [{ id: "root", mounted: true, mountpoint: "/" }, { id: "usb", label: "KINGSTON", mounted: true, mountpoint: "/run/media/oddv/KINGSTON" }];
        eq(F.deviceForPath(devs, "/run/media/oddv/KINGSTON/x").id, "usb", "deviceForPath");
        check(!F.sameDevice(devs, win.home, "/run/media/oddv/KINGSTON"), "sameDevice");
        eq(F.opLabel({ kind: "copy", dest: "/run/media/oddv/KINGSTON/fotos", index: 2, count: 5 }, devs), "COPIANDO A KINGSTON · 2/5", "opLabel");
    }

    function dialog(type, from) {
        // depth-first search: dialogs are direct children, NetView sits inside the content area
        const stack = [from ?? panel];
        while (stack.length) {
            const it = stack.shift();
            for (const c of it.children ?? []) { if (String(c).indexOf(type) === 0) return c; stack.push(c); }
        }
        throw new Error("no " + type);
    }
    function prompt() { for (const c of panel.children) if (c.purpose !== undefined) return c; throw new Error("no prompt"); }
    function shot(name) { panel.grabToImage(r => r.saveToFile(win.outDir + "/" + name)); }

    Timer {
        interval: 400
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            try { run(); } catch (e) { console.error(e.message); running = false; Qt.exit(1); }
        }
        function run() {
            const t = panel.state.tab;
            if (step === 0) {
                win.unitChecks();
                eq(t.shown.length, 12, "hidden entries filtered");
                eq(t.shown[0].name, "capturas", "folders first");
                eq(t.shown.find(e => e.name === "arquitectura.md").git, "M", "git marks from the second pass");
                check(files.watched[win.docs] === 1, "current tab watches its folder");
                t.select(t.shown.findIndex(e => e.name === "backup-2026-10.zip"), 0);
                panel.state.newTab(win.home + "/Descargas");
                panel.state.setCurrent(0);
                check(!files.watched[win.home + "/Descargas"], "background tab does not watch");
                ops.feed(win.opEvents()[0]);
            }
            if (step === 1) shot("files-lista.png");
            if (step === 2) panel.state.viewMode = "cuadricula";
            if (step === 3) shot("files-cuadricula.png");
            if (step === 4) {
                panel.state.viewMode = "lista";
                // keyboard: up, back, forward, hidden files, search
                t.up(); eq(t.path, win.home + "/Proyectos/arxnet-erp", "up");
                t.back(); eq(t.path, win.docs, "back");
                t.forward(); eq(t.path, win.home + "/Proyectos/arxnet-erp", "forward");
                t.back();
                panel.state.showHidden = true; eq(t.shown.length, 13, "Ctrl+H shows hidden");
                panel.state.showHidden = false;
                panel.state.search = "tar"; eq(t.shown.length, 2, "search filters"); panel.state.search = "";
                t.select(1, 0); t.select(3, Qt.ShiftModifier); eq(t.selection.length, 3, "shift range");
                t.select(5, Qt.ControlModifier); eq(t.selection.length, 4, "ctrl toggle");
                t.go(win.home + "/privado");
            }
            if (step === 5) { eq(t.status, "error", "permission error state"); shot("files-error.png"); }
            if (step === 6) {
                t.back(); panel.state.closeTab(1); check(!files.watched[win.home + "/privado"], "watch released");
                t.selectNames(["foto-evento.jpg"]);
            }
            if (step === 7) shot("files-imagen.png");
            if (step === 8) {
                // drop rules: same device → move, Ctrl → copy, onto trash → trash, onto its own folder → nothing
                ops.calls = [];
                panel.dropInto(win.home + "/Documentos", [win.docs + "/dump.sql"], 0);
                panel.dropInto(win.home + "/Documentos", [win.docs + "/dump.sql"], Qt.ControlModifier);
                panel.dropInto("trash:///", [win.docs + "/dump.sql"], 0);
                panel.dropInto(win.docs, [win.docs + "/dump.sql"], 0);
                panel.dropInto(win.docs + "/capturas", [win.docs + "/capturas"], 0);
                eq(JSON.stringify(ops.calls.map(c => c[0])), JSON.stringify(["move", "copy", "trash"]), "drop rules");
                // keyboard: copy + paste, rename prompt
                t.selectNames(["dump.sql"]);
                panel.runAction("copy", t.focusEntry);
                eq(files.clipboard.paths[0], win.docs + "/dump.sql", "Ctrl+C");
                panel.pasteInto(win.home);
                eq(ops.calls[ops.calls.length - 1][0], "copy", "Ctrl+V copies");
                panel.contextMenuFor(t.focusEntry, 420, 300);
            }
            if (step === 9) shot("files-menu.png");
            if (step === 10) { panel.runAction("rename", t.focusEntry); }
            if (step === 11) shot("files-renombrar.png");
            if (step === 12) {
                prompt().reply("cancel");
                ops.feed(win.opEvents()[1]);
            }
            if (step === 13) { check(prompt().visible, "conflict asks by itself"); shot("files-conflicto.png"); }
            if (step === 14) {
                prompt().checked = true; prompt().reply("rename");
                eq(JSON.stringify(ops.calls[ops.calls.length - 1]), JSON.stringify(["answer", "rename", true]), "conflict answer");
                // devices: eject leaves the folder first, encrypted asks for the password (stdin in the service)
                t.go("/run/media/oddv/KINGSTON/fotos");
                panel.deviceAction(devs.deviceById("sda1"), "eject");
                eq(JSON.stringify(devs.calls[0]), JSON.stringify(["eject", "sda1"]), "eject");
                eq(t.path, win.home, "eject leaves the device folder");
                panel.deviceAction(devs.deviceById("sdb1"), "unlock");
            }
            if (step === 15) { prompt().value = "mala"; prompt().reply("ok"); }
            if (step === 16) {
                check(prompt().visible, "wrong password asks again");
                shot("files-cifrado.png");
            }
            if (step === 17) { prompt().reply("cancel"); t.go(win.docs); t.selectNames(["backup-2026-10.zip"]); }
            if (step === 18) { arch.test(win.docs + "/backup-2026-10.zip"); }
            if (step === 19) shot("files-lista.png");
            if (step === 20) { panel.state.viewMode = "cuadricula"; }
            if (step === 21) shot("files-cuadricula.png");
            if (step === 22) { panel.state.viewMode = "lista"; panel.runAction("extractTo", t.focusEntry); }
            if (step === 23) {
                const dlg = dialog("ExtractDialog");
                check(dlg.visible, "extract dialog");
                dlg.start();
                const c = arch.calls[arch.calls.length - 1];
                eq(c[2], win.docs, "own folder: dest is the archive's folder");
                check(c[3].ownFolder && c[3].conflict === "ask", "own folder flag + ask");
            }
            if (step === 24) shot("files-extraer.png");
            if (step === 25) {
                dialog("ExtractDialog").close();
                ops.queue = [];
                // encrypted archive from «Extraer aquí» → dialog asking for the password
                t.selectNames(["proyecto.7z"]);
                panel.runAction("extractHere", t.focusEntry);
                eq(dialog("ExtractDialog").need, "password_required", "password asked");
                dialog("ExtractDialog").close();
                panel.askCompress([win.docs + "/capturas"]);
                prompt().reply("tar.zst");
                eq(JSON.stringify(arch.calls[arch.calls.length - 1].slice(0, 3)), JSON.stringify(["create", "tar.zst", win.docs + "/capturas.tar.zst"]), "compress");
                ops.queue = [{ id: 1, kind: "copy", dest: "/run/media/oddv/KINGSTON/fotos", count: 5, index: 2, state: "running", pct: 38 }];
                t.selectNames(["backup-2026-10.zip"]);
            }
            if (step === 26) {
                t.go("net:///");
                check(t.isNet, "net tab");
            }
            if (step === 27) {
                const nv = dialog("NetView", panel);
                nv.selected = devs.hosts[0];
                eq(nv.shareList.length, 3, "shares of the selected host");
                eq(nv.connectedCount, 1, "connected hosts");
            }
            if (step === 28) shot("files-red.png");
            if (step === 29) {
                const nv = dialog("NetView", panel);
                nv.connectTo("sftp://192.168.1.44");
                check(nv.needsAuth, "auth asked");
            }
            if (step === 30) shot("files-red-credenciales.png");
            if (step === 31) {
                const nv = dialog("NetView", panel);
                nv.connectTo(nv.pendingUri, "pi", "secreto", true);
                eq(JSON.stringify(devs.calls[devs.calls.length - 1]), JSON.stringify(["connect", "sftp://192.168.1.44", "pi", 7, true]), "connect with credentials");
                eq(t.path, "/run/user/1000/gvfs/x", "opens the mount");
                t.go(win.docs);
                panel.runAction("shareHere", null);
            }
            if (step === 32) {
                const d = dialog("ShareDialog");
                check(d.visible && d.status?.shared, "share dialog with status");
                eq(d.smbAddress, "smb://dragonos/arxnet-erp", "smb address");
                eq(d.uncAddress, "\\\\dragonos\\arxnet-erp", "unc address");
            }
            if (step === 33) shot("files-compartir.png");
            if (step === 34) {
                const d = dialog("ShareDialog");
                d.rw = true; d.apply();
                eq(JSON.stringify(files.shareCalls[0]), JSON.stringify(["enable", win.docs, "arxnet-erp", true, false]), "enable args");
                d.close();
                t.go(win.home);
                panel.runAction("shareHere", null);
            }
            if (step === 35) {
                const d = dialog("ShareDialog");
                check(d.error.indexOf("carpeta personal") >= 0, "forbidden path shown");
                shot("files-compartir-prohibido.png");
            }
            if (step === 36) {
                dialog("ShareDialog").close();
                t.go(win.docs);
                panel.typeAhead("r"); panel.typeAhead("e");
                eq(t.focusEntry?.name, "release-2.4.tar.gz", "type-ahead");
                t.go("trash:///");
            }
            if (step === 37) {
                check(panel.inTrash, "trash view");
                t.selectNames(["viejo.txt"]);
                panel.runAction("restore", t.focusEntry);
                eq(JSON.stringify(ops.calls[ops.calls.length - 1][1]), JSON.stringify(["trash:///viejo.txt"]), "restore by uri");
                shot("files-papelera.png");
            }
            if (step === 38) { t.go(win.home + "/vacia"); }
            if (step === 39) shot("files-vacia.png");
            if (step === 40) t.go("/sin-herramienta");
            if (step === 41) { eq(t.error, "dragon-files no está instalado", "missing tool"); shot("files-sin-herramienta.png"); }
            if (step === 42) Qt.quit();
            step++;
        }
    }
}
