// =============================================================================
// dragon-island — BarMetrics.qml
// Service: where the bar islands end, per monitor, so the notch never overlaps them.
// =============================================================================
/**
 * Each Bar reports the screen-local x of the left island's right edge and of the right island's
 * left edge. The collapsed notch lives in the free gap between them, Theme.notchGap away from each
 * island; it stays centred on the screen unless that would overlap an island, then it slides.
 *
 * Functions:
 *   - report(screenName: string, leftEnd: real, rightStart: real): void
 *   - minX(screenName: string): real          (leftmost x the collapsed notch may reach)
 *   - maxX(screenName: string): real          (rightmost x its right edge may reach)
 *   - maxNotchWidth(screenName: string, screenWidth: real): real
 *   - notchX(screenName: string, screenWidth: real, w: real): real (x of a collapsed notch of width w)
 *   - reportNotch(screenName: string, x: real, w: real): void (Notch.qml: where the collapsed notch is drawn)
 *
 * IPC (`qs ipc call barmetrics <fn>`): dump(): string (per monitor: left island end, notch x / width, right island
 *   start and the free room on each side of the notch; used to check that nothing overlaps)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property var _edges: ({})   // screen name → { l, r }
    property var _notch: ({})   // screen name → { x, w }

    function reportNotch(screenName: string, x: real, w: real): void {
        const n = Object.assign({}, root._notch);
        n[screenName] = { x: Math.round(x), w: Math.round(w) };
        root._notch = n;
    }

    IpcHandler {
        target: "barmetrics"
        function dump(): string {
            const out = [];
            for (const name of Object.keys(root._edges)) {
                const e = root._edges[name], n = root._notch[name] ?? { x: -1, w: -1 };
                out.push(`${name} left=${Math.round(e.l)} notch=${n.x}+${n.w} right=${Math.round(e.r)} gapL=${n.x - Math.round(e.l)} gapR=${Math.round(e.r) - n.x - n.w}`);
            }
            return out.join("\n");
        }
    }

    function report(screenName: string, leftEnd: real, rightStart: real): void {
        const e = Object.assign({}, root._edges);
        e[screenName] = { l: leftEnd, r: rightStart };
        root._edges = e;
    }

    function minX(screenName: string): real { return (root._edges[screenName]?.l ?? 0) + Theme.notchGap; }
    function maxX(screenName: string): real { return (root._edges[screenName]?.r ?? 0) - Theme.notchGap; }

    function maxNotchWidth(screenName: string, screenWidth: real): real {
        if (!root._edges[screenName]) return Theme.notchMinWidth;
        return Math.max(Theme.notchMinWidth, maxX(screenName) - minX(screenName));
    }

    function notchX(screenName: string, screenWidth: real, w: real): real {
        if (!root._edges[screenName]) return (screenWidth - w) / 2;
        return Math.max(minX(screenName), Math.min((screenWidth - w) / 2, maxX(screenName) - w));
    }
}
