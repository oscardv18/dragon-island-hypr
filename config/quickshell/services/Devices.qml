// =============================================================================
// dragon-island — Devices.qml (disks, USB, phones, encrypted volumes and network places). Data only.
// `dragon-files devices --json` once, then `devices --watch` (udev/udisks events) ONLY while an explorer window is
// on screen; every event re-reads the list. Passwords go through stdin, never through arguments.
// =============================================================================
/**
 * Properties:
 *   - status: string (ok|loading|unavailable|error) · message: string
 *   - devices: var ([{id, label, kind: disk|usb|mtp|optical|luks, size, used, free, fstype, mounted, mountpoint,
 *       removable, locked, hidden?}] — exactly the §5.7 contract; `hidden` entries are not shown)
 *   - busy: var ({id: "mount"|"unmount"|"eject"|"unlock"}) — actions in flight
 *   - errors: var ({id: message}) — the last failure of each device, cleared on the next success
 *   - watching: bool [readonly] — the event watcher runs
 *   - hosts: var ([{name, address, protocol: smb|sftp|ssh|nfs|ftp|webdav|ipp, uri, port?}]) — `net discover --json`
 *   - netMounts: var ([{uri, name, protocol, host, address?, path, user?, free?, total?, version?}]) — `net mounts`
 *   - servers: var ([{uri, name, protocol, user?}]) — saved servers / bookmarks (`net saved`)
 *   - discovering: bool — a discovery is running · netStatus/netMessage: avahi missing etc.
 *   - netBusy: var ({uri: "connect"|"unmount"}) · netErrors: var ({uri: {code, message}})
 *
 * Functions:
 *   - refresh() · mount(id, callback) · unmount(id) · eject(id) · unlock(id, passphrase, callback)
 *   - deviceById(id): var
 *   - discover() — one `net discover` (NetView repeats it every Theme.files.discoverEvery while it is visible)
 *   - refreshNet() — mounts + saved servers
 *   - connect(uri, user, password, save, callback) — `net connect <uri> [--user] [--password-stdin] [--save]`; the
 *       password goes to the system keyring (the tool uses secret-tool), never to a file; error auth_required asks
 *   - unmountNet(uri) · shares(host, callback) — `net shares <host>` · saveServer(uri, name) · forgetServer(uri)
 *   - hostState(host): "connected"|"saved"|"printer"|"available" · mountFor(host): var
 * =============================================================================
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root
    property string status: "loading"
    property string message: ""
    property var devices: []
    property var busy: ({})
    property var errors: ({})
    readonly property bool wanted: Files.visibleWindows > 0
    readonly property bool watching: _watcher !== null
    property var _watcher: null
    property var hosts: []
    property var netMounts: []
    property var servers: []
    property bool discovering: false
    property string netStatus: "ok"
    property string netMessage: ""
    property var netBusy: ({})
    property var netErrors: ({})

    Component { id: requestComponent; FilesRequest {} }
    function call(args, callback, extra): var {
        const p = requestComponent.createObject(root, Object.assign({ args: args, callback: callback ?? null }, extra ?? {}));
        p.start();
        return p;
    }

    function refresh(): void {
        call(["devices"], r => {
            const list = Array.isArray(r) ? r : (r.ok ? (r.devices ?? []) : null);
            if (list === null) {
                status = r.error?.code === "missing_tool" ? "unavailable" : "error";
                message = r.error?.code === "missing_tool" ? "dragon-files no está instalado: ejecuta ./update.sh" : (r.error?.message ?? "No se pudieron leer los dispositivos");
                return;
            }
            devices = list.filter(d => !d.hidden);
            status = "ok"; message = "";
        });
    }
    function deviceById(id): var { return devices.find(d => d.id === id) ?? null; }

    function _act(action, id, args, callback, extra): void {
        const b = Object.assign({}, busy); b[id] = action; busy = b;
        call(args, r => {
            const nb = Object.assign({}, busy); delete nb[id]; busy = nb;
            const e = Object.assign({}, errors);
            if (r.ok) delete e[id]; else e[id] = r.error?.message ?? "No se pudo completar";
            errors = e;
            refresh();
            if (callback) callback(r);
        }, extra);
    }
    function mount(id, callback): void { _act("mount", id, ["mount", id], callback); }
    function unmount(id): void { _act("unmount", id, ["unmount", id]); }
    function eject(id): void { _act("eject", id, ["eject", id]); }
    function unlock(id, passphrase, callback): void { _act("unlock", id, ["unlock", id, "--passphrase-stdin"], callback, { input: passphrase }); }

    // ---- event watcher: only while some explorer window is visible ----
    onWantedChanged: _syncWatch()
    Component.onCompleted: _syncWatch()
    function _syncWatch(): void {
        if (wanted && !_watcher) {
            refresh();
            refreshNet();
            const p = requestComponent.createObject(root, { args: ["devices", "--watch"], stream: true, persistent: true });
            p.event.connect(() => debounce.restart());
            p.done.connect(r => { if (root._watcher === p) { root._watcher = null; p.destroy(); if (root.wanted) retry.start(); } });
            _watcher = p;
            p.start();
        } else if (!wanted && _watcher) {
            const p = _watcher;
            _watcher = null;
            p.running = false;
            p.destroy();
            retry.stop();
        }
    }
    Timer { id: debounce; interval: Theme.files.watchDebounce; onTriggered: root.refresh() }
    // the watcher died (tool missing, udisks restarted): try again later, never in a tight loop
    Timer { id: retry; interval: Theme.files.watchRetry; onTriggered: root._syncWatch() }

    // ---- network (d5) ----
    function discover(): void {
        if (discovering) return;
        discovering = true;
        call(["net", "discover"], r => {
            discovering = false;
            if (r.ok) { hosts = r.hosts ?? []; netStatus = "ok"; netMessage = ""; }
            else { netStatus = r.error?.code === "missing_tool" ? "unavailable" : "error"; netMessage = r.error?.message ?? "No se pudo buscar en la red"; if (r.error?.hint) netMessage += ". " + r.error.hint; }
        });
        refreshNet();
    }
    function refreshNet(): void {
        call(["net", "mounts"], r => { if (r.ok) netMounts = r.mounts ?? []; });
        call(["net", "saved"], r => { if (r.ok) servers = r.servers ?? []; });
    }
    function _hostMatches(h, m): bool { return !!m && (m.host === h.name || m.host === h.address || (m.address && m.address === h.address)); }
    function mountFor(host): var { return netMounts.find(m => _hostMatches(host, m)) ?? null; }
    function hostState(host): string {
        if (host.protocol === "ipp") return "printer";
        if (mountFor(host)) return "connected";
        if (servers.some(s => s.uri && (s.uri.indexOf("//" + host.name) >= 0 || s.uri.indexOf("//" + host.address) >= 0))) return "saved";
        return "available";
    }
    function _netAct(uri, action, args, callback, extra): void {
        const b = Object.assign({}, netBusy); b[uri] = action; netBusy = b;
        call(args, r => {
            const nb = Object.assign({}, netBusy); delete nb[uri]; netBusy = nb;
            const e = Object.assign({}, netErrors);
            if (r.ok) delete e[uri]; else e[uri] = r.error ?? { code: "error", message: "No se pudo conectar" };
            netErrors = e;
            refreshNet();
            if (callback) callback(r);
        }, extra);
    }
    function connect(uri, user, password, save, callback): void {
        const args = ["net", "connect", uri];
        if (user) args.push("--user", user);
        if (password) args.push("--password-stdin");
        if (save) args.push("--save");
        _netAct(uri, "connect", args, callback, { input: password ?? "" });
    }
    function unmountNet(uri): void { _netAct(uri, "unmount", ["net", "unmount", uri]); }
    function shares(host, callback): void { call(["net", "shares", host], callback); }
    function saveServer(uri, name): void { call(["net", "save", uri].concat(name ? ["--name", name] : []), r => refreshNet()); }
    function forgetServer(uri): void { call(["net", "forget", uri], r => refreshNet()); }
}
