// =============================================================================
// dragon-island — WallPalette.qml
// Service: the palette taken from the wallpaper (named WallPalette: QtQuick 6 already has a `Palette` type, which
// shadows a singleton of that name). bin/dragon-palette (the only thing that makes colours) writes
// ~/.local/state/dragon-island/palette.json; this service only reads it and runs that command.
// =============================================================================
/**
 * palette.json (version 1): { source, sourceHash, fallback, accent, accentSoft, accentDeep, glow, onAccent, tint,
 * swatches: [5 × "#RRGGBB"] }. ok / warn / danger are never in it: they stay fixed in Theme.
 * A missing, unreadable or invalid file (any colour that is not #RRGGBB) means ready = false: Theme keeps the Dragon
 * accent and nothing is logged.
 *
 * Properties:
 *   - ready: bool [readonly] (a valid palette.json is loaded)
 *   - accent, accentSoft, accentDeep, glow, onAccent, tint: color [readonly] (meaningless while !ready)
 *   - swatches: list<color> [readonly] (5 colours of the wallpaper, most present first; [] while !ready)
 *   - fallback: bool [readonly] (the wallpaper was too dull: dragon-palette returned the Dragon palette)
 *   - source: string [readonly] (the image it was made from)
 *   - active: bool [readonly] (Settings.wallpaperPalette && ready && !fallback: Theme follows this palette)
 *   - busy: bool [readonly] (a dragon-palette generate / reset is running)
 *
 * Functions:
 *   - setEnabled(on: bool): void (saves Settings.wallpaperPalette; on → regenerate(), off → dragon-palette reset)
 *   - regenerate(): void (generate from ~/.cache/dragon-island/current-wallpaper; nothing while the setting is off)
 *
 * Theme reads this service only through the Bindings in shell.qml (Theme stays the single source of tokens).
 * The wallpaper change itself runs dragon-palette from scripts/wallpapers.sh (Wallpaper.apply passes the flags).
 *
 * IPC (`qs ipc call palette <fn>`): enabled(on: bool), regenerate(), current(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string path: `${stateHome}/dragon-island/palette.json`
    readonly property string bin: `${home}/.local/bin/dragon-palette`
    readonly property string currentWallpaper: `${Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"}/dragon-island/current-wallpaper`

    property var _p: null
    readonly property bool ready: _p !== null
    readonly property color accent: _p?.accent ?? "transparent"
    readonly property color accentSoft: _p?.accentSoft ?? "transparent"
    readonly property color accentDeep: _p?.accentDeep ?? "transparent"
    readonly property color glow: _p?.glow ?? "transparent"
    readonly property color onAccent: _p?.onAccent ?? "transparent"
    readonly property color tint: _p?.tint ?? "transparent"
    readonly property var swatches: _p?.swatches ?? []
    readonly property bool fallback: _p?.fallback ?? false
    readonly property string source: _p?.source ?? ""
    readonly property bool active: Settings.wallpaperPalette && ready && !fallback
    readonly property bool busy: runner.running

    readonly property var _keys: ["accent", "accentSoft", "accentDeep", "glow", "onAccent", "tint"]
    function _hex(v): bool { return typeof v === "string" && /^#[0-9A-Fa-f]{6}$/.test(v); }

    function _parse(text: string): var {
        let d;
        try { d = JSON.parse(text); } catch (e) { return null; }
        if (!d || typeof d !== "object" || d.version !== 1) return null;
        for (const k of root._keys) if (!root._hex(d[k])) return null;
        const sw = Array.isArray(d.swatches) ? d.swatches.filter(c => root._hex(c)) : [];
        return {
            accent: d.accent, accentSoft: d.accentSoft, accentDeep: d.accentDeep, glow: d.glow, onAccent: d.onAccent, tint: d.tint,
            swatches: sw.slice(0, 5), fallback: d.fallback === true, source: typeof d.source === "string" ? d.source : ""
        };
    }

    FileView {
        id: file
        path: root.path
        printErrors: false
        watchChanges: true
        onFileChanged: file.reload()
        onLoaded: root._p = root._parse(file.text())
        onLoadFailed: root._p = null
    }

    // one dragon-palette run at a time; the latest request wins
    property var _queue: null
    Process {
        id: runner
        onExited: {
            const q = root._queue;
            root._queue = null;
            if (q) root._exec(q);
            else file.reload();   // reset deletes the file: watchChanges does not always see a deletion
        }
    }
    function _exec(script: string): void {
        if (runner.running) { root._queue = script; return; }
        // nice: the palette must never compete with the wallpaper transition or the desktop
        runner.exec(["nice", "-n", "10", "sh", "-c", script, "sh", root.bin, root.currentWallpaper]);
    }

    function regenerate(): void {
        if (!Settings.wallpaperPalette) return;
        root._exec('"$1" generate "$2" --quiet');
    }

    function setEnabled(on: bool): void {
        Settings.setWallpaperPalette(on);
        if (on) Qt.callLater(root.regenerate);   // after the setting is saved: regenerate reads it
        else root._exec('"$1" reset --quiet');
    }

    IpcHandler {
        target: "palette"
        function enabled(on: bool): void { root.setEnabled(on); }
        function regenerate(): void { root.regenerate(); }
        function current(): string {
            if (!root.ready) return "ready=false";
            return [`ready=true`, `active=${root.active}`, `fallback=${root.fallback}`, `source=${root.source}`,
                    `accent=${root._p.accent}`, `swatches=${root._p.swatches.join(" ")}`].join("\n");
        }
    }
}
