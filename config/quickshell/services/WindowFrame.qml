// =============================================================================
// dragon-island — WindowFrame.qml
// Service: the focused window's real geometry, for the frame drawn around it (modules/frame/FrameWindow.qml).
// config/hypr/framewatch.lua writes $XDG_RUNTIME_DIR/dragon-window-frame from inside Hyprland, only when something
// changed (Hyprland has no IPC event for moves / resizes); this watches it with inotify — no timer, no process.
// =============================================================================
/**
 * Properties:
 *   - present: bool [readonly] (a window has the focus and the feed is alive)
 *   - address: string [readonly]
 *   - winX / winY / winW / winH: real [readonly] (the window's own box, local to its monitor, logical px, no border)
 *   - fullscreen: int [readonly] (Hyprland's mode: 0 none · 1 maximized · 2 fullscreen · 3 both)
 *   - floating: bool [readonly]
 *   - monitor: string [readonly] (monitor name, = ShellScreen.name)
 *   - workspace: string [readonly] (workspace name; special ones start with "special:")
 *   - rounding / border: real [readonly] (decoration.rounding and general.border_size)
 *   - mode: string [readonly] (Settings.windowFrame: "escuadras" · "hilo" · "nada")
 *   - stamp: real [readonly] (ms of the last geometry change; the view snaps instead of easing when two come quickly,
 *       i.e. while a window is being dragged or resized)
 *   - interval: real [readonly] (ms between the last two geometry changes)
 *
 * Functions:
 *   - parse(line: string): var (one feed line → { address, x, y, … } or null for "none" / garbage; pure, tested)
 *   - shownOn(screenName: string): bool (the frame belongs on that monitor: focused window there, not fullscreen,
 *       not the drop-down terminal — that one is joined to the island — and the frame is not off)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string feedPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/dragon-window-frame`

    property bool present: false
    property string address: ""
    property real winX: 0
    property real winY: 0
    property real winW: 0
    property real winH: 0
    property int fullscreen: 0
    property bool floating: false
    property string monitor: ""
    property string workspace: ""
    property real rounding: 0
    property real border: 0
    property real stamp: 0
    property real interval: 1e9
    readonly property string mode: Settings.windowFrame

    function parse(line: string): var {
        const t = (line || "").trim();
        if (t.length === 0 || t === "none") return null;
        const f = t.split("\t");
        if (f.length < 11) return null;
        const n = i => Number(f[i]);
        if ([1, 2, 3, 4].some(i => !isFinite(n(i)))) return null;
        return {
            address: f[0], x: n(1), y: n(2), width: n(3), height: n(4),
            fullscreen: n(5) | 0, floating: f[6] === "1", monitor: f[7], workspace: f[8],
            rounding: isFinite(n(9)) ? n(9) : 0, border: isFinite(n(10)) ? n(10) : 0
        };
    }

    function shownOn(screenName: string): bool {
        return root.present && root.mode !== "nada" && root.monitor === screenName
            && (root.fullscreen & 2) === 0 && root.workspace !== "special:dropdown"
            && root.winW > 0 && root.winH > 0;
    }

    function _apply(text: string): void {
        // an empty read can catch Hyprland mid-write: keep what we have, the next change event brings the line
        if ((text || "").trim().length === 0) return;
        const g = root.parse(text);
        if (!g) { root.present = false; return; }
        const changed = g.x !== root.winX || g.y !== root.winY || g.width !== root.winW || g.height !== root.winH
                        || g.address !== root.address || g.border !== root.border;
        root.address = g.address;
        root.fullscreen = g.fullscreen;
        root.floating = g.floating;
        root.monitor = g.monitor;
        root.workspace = g.workspace;
        root.rounding = g.rounding;
        root.border = g.border;
        root.winX = g.x; root.winY = g.y; root.winW = g.width; root.winH = g.height;
        root.present = true;
        // last: the view reads the new geometry when the stamp changes
        if (changed) {
            const now = Date.now();
            root.interval = now - root.stamp;
            root.stamp = now;
        }
    }

    FileView {
        id: feed
        path: root.feedPath
        printErrors: false
        watchChanges: true
        blockLoading: true
        onFileChanged: { feed.reload(); root._apply(feed.text()); }
        onLoaded: root._apply(feed.text())
        onLoadFailed: root.present = false
    }
}
