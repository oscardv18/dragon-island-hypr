// =============================================================================
// dragon-island — Dock.qml
// Service: the arc dock — pinned apps, open apps, minimised windows, smart hiding, downloads stack
// =============================================================================
/**
 * Properties:
 *   - position: string ("bottom" | "left" | "right"), pinnedIds: list<string> [readonly]
 *   - alwaysVisible: bool (SUPER+X)
 *   - pinnedItems / openItems: list<var> [readonly] (left and right halves of the arc)
 *       item: { key, id, name, icon, windows: list<HyprlandToplevel>, count, minimizedOnly, pinned, badge, entry }
 *   - workspaceFree: bool [readonly] (the current workspace has no tiled / fullscreen window: the dock may show)
 *   - wanted: bool [readonly] (visible: workspaceFree || alwaysVisible || hovered)
 *   - hovered: bool (hot zone or dock under the pointer; leaving waits Theme.dockHideDelay)
 *   - downloads: list<var> [readonly] ({ name, path }, newest first, refreshed on request)
 *
 * Functions:
 *   - activate(item): void       (focus, cycle through its windows, restore if minimised, launch if closed)
 *   - newInstance(item): void    pin(item) / unpin(item) / togglePin(item): void
 *   - closeAll(item): void       moveAllTo(item, ws: int): void
 *   - reorder(from: int, to: int): void (pinned apps)
 *   - minimizeActive(): void     (window → special workspace "minimized"; shown dimmed in the dock, click restores)
 *   - togglePinned(): void       hover(on: bool): void     refreshDownloads(): void   open(path): void
 *   - setPosition(p: string): void
 *
 * IPC (`qs ipc call dock <fn>`): toggle() (always visible on/off, SUPER+X), minimize() (SUPER+M), position(p: string)
 * State: ~/.local/state/dragon-island/dock.json { pinned: [desktop entry ids], position, alwaysVisible }
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import ".."

Singleton {
    id: root

    property string position: "bottom"
    property var pinnedIds: []
    property bool alwaysVisible: false
    property bool hovered: false
    property bool _loaded: false

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // ---------------------------------------------------------------- windows → items
    function _entryFor(cls: string): var {
        return cls ? (DesktopEntries.heuristicLookup(cls) ?? null) : null;
    }

    readonly property var _windows: Hyprland.toplevels.values.map(t => {
        const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
        const entry = root._entryFor(cls);
        return {
            toplevel: t,
            cls: cls,
            key: entry ? entry.id : cls,
            entry: entry,
            minimized: (t.workspace?.name ?? "").startsWith("special:minimized"),
            floating: t.lastIpcObject?.floating ?? false
        };
    }).filter(w => w.cls.length > 0)

    function _unreadFor(name: string, id: string): int {
        const n = (name || "").toLowerCase(), i = (id || "").toLowerCase();
        return Notifs.unreadList().filter(x => {
            const app = (x.appName || "").toLowerCase(), de = (x.desktopEntry || "").toLowerCase();
            return (de.length > 0 && (de === i || i.startsWith(de))) || (app.length > 0 && (app === n || i.includes(app)));
        }).length;
    }

    function _item(key: string, entry, pinned: bool): var {
        const wins = root._windows.filter(w => w.key === key);
        const name = entry?.name || (wins[0]?.cls ?? key);
        return {
            key: key,
            id: entry?.id ?? key,
            name: name,
            icon: entry ? Apps.iconFor(entry) : Quickshell.iconPath(key.toLowerCase(), "application-x-executable"),
            windows: wins.map(w => w.toplevel),
            count: wins.length,
            minimizedOnly: wins.length > 0 && wins.every(w => w.minimized),
            pinned: pinned,
            badge: root._unreadFor(name, entry?.id ?? key),
            entry: entry
        };
    }

    // depends on the entries list too: at login the pinned ids can load before the desktop entries are scanned
    readonly property var pinnedItems: {
        const known = DesktopEntries.applications.values;
        return root.pinnedIds
            .map(id => { const e = known.find(x => x.id === id) ?? DesktopEntries.heuristicLookup(id); return e ? root._item(e.id, e, true) : null; })
            .filter(i => i !== null);
    }

    readonly property var openItems: {
        const pinnedKeys = root.pinnedItems.map(i => i.key);
        const seen = [], out = [];
        for (const w of root._windows) {
            if (pinnedKeys.indexOf(w.key) >= 0 || seen.indexOf(w.key) >= 0) continue;
            seen.push(w.key);
            out.push(root._item(w.key, w.entry, false));
        }
        return out;
    }

    // ---------------------------------------------------------------- smart hiding
    // visible while the current workspace has no tiled or fullscreen window (empty, or only floating windows)
    property bool workspaceFree: true

    function _evaluate(): void {
        const ws = Hyprland.focusedWorkspace;
        if (!ws) { root.workspaceFree = true; return; }
        const wins = ws.toplevels.values;
        root.workspaceFree = wins.every(t => (t.lastIpcObject?.floating ?? false));
    }

    Timer { id: settle; interval: 180; onTriggered: { Hyprland.refreshToplevels(); recheck.restart(); } }
    Timer { id: recheck; interval: 120; onTriggered: root._evaluate() }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            switch (e.name) {
                case "openwindow": case "closewindow": case "movewindow": case "movewindowv2": case "workspace":
                case "workspacev2": case "fullscreen": case "changefloatingmode": case "focusedmon": settle.restart(); break;
            }
        }
    }
    Component.onCompleted: settle.restart()

    readonly property bool wanted: workspaceFree || alwaysVisible || hovered

    function hover(on: bool): void {
        if (on) { hideTimer.stop(); root.hovered = true; }
        else hideTimer.restart();
    }
    Timer { id: hideTimer; interval: Theme.dockHideDelay; onTriggered: root.hovered = false }

    // ---------------------------------------------------------------- actions
    function _focus(t): void { Hypr.focusWindow(t.address); }

    function activate(item): void {
        if (!item) return;
        if (item.count === 0) { Apps.launch(item.entry ?? DesktopEntries.heuristicLookup(item.key)); return; }
        const wins = item.windows;
        if (item.minimizedOnly) { root._restore(wins[0]); return; }
        const visible = wins.filter(t => !(t.workspace?.name ?? "").startsWith("special:minimized"));
        const at = visible.findIndex(t => t.activated);
        root._focus(visible[(at + 1) % visible.length]);   // already focused → the next window of the app
    }

    function _restore(t): void {
        const ws = Hyprland.focusedWorkspace?.id ?? 1;
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${Hypr.addr(t.address)}" })`);
        Hypr.focusWindow(t.address);
    }

    function newInstance(item): void {
        const e = item?.entry;
        if (e) Apps.launch(e);
    }

    function closeAll(item): void {
        for (const t of (item?.windows ?? [])) Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${Hypr.addr(t.address)}" })`);
    }

    function moveAllTo(item, ws: int): void {
        for (const t of (item?.windows ?? [])) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${Hypr.addr(t.address)}", follow = false })`);
    }

    function minimizeActive(): void {
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false })');
    }

    function pin(item): void {
        if (!item?.entry || root.pinnedIds.indexOf(item.id) >= 0) return;
        root.pinnedIds = root.pinnedIds.concat([item.id]);
        root._save();
    }
    function unpin(item): void {
        root.pinnedIds = root.pinnedIds.filter(i => i !== item?.id);
        root._save();
    }
    function togglePin(item): void { if (item?.pinned) root.unpin(item); else root.pin(item); }

    function reorder(from: int, to: int): void {
        const list = root.pinnedIds.slice();
        if (from < 0 || from >= list.length) return;
        to = Math.max(0, Math.min(list.length - 1, to));
        list.splice(to, 0, list.splice(from, 1)[0]);
        root.pinnedIds = list;
        root._save();
    }

    function togglePinned(): void { root.alwaysVisible = !root.alwaysVisible; root._save(); }
    function setPosition(p: string): void {
        if (["bottom", "left", "right"].indexOf(p) < 0) return;
        root.position = p;
        root._save();
    }

    // ---------------------------------------------------------------- downloads
    property var downloads: []

    function refreshDownloads(): void { if (!lister.running) lister.running = true; }
    function open(path: string): void { Quickshell.execDetached(["xdg-open", path]); }

    Process {
        id: lister
        command: ["sh", "-c", "d=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$d\" ] || d=\"$HOME/Downloads\"; ls -1t \"$d\" 2>/dev/null | head -n 6 | while IFS= read -r f; do printf '%s\\t%s\\n' \"$f\" \"$d/$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.downloads = this.text.split("\n").filter(l => l.includes("\t")).map(l => { const f = l.split("\t"); return { name: f[0], path: f[1] }; });
            }
        }
    }

    // ---------------------------------------------------------------- state file
    function _save(): void {
        stateFile.setText(JSON.stringify({ pinned: root.pinnedIds, position: root.position, alwaysVisible: root.alwaysVisible }, null, 2));
    }

    FileView {
        id: stateFile
        path: `${root.stateHome}/dragon-island/dock.json`
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(stateFile.text()) || {};
                root.pinnedIds = d.pinned ?? [];
                root.position = d.position ?? "bottom";
                root.alwaysVisible = d.alwaysVisible ?? false;
            } catch (e) { root._defaults(); }
            root._loaded = true;
        }
        onLoadFailed: { root._defaults(); root._loaded = true; }
    }

    // first run: the terminal, the browser and the file manager, if they are installed
    function _defaults(): void {
        const wanted = ["com.mitchellh.ghostty", "brave-browser", "org.kde.dolphin"];
        root.pinnedIds = wanted.filter(id => DesktopEntries.byId(id) !== null);
        root._save();
    }

    IpcHandler {
        target: "dock"
        function toggle(): void { root.togglePinned(); }
        function minimize(): void { root.minimizeActive(); }
        function position(p: string): void { root.setPosition(p); }
    }
}
