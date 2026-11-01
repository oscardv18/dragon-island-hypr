// =============================================================================
// dragon-island — Devices.qml (disks, USB, phones, encrypted volumes; network places are added in d5). Data only.
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
 *
 * Functions:
 *   - refresh() · mount(id, callback) · unmount(id) · eject(id) · unlock(id, passphrase, callback)
 *   - deviceById(id): var
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
}
