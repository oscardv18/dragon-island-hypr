// =============================================================================
// dragon-island — Switcher.qml
// Service: the orbital Alt+Tab (docs/design/10-alttab.png): window list, choice, filters, the quick tap
// =============================================================================
/**
 * Hyprland (config/hypr/binds.lua, only while Settings.switcherOrbital):
 *   ALT + Tab → `qs ipc call switcher next`   ALT + SHIFT + Tab → `… prev`   releasing Alt (release bind) → `… confirm`
 * The switcher window (modules/switcher/) also confirms on its own Alt release, cancels on Esc.
 * Quick tap: the first `next` captures the windows in MRU order and picks the previous one; the ring only shows after
 * Theme.switcherShowDelay. A `confirm` before that focuses the previous window without showing anything.
 *
 * Properties:
 *   - active: bool [readonly]   (between the first next / prev and confirm / cancel)
 *   - shown: bool [readonly]    (the ring is on screen: ShellState panel "switcher")
 *   - windows: list<var> [readonly] (captured at the start, Hypr.mruWindows() items)
 *   - filter: string [readonly] ("all" | "workspace" | "app")
 *   - filterWorkspace: int [readonly] (the workspace of the "workspace" filter: the focused one, or 1–5)
 *   - list: list<var> [readonly] (windows after the filter; "app" = the most recent window of each app)
 *   - index: int [readonly]     (the chosen one in `list`)
 *   - chosen: var [readonly]
 *   - counts: var [readonly]    ({ all, workspace, app })
 *
 * Functions:
 *   - next(): void   prev(): void   step(delta: int): void
 *   - confirm(): void (focus the chosen window and close)   cancel(): void
 *   - setFilter(f: string): void   filterTo(ws: int): void (keys 1–5)
 *   - closeChosen(): void (Q: closes that window, keeps the switcher open)
 *   - pick(i: int): void (click on a card)
 *
 * IPC (`qs ipc call switcher <fn>`): next(), prev(), confirm(), cancel()
 * Settings.switcherOrbital changing → `hyprctl reload`, so binds.lua binds or frees Alt + Tab.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool active: false
    readonly property bool shown: ShellState.openPanel === "switcher"
    property var windows: []
    property string filter: "all"
    property int filterWorkspace: 0
    property int index: 0

    readonly property var counts: ({
        all: root.windows.length,
        workspace: root.windows.filter(w => w.workspace === Hypr.focusedWorkspaceId).length,
        app: root._byApp(root.windows).length
    })
    function _byApp(list): var {
        const seen = {};
        return list.filter(w => seen[w.entryId] ? false : (seen[w.entryId] = true));
    }
    readonly property var list: root.filter === "workspace" ? root.windows.filter(w => w.workspace === root.filterWorkspace)
                              : root.filter === "app" ? root._byApp(root.windows)
                              : root.windows
    readonly property var chosen: root.list.length > 0 ? root.list[Math.max(0, Math.min(root.index, root.list.length - 1))] : null

    function _start(first: int): void {
        root.windows = Hypr.mruWindows();
        root.filter = "all";
        root.filterWorkspace = Hypr.focusedWorkspaceId;
        root.index = root.windows.length > 1 ? (first > 0 ? 1 : root.windows.length - 1) : 0;
        root.active = true;
        showTimer.restart();
    }

    function step(delta: int): void {
        const n = root.list.length;
        if (n === 0) return;
        root.index = ((root.index + delta) % n + n) % n;
    }
    function next(): void { if (!root.active) root._start(1); else root.step(1); }
    function prev(): void { if (!root.active) root._start(-1); else root.step(-1); }

    function confirm(): void {
        if (!root.active) return;
        const w = root.chosen;
        root._end();
        if (w) Hypr.focusWindow(w.address);
    }
    function cancel(): void { if (root.active) root._end(); }
    function _end(): void {
        showTimer.stop();
        root.active = false;
        if (root.shown) ShellState.close();
    }

    function setFilter(f: string): void {
        if (["all", "workspace", "app"].indexOf(f) < 0) return;
        if (f === "workspace" && root.filter !== "workspace") root.filterWorkspace = Hypr.focusedWorkspaceId;
        root.filter = f;
        root.index = 0;
    }
    function filterTo(ws: int): void {
        root.filterWorkspace = ws;
        root.filter = "workspace";
        root.index = 0;
    }
    function pick(i: int): void { root.index = i; root.confirm(); }

    function closeChosen(): void {
        const w = root.chosen;
        if (!w) return;
        Hypr.closeWindow(w.address);
        root.windows = root.windows.filter(x => x.address !== w.address);
        if (root.index >= root.list.length) root.index = Math.max(0, root.list.length - 1);
    }

    // the ring appears only if Alt is still held after this
    Timer {
        id: showTimer
        interval: Theme.switcherShowDelay
        onTriggered: if (root.active && root.windows.length > 0) ShellState.open("switcher", "")
    }
    // another panel took over (or a click outside closed it): the switch is off
    onShownChanged: if (!shown && active && !showTimer.running) { active = false; }

    // Settings › Launcher › «Alt+Tab orbital»: binds.lua reads the key at load time
    // (not for the first read of settings.json at start-up: Hyprland already loaded binds.lua with it)
    readonly property real _born: Date.now()
    property bool _orbital: Settings.switcherOrbital
    on_OrbitalChanged: if (Date.now() - root._born > 3000) reloadTimer.restart()
    Timer {
        id: reloadTimer
        interval: 400          // after settings.json is written
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }

    IpcHandler {
        target: "switcher"
        function next(): void { root.next(); }
        function prev(): void { root.prev(); }
        function confirm(): void { root.confirm(); }
        function cancel(): void { root.cancel(); }
    }
}
