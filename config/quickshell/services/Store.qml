// =============================================================================
// dragon-island — Store.qml
// Service: data and actions of the "Tienda" panel (SUPER + I): search pacman + AUR, installed, updates, cleanup
// =============================================================================
/**
 * Reads go through scripts/store.sh (Process, in the background; nothing here blocks the UI). Anything that needs
 * privileges runs in a floating Ghostty window through ~/.local/bin/dragon-pkg (bin/dragon-pkg of the repo):
 * Quickshell never asks for or handles a password. The script writes ~/.local/state/dragon-island/pkg-status.json
 * when it ends; this service watches it, notifies, and refreshes the lists and Updates.
 *
 * Properties:
 *   - results: list<var> [readonly] ({ repo: "extra" | "aur" ..., name, version, installed: bool })
 *   - searching / listsReady: bool [readonly]
 *   - installed: list<var> [readonly] ({ name, version, aur: bool })
 *   - updates: list<var> [readonly] ({ repo: "official" | "aur", name, old, new }); updatesLoading: bool
 *   - orphans: list<string> [readonly]; cacheSize: string; cacheOld: int
 *   - details: var [readonly] (Key → value of the focused package); detailsFor: string; detailsLoading: bool
 *   - pkgbuild: string [readonly]; pkgbuildFor: string; pkgbuildLoading: bool
 *   - removePreview: var [readonly] ({ ok: [names that go], err: [pacman lines], names: [asked] }); previewing: bool
 *   - selected: var [readonly] (name → { repo }); selectedCount: int
 *   - pendingQuery: string (set by the orbital launcher's "+name" prefix; the panel consumes it)
 *   - helper: string [readonly] ("paru" | "yay" | "")
 *
 * Functions:
 *   - init(): void   refreshLists(): void   search(query)   loadInfo(item)   loadInstalledInfo(name)
 *   - loadInstalled()   loadUpdates()   loadClean()   loadPkgbuild(name)   previewRemoval(names)
 *   - toggleSelect(item): void   clearSelection(): void   isSelected(name): bool
 *   - install(items): void   (official ones with pacman, AUR ones with the helper: one terminal each)
 *   - remove(names)   updateAll()   clean(what: "orphans" | "cache" | "all")
 *   - isCritical(name): bool
 *
 * IPC: none of its own: `qs ipc call shell toggle store`.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: `${Quickshell.shellDir}/scripts/store.sh`
    readonly property string pkgBin: `${home}/.local/bin/dragon-pkg`
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string statusPath: `${stateHome}/dragon-island/pkg-status.json`
    readonly property string logPath: `${stateHome}/dragon-island/pkg.log`

    property string pendingQuery: ""
    property string helper: ""

    property var results: []
    property bool searching: false
    property bool listsReady: false
    property var installed: []
    property var updates: []
    property bool updatesLoading: false
    property var orphans: []
    property string cacheSize: ""
    property int cacheOld: 0
    property var details: ({})
    property string detailsFor: ""
    property bool detailsLoading: false
    property string pkgbuild: ""
    property string pkgbuildFor: ""
    property bool pkgbuildLoading: false
    property var removePreview: ({ ok: [], err: [], names: [] })
    property bool previewing: false
    property var selected: ({})
    readonly property int selectedCount: Object.keys(selected).length

    // packages whose removal can leave the system unbootable or the session unusable
    readonly property var _critical: /^(base|base-devel|linux|linux-.*|linux-firmware.*|systemd.*|glibc|gcc-libs|pacman|pacman-.*|bash|coreutils|filesystem|util-linux.*|shadow|sudo|grub|mkinitcpio.*|hyprland|hyprlock|hypridle|hyprutils|quickshell|pipewire.*|wireplumber|networkmanager|sddm.*|plasma.*|kwin.*|kde-.*|xorg-.*|wayland|mesa|dbus.*|polkit.*|ghostty|qt6-base|qt6-declarative|yay|paru)$/

    function isCritical(name: string): bool { return root._critical.test(name); }

    function init(): void { }          // touching the singleton starts it (lists, status watcher)

    // ---------------------------------------------------------------- lists
    function refreshLists(): void {
        if (!lists.running) lists.exec(["bash", root.script, "refresh"]);
    }

    Process {
        id: lists
        stdout: StdioCollector { onStreamFinished: root.listsReady = true }
        onExited: { root.loadInstalled(); if (root._lastQuery.length > 0) root.search(root._lastQuery); }
    }

    Process {
        command: ["sh", "-c", "command -v paru >/dev/null 2>&1 && echo paru || { command -v yay >/dev/null 2>&1 && echo yay; } || true"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.helper = this.text.trim() }
    }

    Component.onCompleted: refreshLists()
    Timer { interval: 86400000; running: true; repeat: true; onTriggered: root.refreshLists() }   // the AUR list: once a day

    // ---------------------------------------------------------------- search
    property string _lastQuery: ""
    property bool _searchAgain: false

    function search(query: string): void {
        root._lastQuery = query;
        if (searcher.running) { root._searchAgain = true; return; }
        root._runSearch();
    }
    function _runSearch(): void {
        root.searching = true;
        searcher.exec(["bash", root.script, "search", root._lastQuery, "150"]);
    }
    Process {
        id: searcher
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._searchAgain) return;
                const out = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 4 || f[1].length === 0) continue;
                    out.push({ repo: f[0], name: f[1], version: f[2], installed: f[3] === "1" });
                }
                root.results = out;
            }
        }
        onExited: {
            if (root._searchAgain) { root._searchAgain = false; root._runSearch(); }
            else root.searching = false;
        }
    }

    // ---------------------------------------------------------------- details (AUR: votes, maintainer, out of date ...)
    property var _infoReq: null
    property string _ranKey: ""
    function _parseKv(text: string): var {
        const o = {};
        for (const line of text.split("\n")) {
            const i = line.indexOf("\t");
            if (i > 0) o[line.slice(0, i)] = line.slice(i + 1).trim();
        }
        return o;
    }
    function _startInfo(): void {
        root._ranKey = root._infoReq.join("\t");
        infoProc.exec(["bash", root.script].concat(root._infoReq));
    }
    function _info(args: var, name: string): void {
        root.detailsFor = name;
        root.detailsLoading = true;
        root._infoReq = args;
        if (!infoProc.running) root._startInfo();
    }
    function loadInfo(item): void { if (item) root._info(["info", item.repo === "aur" ? "aur" : "official", item.name], item.name); }
    function loadInstalledInfo(name: string): void { root._info(["qinfo", name], name); }
    Process {
        id: infoProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._infoReq && root._infoReq.join("\t") === root._ranKey) root.details = root._parseKv(this.text);
            }
        }
        onExited: {
            // a newer request arrived while this one ran: run it; otherwise we are done
            if (root._infoReq && root._infoReq.join("\t") !== root._ranKey) root._startInfo();
            else root.detailsLoading = false;
        }
    }

    // ---------------------------------------------------------------- PKGBUILD
    function loadPkgbuild(name: string): void {
        root.pkgbuildFor = name;
        root.pkgbuild = "";
        root.pkgbuildLoading = true;
        pkgbuildProc.exec(["bash", root.script, "pkgbuild", name]);
    }
    Process {
        id: pkgbuildProc
        stdout: StdioCollector { onStreamFinished: { root.pkgbuild = this.text; root.pkgbuildLoading = false; } }
    }

    // ---------------------------------------------------------------- installed
    property var _explicit: []
    function loadInstalled(): void {
        installedOfficial.exec(["bash", root.script, "installed", "explicit"]);
    }
    function _parseInstalled(text: string, aur: bool): var {
        const out = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f[0]) out.push({ name: f[0], version: f[1] || "", aur: aur });
        }
        return out;
    }
    Process {
        id: installedOfficial
        stdout: StdioCollector { onStreamFinished: root._explicit = root._parseInstalled(this.text, false) }
        onExited: installedAur.exec(["bash", root.script, "installed", "aur"])
    }
    Process {
        id: installedAur
        stdout: StdioCollector {
            onStreamFinished: root.installed = root._explicit.concat(root._parseInstalled(this.text, true)).sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    // ---------------------------------------------------------------- updates
    function loadUpdates(): void {
        if (updatesProc.running) return;
        root.updatesLoading = true;
        updatesProc.exec(["bash", root.script, "updates"]);
    }
    Process {
        id: updatesProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length >= 4) out.push({ repo: f[0], name: f[1], old: f[2], new: f[3] });
                }
                root.updates = out;
                // the right island's counter comes from here too
                Updates.repoCount = out.filter(u => u.repo === "official").length;
                Updates.aurCount = out.filter(u => u.repo === "aur").length;
            }
        }
        onExited: root.updatesLoading = false
    }

    // ---------------------------------------------------------------- cleanup
    function loadClean(): void {
        orphansProc.exec(["bash", root.script, "orphans"]);
        cacheProc.exec(["bash", root.script, "cache"]);
    }
    Process {
        id: orphansProc
        stdout: StdioCollector { onStreamFinished: root.orphans = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0) }
    }
    Process {
        id: cacheProc
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "size") root.cacheSize = f[1] || "";
                    if (f[0] === "old") root.cacheOld = parseInt(f[1]) || 0;
                }
            }
        }
    }

    // ---------------------------------------------------------------- removal preview (pacman -Rs --print)
    function previewRemoval(names: var): void {
        root.previewing = true;
        root.removePreview = { ok: [], err: [], names: names };
        previewProc.exec(["bash", root.script, "preview-remove"].concat(names));
    }
    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = [], err = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "OK") ok.push(f[1]);
                    else if (f[0] === "ERR") err.push(f[1]);
                }
                root.removePreview = { ok: ok, err: err, names: root.removePreview.names };
            }
        }
        onExited: root.previewing = false
    }

    // ---------------------------------------------------------------- selection
    function isSelected(name: string): bool { return root.selected[name] !== undefined; }
    function toggleSelect(item): void {
        const next = Object.assign({}, root.selected);
        if (next[item.name] !== undefined) delete next[item.name];
        else next[item.name] = { repo: item.repo ?? (item.aur ? "aur" : "official") };
        root.selected = next;
    }
    function clearSelection(): void { root.selected = ({}); }

    // ---------------------------------------------------------------- actions: a floating Ghostty runs bin/dragon-pkg
    function _terminal(action: string, pkgs: var): void {
        Quickshell.execDetached(["ghostty", "--class=org.dragonisland.Pkg", "--title=Tienda de apps — " + action, "-e", root.pkgBin, action].concat(pkgs));
    }

    function install(items: var): void {
        const official = items.filter(i => i.repo !== "aur").map(i => i.name);
        const aur = items.filter(i => i.repo === "aur").map(i => i.name);
        // two terminals only when both kinds are asked: the official ones first
        if (official.length > 0 && aur.length > 0) {
            Quickshell.execDetached(["ghostty", "--class=org.dragonisland.Pkg", "--title=Tienda de apps — instalar", "-e", "sh", "-c",
                `"$0" install ${official.join(" ")} && "$0" aur ${aur.join(" ")}`, root.pkgBin]);
        } else if (official.length > 0) root._terminal("install", official);
        else if (aur.length > 0) root._terminal("aur", aur);
    }
    function remove(names: var): void { root._terminal("remove", names); }
    function updateAll(): void { root._terminal("update", []); }
    function clean(what: string): void { root._terminal("clean", [what]); }

    // ---------------------------------------------------------------- result of the terminal
    property string _lastStatusId: ""
    property bool _statusPrimed: false

    FileView {
        id: statusFile
        path: root.statusPath
        printErrors: false
        watchChanges: true
        onFileChanged: statusFile.reload()
        onLoaded: root._status(statusFile.text())
    }

    function _status(text: string): void {
        let st = null;
        try { st = JSON.parse(text); } catch (e) { return; }
        if (!st || !st.id) return;
        if (!root._statusPrimed) { root._statusPrimed = true; root._lastStatusId = st.id; return; }   // the one from a previous session
        if (st.id === root._lastStatusId) return;
        root._lastStatusId = st.id;

        const names = (st.packages || []).join(", ") + (st.dryRun ? " (simulación)" : "");
        const verbs = { install: "Instalado", aur: "Instalado", remove: "Eliminado", update: "Sistema actualizado", clean: "Limpieza hecha" };
        const fails = { install: "Error al instalar", aur: "Error al instalar", remove: "Error al eliminar", update: "Error al actualizar", clean: "Error en la limpieza" };
        if (st.code === 0) {
            Quickshell.execDetached(["notify-send", "-a", "Tienda", "-i", "package-x-generic", `${verbs[st.action] || "Hecho"}${names ? ": " + names : ""}`,
                st.repoChanged ? "Las listas de «Mis apps» del repo cambiaron (cambios sin commit en packages/)" : "Listo"]);
        } else {
            // the action opens the log in a terminal
            Quickshell.execDetached(["sh", "-c",
                `a=$(notify-send -a Tienda -u critical -A log="Ver registro" "$1" "Código de salida ${st.code}"); [ "$a" = log ] && exec ghostty --class=org.dragonisland.Pkg --title="Registro de la Tienda" -e less +G "$2"`,
                "sh", `${fails[st.action] || "Error"}${names ? ": " + names : ""}`, root.logPath]);
        }
        // whatever happened, look again: installed marks, lists, the right island's update counter, new .desktop files
        // (DesktopEntries notices them on its own, so the orbital launcher shows the new app)
        root.clearSelection();
        root.refreshLists();
        Updates.refresh();
    }
}
