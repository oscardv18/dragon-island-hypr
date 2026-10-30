// =============================================================================
// dragon-island — WorkspacePreview.qml
// Service: state of the workspace hover preview (which workspace, where, on which monitor)
// =============================================================================
/**
 * The workspace pills call show() / hide(); the preview window (modules/bar/PreviewWindow.qml) follows
 * `open`. hide() waits a moment so the pointer can travel from the pill to the preview card, keep() (the
 * card is hovered) cancels it.
 *
 * Properties:
 *   - open: bool [readonly]
 *   - wsId: int [readonly]
 *   - anchorX: real [readonly] (screen x of the pill's centre)
 *   - screenName: string [readonly]
 *   - windows: list<var> [readonly] (Hypr.windowsOn(wsId))
 *
 * Functions:
 *   - show(wsId: int, anchorX: real, screenName: string): void   (no preview for an empty workspace)
 *   - hide(): void     keep(): void     close(): void
 *   - layout(wsId: int): list<var> (the windows of that workspace with their real geometry, `hyprctl clients`, relative
 *       to their monitor: { toplevel, address, title, appClass, appName, icon, floating, x, y, w, h } — x … h are 0–1
 *       fractions of the monitor, so a card of any size draws them in proportion; floating ones last = on top)
 *   - dominantApp(wsId: int): string (name of the app covering most of the workspace, "" if empty)
 *   Hypr.refresh() first when the geometry must be fresh (the overview does it when it opens).
 */
pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool open: false
    property int wsId: 0
    property real anchorX: 0
    property string screenName: ""
    readonly property var windows: root.open ? Hypr.windowsOn(root.wsId) : []

    function layout(id: int): var {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        if (!ws) return [];
        const mon = ws.monitor?.lastIpcObject ?? {};
        const scale = mon.scale || 1;
        const mx = mon.x ?? 0, my = mon.y ?? 0;
        const mw = (mon.width || 1920) / scale, mh = (mon.height || 1080) / scale;
        return ws.toplevels.values.map(t => {
            const o = t.lastIpcObject ?? {};
            const at = o.at ?? [mx, my], size = o.size ?? [mw, mh];
            const cls = t.wayland?.appId || o.class || "";
            const entry = cls ? DesktopEntries.heuristicLookup(cls) : null;
            return {
                toplevel: t, address: t.address, title: t.title || "", appClass: cls, appName: entry?.name || cls,
                icon: Hypr.iconFor(cls), floating: o.floating ?? false,
                x: (at[0] - mx) / mw, y: (at[1] - my) / mh, w: size[0] / mw, h: size[1] / mh
            };
        }).sort((a, b) => (a.floating ? 1 : 0) - (b.floating ? 1 : 0));
    }

    function dominantApp(id: int): string {
        const area = {};
        for (const w of root.layout(id)) area[w.appName] = (area[w.appName] || 0) + w.w * w.h;
        let best = "", max = 0;
        for (const k in area) if (area[k] > max) { max = area[k]; best = k; }
        return best;
    }

    function show(id: int, x: real, screen: string): void {
        hideTimer.stop();
        if (Hypr.windowsOn(id).length === 0) { root.close(); return; }
        root.wsId = id;
        root.anchorX = x;
        root.screenName = screen;
        showTimer.restart();
    }

    function hide(): void { showTimer.stop(); hideTimer.restart(); }
    function keep(): void { hideTimer.stop(); }
    function close(): void { showTimer.stop(); hideTimer.stop(); root.open = false; }

    // a short delay before opening, so crossing the pills does not flash previews
    Timer { id: showTimer; interval: 350; onTriggered: root.open = true }
    Timer { id: hideTimer; interval: 280; onTriggered: root.open = false }
}
