// =============================================================================
// dragon-island — Wallpaper.qml
// Service: wallpapers (static, GIF, video) with awww (images / GIF) and mpvpaper (video)
// =============================================================================
/**
 * Folder: settings.json "wallpaperDir" (default ~/Pictures/Wallpapers, created on the first scan).
 * Tools: awww-daemon + `awww img` for jpg / png / webp / GIF (transition "grow" from the centre, 60 fps),
 * one mpvpaper per monitor for mp4 / webm / mkv (loop, no audio, hwdec). Only one of them runs at a time
 * (scripts/wallpapers.sh stops the other). The heavy lifting (scan, thumbnails, apply) is in that script.
 *
 * Properties:
 *   - dir: string [readonly]
 *   - items: list<var> [readonly] ({ path, name, kind: "static" | "animated" | "video", thumb, mtime })
 *   - thumbsReady: var [readonly] (path → true once its thumbnail exists, ~/.cache/dragon-island/thumbs)
 *   - loading: bool [readonly]
 *   - current: string [readonly] (path of the active wallpaper, "" if none yet)
 *   - currentKind: string [readonly]
 *   - videoPaused: bool [readonly] (a monitor has a fullscreen window: its video is paused)
 *
 * Functions:
 *   - refresh(): void                 (rescan the folder; thumbnails are only made if missing or changed)
 *   - apply(path: string): void       (saves it to ~/.local/state/dragon-island/wallpaper.json)
 *   - random(): void   next(): void   previous(): void
 *   - search(query: string, tab: string): list<var>  (tab: "all" | "static" | "animated"; animated = GIF + video)
 *   - openFolder(): void              (Dolphin)
 *   - thumbUrl(item): string
 *
 * ~/.cache/dragon-island/current-wallpaper always links to the current image (a frame for GIF / video):
 * hyprlock uses it as its background.
 *
 * Video pause: when the workspace shown on a monitor has a fullscreen window (Hyprland events, through
 * Hypr.fullscreenOn), that monitor's mpvpaper is paused over mpv's own IPC socket (set_property pause).
 * Chosen over SIGSTOP / mpvpaper's --auto-pause because it stops decoding and rendering cleanly, keeps
 * the Wayland connection alive (a stopped client cannot answer configure / output events), is per monitor
 * and needs no extra tool.
 *
 * IPC (`qs ipc call wallpaper <fn>`): toggle(), set(path: string), random(), next(), current(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../components"

Singleton {
    id: root

    readonly property string dir: Settings.wallpaperDir
    readonly property string script: `${Quickshell.shellDir}/scripts/wallpapers.sh`
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
    readonly property string defaultFallback: `${Quickshell.env("HOME")}/.local/share/dragon-island/wallpaper.jpg`

    property var items: []
    property var thumbsReady: ({})
    property bool loading: false
    property bool videoPaused: false

    readonly property string current: saved.path
    readonly property string currentKind: saved.kind

    property bool _restored: false
    property var _buf: []
    property var _queue: null          // latest apply request while the applier is busy

    function init(): void { }          // touching the singleton starts it (IPC target, restore)

    function kindOf(path: string): string {
        const p = path.toLowerCase();
        if (/\.(jpe?g|png|webp)$/.test(p)) return "static";
        if (p.endsWith(".gif")) return "animated";
        if (/\.(mp4|webm|mkv)$/.test(p)) return "video";
        return "";
    }

    function thumbUrl(item): string {
        return item && root.thumbsReady[item.path] ? `file://${item.thumb}` : "";
    }

    function search(query: string, tab: string): var {
        const q = query.trim().toLowerCase();
        return root.items.filter(i => {
            if (tab === "static" && i.kind !== "static") return false;
            if (tab === "animated" && i.kind === "static") return false;
            return q.length === 0 || i.name.toLowerCase().includes(q);
        });
    }

    function refresh(): void {
        if (scanner.running) return;
        root._buf = [];
        root.loading = true;
        scanner.exec(["bash", root.script, "scan", root.dir]);
    }

    function apply(path: string): void {
        const kind = root.kindOf(path);
        if (kind.length === 0) return;
        saved.path = path;
        saved.kind = kind;
        stateFile.writeAdapter();
        root._run(path, kind, "grow");
    }

    function _run(path: string, kind: string, transition: string): void {
        const req = { path: path, kind: kind, transition: transition };
        if (applier.running) { root._queue = req; return; }
        if (kind === "video") applier.exec(["bash", root.script, "apply-video", path, ...Quickshell.screens.map(s => s.name)]);
        else applier.exec(["bash", root.script, "apply-image", path, transition]);
    }

    function _step(delta: int): void {
        const list = root.items;
        if (list.length === 0) return;
        const at = list.findIndex(i => i.path === root.current);
        root.apply(list[((at < 0 ? 0 : at) + delta + list.length) % list.length].path);
    }
    function next(): void { root._step(1); }
    function previous(): void { root._step(-1); }
    function random(): void {
        const others = root.items.filter(i => i.path !== root.current);
        if (others.length === 0) return;
        root.apply(others[Math.floor(Math.random() * others.length)].path);
    }

    function openFolder(): void { Quickshell.execDetached(["dolphin", root.dir]); }

    // ---- login: restore the saved wallpaper (only if nothing is displaying one yet) ----
    function _restore(): void {
        if (root._restored) return;
        root._restored = true;
        let path = saved.path;
        const known = root.items.find(i => i.path === path);
        if (!known) {
            const def = root.items.find(i => i.name === "dragon-island.jpg") ?? root.items[0];
            path = def ? def.path : root.defaultFallback;
        }
        probe.target = path;
        probe.previous = saved.path;
        probe.exec(["bash", root.script, "running"]);
    }

    Process {
        id: probe
        property string target: ""
        property string previous: ""
        stdout: StdioCollector {
            onStreamFinished: {
                // awww restores its own last image when the daemon starts, so compare with what we saved:
                // a video needs mpvpaper running; an image needs awww to be showing exactly that file
                const state = this.text.trim().split("\t");
                const kind = root.kindOf(probe.target);
                if (kind.length === 0) return;
                const already = kind === "video" ? state[0] === "video" : (state[0] === "image" && state[1] === probe.target);
                saved.path = probe.target;
                saved.kind = kind;
                if (saved.path !== probe.previous) stateFile.writeAdapter();
                if (!already) root._run(probe.target, kind, "none");   // login: no transition
            }
        }
    }

    Process {
        id: scanner
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f.length < 4) return;
                root._buf.push({ path: f[0], name: f[0].slice(f[0].lastIndexOf("/") + 1), kind: f[1], thumb: f[2], mtime: Number(f[3]) });
            }
        }
        onExited: {
            root.items = root._buf;
            root.loading = false;
            thumbs.exec(["bash", root.script, "thumbs", root.dir]);
            root._restore();
        }
    }

    // thumbnails in the background; every finished one flips thumbsReady[path]
    Process {
        id: thumbs
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] !== "ready" || f.length < 2) return;
                const next = Object.assign({}, root.thumbsReady);
                next[f[1]] = true;
                root.thumbsReady = next;
            }
        }
    }

    Process {
        id: applier
        onExited: {
            const q = root._queue;
            root._queue = null;
            if (q) root._run(q.path, q.kind, q.transition);
            else pauseSync.restart();
        }
    }

    // ---- smart pause of the video ----
    Timer { id: pauseSync; interval: 1500; onTriggered: root._syncPause() }

    Instantiator {
        id: pausers
        model: Quickshell.screens
        delegate: MpvPause {
            required property var modelData
            output: modelData.name
            readonly property bool fullscreen: Hypr.fullscreenOn(modelData)
            onFullscreenChanged: if (root.currentKind === "video") { setPaused(fullscreen); root._updatePaused(); }
        }
    }

    function _updatePaused(): void {
        let any = false;
        for (let i = 0; i < pausers.count; i++) if (pausers.objectAt(i)?.fullscreen) any = true;
        root.videoPaused = any && root.currentKind === "video";
    }

    function _syncPause(): void {
        if (root.currentKind !== "video") { root.videoPaused = false; return; }
        for (let i = 0; i < pausers.count; i++) {
            const p = pausers.objectAt(i);
            if (p) p.setPaused(p.fullscreen);
        }
        root._updatePaused();
    }

    // ---- saved state ----
    FileView {
        id: stateFile
        path: `${root.stateHome}/dragon-island/wallpaper.json`
        printErrors: false
        adapter: JsonAdapter {
            id: saved
            property string path: ""
            property string kind: ""
        }
        onLoaded: root.refresh()
        onLoadFailed: root.refresh()
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { ShellState.toggle("wallpapers", ""); }
        function set(path: string): void { root.apply(path); }
        function random(): void { root.random(); }
        function next(): void { root.next(); }
        function current(): string { return root.current; }
    }
}
