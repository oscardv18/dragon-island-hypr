// =============================================================================
// dragon-island — Files.qml (explorer data: folders, places, thumbnails, windows). Data only; the views in
// modules/files/ never run a command. Every call goes to `dragon-files … --json` (docs/design/PLAN-FASE-5.md §5.7).
// Nothing runs while no explorer window is open: watchers are reference-counted by the visible tabs.
// =============================================================================
/**
 * Properties:
 *   - status: string (ok|loading|unavailable|error) · message: string (human text of the last service error)
 *   - home: string [readonly]
 *   - places: var ([{id, label, path, kind: home|desktop|documents|downloads|pictures|music|videos|project|bookmark|trash,
 *       repo: bool, badge: int|null}]; from `places --json`, whether it arrives as one list or grouped by
 *       xdg / bookmarks / projects)
 *   - windows: var ([{uid, path}]) — one entry per open explorer window (shell.qml instantiates FilesWindow for each)
 *   - visibleWindows: int — windows on screen; Devices only watches udisks while this is > 0
 *   - clipboard: var ({mode: "copy"|"cut", paths: []}) — shared by every window
 *   - composerAvailable: bool — the prompt composer (tramo 5c) is present; until then «Enviar al agente» is disabled
 *
 * Functions:
 *   - list(path, opts {hidden, git}, callback(result)) — `ls`; result = {ok, path, entries, free, total, fs} or error
 *   - properties(path, callback) — `props`
 *   - thumb(path, callback(file|null)) — `thumb --size large`; cached per path+mtime, at most
 *       Theme.files.thumbConcurrency processes at once, queued in request order
 *   - open(path) · openWith(path, appId) · openWithList(path, callback) · terminalHere(path)
 *   - acquireWatch(path) / releaseWatch(path) — one `watch` process per folder while some visible tab shows it
 *   - setClipboard(mode, paths) · copyText(text) (system clipboard, for the share addresses)
 *   - refreshPlaces() · addBookmark(path, label) · removeBookmark(path)
 *   - openWindow(path) · closeWindow(uid) · windowShown(bool)
 *   - sendToAgent(paths) — emits agentRequested(paths) for the composer; nothing is sent anywhere by itself
 *
 * Signals: folderChanged(path) · agentRequested(paths) · placesChanged()
 * IPC (target "files"): open(path) — new window (home when empty) · count(): int
 * =============================================================================
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root
    readonly property string home: Quickshell.env("HOME") ?? "/"
    property string status: "ok"
    property string message: ""
    property var places: []
    property var windows: []
    property int visibleWindows: 0
    property var clipboard: ({ mode: "", paths: [] })
    property bool composerAvailable: false
    property int _uid: 0
    property var _watchers: ({})
    property var _thumbs: ({})
    property var _thumbQueue: []
    property int _thumbRunning: 0
    signal folderChanged(string path)
    signal agentRequested(var paths)

    Component { id: requestComponent; FilesRequest {} }

    function call(args, callback, extra): var {
        const p = requestComponent.createObject(root, Object.assign({ args: args, callback: callback ?? null }, extra ?? {}));
        p.start();
        return p;
    }
    function _report(r): void {
        if (r.ok) return;
        if (r.error?.code === "missing_tool") { status = "unavailable"; message = "dragon-files no está instalado: ejecuta ./update.sh"; }
        else { message = r.error?.message ?? "Error"; }
    }

    // ---- windows ----
    function openWindow(path): void {
        _uid++;
        windows = windows.concat([{ uid: _uid, path: path || home }]);
        if (windows.length === 1) refreshPlaces();
    }
    function closeWindow(uid): void { windows = windows.filter(w => w.uid !== uid); }
    function windowShown(shown): void { visibleWindows = Math.max(0, visibleWindows + (shown ? 1 : -1)); }

    // ---- folders ----
    function list(path, opts, callback): void {
        const args = ["ls", path, "--sort", "name", "--dirs-first"];
        if (opts?.hidden) args.push("--hidden");
        if (opts?.git) args.push("--git");
        call(args, r => {
            if (r.ok && status !== "ok") { status = "ok"; message = ""; }
            else _report(r);
            if (callback) callback(r);
        });
    }
    function properties(path, callback): void { call(["props", path], callback); }
    function open(path): void { call(["open", path], _report); }
    function openWith(path, appId): void { call(["open-with", path, "--app", appId], _report); }
    function openWithList(path, callback): void { call(["open-with", path, "--list"], callback); }
    function terminalHere(path): void { call(["terminal-here", path], _report); }

    function acquireWatch(path): void {
        if (!path || path.indexOf("://") >= 0) return;
        const w = Object.assign({}, _watchers);
        if (w[path]) { w[path].refs++; _watchers = w; return; }
        const p = requestComponent.createObject(root, { args: ["watch", path], stream: true, persistent: true });
        const debounce = debounceComponent.createObject(root, { path: path });
        p.event.connect(() => debounce.restart());
        p.done.connect(r => { if (!r.ok && r.error?.code !== "cancelled") console.warn("files watch:", path, r.error?.message); });
        p.start();
        w[path] = { refs: 1, proc: p, timer: debounce };
        _watchers = w;
    }
    function releaseWatch(path): void {
        const w = Object.assign({}, _watchers);
        const e = w[path];
        if (!e) return;
        if (--e.refs > 0) { _watchers = w; return; }
        e.proc.running = false;
        e.proc.destroy();
        e.timer.destroy();
        delete w[path];
        _watchers = w;
    }
    Component {
        id: debounceComponent
        Timer {
            property string path
            interval: Theme.files.watchDebounce
            onTriggered: root.folderChanged(path)
        }
    }

    // ---- thumbnails ----
    function thumb(path, mtime, callback): void {
        const key = path + "@" + (mtime ?? 0);
        if (_thumbs[key] !== undefined) { callback(_thumbs[key]); return; }
        _thumbQueue.push({ key: key, path: path, callback: callback });
        _pumpThumbs();
    }
    function _pumpThumbs(): void {
        while (_thumbRunning < Theme.files.thumbConcurrency && _thumbQueue.length) {
            const job = _thumbQueue.shift();
            if (_thumbs[job.key] !== undefined) { job.callback(_thumbs[job.key]); continue; }
            _thumbRunning++;
            call(["thumb", job.path, "--size", "large"], r => {
                _thumbRunning--;
                const file = r.ok ? (r.thumb ?? r.path ?? null) : null;
                const t = _thumbs; t[job.key] = file;
                job.callback(file);
                _pumpThumbs();
            });
        }
    }

    // ---- places ----
    function refreshPlaces(): void {
        call(["places"], r => {
            if (!r.ok) { _report(r); return; }
            places = Array.isArray(r.places) ? r.places
                : [].concat(r.xdg ?? r.places?.xdg ?? [], r.projects ?? r.places?.projects ?? [], r.bookmarks ?? r.places?.bookmarks ?? []);
        });
    }
    function addBookmark(path, label): void { call(["places", "add", path].concat(label ? ["--label", label] : []), r => { if (r.ok) refreshPlaces(); else _report(r); }); }
    function removeBookmark(path): void { call(["places", "rm", path], r => { if (r.ok) refreshPlaces(); else _report(r); }); }

    // ---- clipboard / agent ----
    function setClipboard(mode, paths): void { clipboard = { mode: mode, paths: paths.slice() }; }
    function copyText(text): void { Quickshell.clipboardText = text; }
    function sendToAgent(paths): void { if (composerAvailable && paths.length) agentRequested(paths); }

    IpcHandler {
        target: "files"
        function open(path: string): void { root.openWindow(path); }
        function count(): int { return root.windows.length; }
    }
}
