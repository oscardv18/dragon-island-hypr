// =============================================================================
// dragon-island — Hypr.qml
// Service: Hyprland compositor state & dispatch (Lua dispatcher syntax on 0.55+)
// =============================================================================
/**
 * Properties:
 *   - usingLua: bool [readonly]
 *   - focusedWorkspaceId: int [readonly]
 *   - focusedMonitorName: string [readonly]
 *   - activeTitle: string [readonly]
 *   - activeClass: string [readonly] (Wayland app id, falls back to the X11/IPC class)
 *   - activeIcon: string [readonly] (image source for the active app, "" if none)
 *   - hasActiveWindow: bool [readonly]
 *   - workspaceCount: int [readonly] (numbered pills shown in the bar, 5)
 *   - workspaces: list<var> [readonly] (1..5: { id, name, active, occupied, urgent, windows, visible })
 *       active  = focused workspace; visible = shown on some monitor (multi-monitor)
 *   - monitors: ObjectModel<HyprlandMonitor> [readonly]
 *
 *   - submap: string [readonly] (active submap, "" = default; from the `submap` event)
 *   - mru: list<string> [readonly] (window addresses, last focused first, from the activewindowv2 events since the shell
 *       started; windows never focused since then follow Hyprland's focusHistoryID)
 *   - lastActive: var [readonly] (address → ms timestamp of the last moment it was the active window)
 *   - activeFloating / activePinned: bool [readonly] (of the active window)
 *
 * Functions:
 *   - windowsOn(id: int): list<var> (the windows of workspace id: { toplevel, address, title, appClass, icon, floating })
 *   - isTerminal(appClass: string): bool (Ghostty, kitty, foot, WezTerm, Konsole, Alacritty and our own terminal classes)
 *   - windowsByApp: var [readonly] (desktop entry id — or the class when there is no entry — → list of
 *       { toplevel, address, title, appClass, workspace }; special workspaces (minimized, drop-down) left out)
 *   - iconFor(appClass: string): string (image source of an app's icon)
 *   - focusWindow(address: string): void
 *   - closeWindow(address: string): void
 *   - moveWindowSilent(address: string, ws: int): void (to workspace ws without following it)
 *   - sendShortcut(mods: string, key: string, address: string): void (e.g. "CTRL", "V": paste into that window)
 *   - mruWindows(): list<var> (every window on a normal workspace, MRU order:
 *       { toplevel, address, title, appClass, appName, icon, entryId, workspace, lastActive, floating })
 *   - togglePin(): void (pinning needs a floating window)
 *   - focusWorkspace(id: int): void
 *   - focusRelative(delta: int): void (next/previous existing workspace, mouse wheel)
 *   - fullscreenOn(screen): bool      (active workspace of that monitor has a fullscreen window)
 *   - moveWindowToWorkspace(id: int): void
 *   - closeActiveWindow(): void
 *   - toggleFullscreen(): void
 *   - toggleFloat(): void
 *   - dispatch(cmd: string): void
 *   - monitorFor(screen): HyprlandMonitor
 *   - refresh(): void
 *
 * Signals:
 *   - workspaceChanged(id: int)
 *   - activeWindowChanged(title: string, appClass: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool usingLua: Hyprland.usingLua
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""

    // Hyprland.activeToplevel is a HyprlandToplevel: title is native, the app id lives on its Wayland handle
    readonly property var activeToplevel: Hyprland.activeToplevel
    readonly property bool hasActiveWindow: activeToplevel !== null && activeToplevel !== undefined
    readonly property string activeTitle: activeToplevel?.title ?? ""
    readonly property string activeClass: activeToplevel?.wayland?.appId || activeToplevel?.lastIpcObject?.class || ""
    readonly property string activeIcon: {
        if (activeClass.length === 0) return "";
        const entry = DesktopEntries.heuristicLookup(activeClass);
        return Quickshell.iconPath(entry?.icon || activeClass.toLowerCase(), "application-x-executable");
    }

    readonly property int workspaceCount: 5

    property string submap: ""
    readonly property bool activeFloating: activeToplevel?.lastIpcObject?.floating ?? false
    readonly property bool activePinned: activeToplevel?.lastIpcObject?.pinned ?? false

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // "submap>>name": empty name when it is reset
            if (event.name === "submap") root.submap = event.data;
            // floating / pin state of the active window is only fetched on request
            else if (event.name === "changefloatingmode" || event.name === "pin" || event.name === "activewindowv2") Hyprland.refreshToplevels();
            // focus history (Alt+Tab): "activewindowv2>>address" (no 0x prefix)
            if (event.name === "activewindowv2") root._focused(event.data);
        }
    }

    property var mru: []
    property var lastActive: ({})
    function _focused(address: string): void {
        const now = Date.now();
        const la = Object.assign({}, root.lastActive);
        if (root.mru.length > 0) la[root.mru[0]] = now;          // the one that just lost the focus
        if (address && address !== ",") {
            la[address] = now;
            root.mru = [address].concat(root.mru.filter(a => a !== address)).slice(0, 200);
        }
        root.lastActive = la;
    }

    function mruWindows(): var {
        const rank = t => {
            const i = root.mru.indexOf(t.address);
            return i >= 0 ? i : 1000 + (t.lastIpcObject?.focusHistoryID ?? 999);
        };
        return Hyprland.toplevels.values
            .filter(t => t.workspace && t.workspace.id >= 1)
            .sort((a, b) => rank(a) - rank(b))
            .map(t => {
                const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
                const entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
                return {
                    toplevel: t, address: t.address, title: t.title || "", appClass: cls,
                    appName: entry?.name || cls, entryId: entry?.id || cls, icon: root.iconFor(cls),
                    workspace: t.workspace.id, lastActive: root.lastActive[t.address] ?? 0,
                    floating: t.lastIpcObject?.floating ?? false
                };
            });
    }

    function closeWindow(address: string): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.window.close({ window = "address:${root.addr(address)}" })` : `closewindow address:${root.addr(address)}`);
    }

    function moveWindowSilent(address: string, ws: int): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.window.move({ window = "address:${root.addr(address)}", workspace = ${ws}, follow = false })`
                                        : `movetoworkspacesilent ${ws},address:${root.addr(address)}`);
    }

    function sendShortcut(mods: string, key: string, address: string): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.send_shortcut({ mods = "${mods}", key = "${key}", window = "address:${root.addr(address)}" })`
                                        : `sendshortcut ${mods}, ${key}, address:${root.addr(address)}`);
    }

    function iconFor(appClass: string): string {
        if (!appClass) return Quickshell.iconPath("application-x-executable");
        const entry = DesktopEntries.heuristicLookup(appClass);
        return Quickshell.iconPath(entry?.icon || appClass.toLowerCase(), "application-x-executable");
    }

    function windowsOn(id: int): var {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (!ws) return [];
        return ws.toplevels.values.map(t => {
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            return {
                toplevel: t,
                address: t.address,
                title: t.title,
                appClass: cls,
                icon: root.iconFor(cls),
                floating: t.lastIpcObject?.floating ?? false
            };
        });
    }

    // HyprlandToplevel.address has no 0x prefix; the dispatchers want one
    function addr(address: string): string { return address.startsWith("0x") ? address : `0x${address}`; }

    function focusWindow(address: string): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.focus({ window = "address:${root.addr(address)}" })` : `focuswindow address:${root.addr(address)}`);
    }

    function togglePin(): void {
        Hyprland.dispatch(root.usingLua ? 'hl.dsp.window.pin({ action = "toggle" })' : "pin");
    }

    function isTerminal(appClass: string): bool {
        return /^(com\.mitchellh\.ghostty.*|org\.dragonisland\.(herdr|dropdown|pkg|setup)|kitty|alacritty|foot|footclient|org\.wezfurlong\.wezterm|wezterm|org\.kde\.konsole|konsole)$/i.test(appClass || "");
    }

    readonly property var windowsByApp: {
        const map = {};
        for (const t of Hyprland.toplevels.values) {
            const ws = t.workspace;
            if (!ws || ws.id < 1) continue;
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            if (cls.length === 0) continue;
            const key = DesktopEntries.heuristicLookup(cls)?.id ?? cls;
            (map[key] = map[key] || []).push({ toplevel: t, address: t.address, title: t.title, appClass: cls, workspace: ws.id });
        }
        return map;
    }

    readonly property var workspaces: {
        const list = [];
        const all = Hyprland.workspaces.values;
        for (let i = 1; i <= root.workspaceCount; i++) {
            const ws = all.find(w => w.id === i) ?? null;
            const windows = ws ? ws.toplevels.values.length : 0;
            list.push({
                id: i,
                name: ws ? ws.name : `${i}`,
                active: root.focusedWorkspaceId === i,
                visible: ws ? ws.active : false,
                occupied: windows > 0,
                urgent: ws ? ws.urgent : false,
                windows: windows
            });
        }
        return list;
    }

    readonly property var monitors: Hyprland.monitors

    function dispatch(command: string): void {
        Hyprland.dispatch(command);
    }

    function focusWorkspace(id: int): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.focus({ workspace = ${id} })` : `workspace ${id}`);
    }

    function focusRelative(delta: int): void {
        const target = delta > 0 ? "e+1" : "e-1";
        Hyprland.dispatch(root.usingLua ? `hl.dsp.focus({ workspace = "${target}" })` : `workspace ${target}`);
    }

    function fullscreenOn(screen): bool {
        const mon = screen ? Hyprland.monitorFor(screen) : null;
        return mon?.activeWorkspace?.hasFullscreen ?? false;
    }

    function moveWindowToWorkspace(id: int): void {
        Hyprland.dispatch(root.usingLua ? `hl.dsp.window.move({ workspace = ${id} })` : `movetoworkspace ${id}`);
    }

    function closeActiveWindow(): void {
        Hyprland.dispatch(root.usingLua ? "hl.dsp.window.close()" : "killactive");
    }

    function toggleFullscreen(): void {
        Hyprland.dispatch(root.usingLua ? 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })' : "fullscreen 1");
    }

    function toggleFloat(): void {
        Hyprland.dispatch(root.usingLua ? 'hl.dsp.window.float({ action = "toggle" })' : "togglefloating");
    }

    function monitorFor(screen): var {
        return screen ? Hyprland.monitorFor(screen) : null;
    }

    function refresh(): void {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }

    signal workspaceChanged(id: int)
    signal activeWindowChanged(title: string, appClass: string)

    onFocusedWorkspaceIdChanged: root.workspaceChanged(root.focusedWorkspaceId)
    onActiveTitleChanged: root.activeWindowChanged(root.activeTitle, root.activeClass)
    Component.onCompleted: if (root.activeToplevel) root._focused(root.activeToplevel.address)
}
