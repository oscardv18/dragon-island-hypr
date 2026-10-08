// =============================================================================
// dragon-island — EditorWatcher.qml
// Service: code editors that are open (left bottom island)
// =============================================================================
/**
 * GUI editors: Hyprland windows whose class matches AppsConfig.editorClasses (VS Code, Cursor, Zed, Kate, JetBrains…).
 * Terminal editors (nvim, helix, emacs…): processes whose name matches AppsConfig.editorProcesses, read with `ps`
 * only while the Apps tab is open (10 s, plus once on reveal). They have no window of their own, so they are
 * listed but cannot be focused.
 *
 * Properties:
 *   - editors: list<var> [readonly] ({ key, name, kind: "window" | "process", count, toplevel (first window | null),
 *       workspace (label of its workspace, "" for processes) })   one entry per editor, windows of one class are grouped
 *   - count: int [readonly] (windows + terminal processes)
 *
 * Functions:
 *   - setWatching(on: bool): void
 *   - focus(editor): void   (focuses its first window; nothing for processes)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import ".."

Singleton {
    id: root

    property bool _watching: false
    property var _procs: ({})        // name → count
    function setWatching(on: bool): void {
        if (root._watching === on) return;
        root._watching = on;
        if (on) ps.running = true;
    }

    Process {
        id: ps
        command: ["ps", "-eo", "comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const l of text.split("\n")) { const n = l.trim(); if (n) map[n] = (map[n] ?? 0) + 1; }
                root._procs = map;
            }
        }
    }
    Timer { interval: 10000; running: root._watching; repeat: true; onTriggered: if (!ps.running) ps.running = true }

    readonly property var editors: {
        const out = [], byClass = {};
        for (const t of Hyprland.toplevels.values) {
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            if (!AppsConfig.anyMatches(AppsConfig.editorClasses, cls)) continue;
            const key = cls.toLowerCase();
            if (byClass[key]) { byClass[key].count++; continue; }
            const de = DesktopEntries.heuristicLookup(cls);
            const ws = t.workspace;
            byClass[key] = { key: `w:${key}`, name: de?.name || cls, kind: "window", count: 1, toplevel: t, workspace: ws ? (ws.name ?? `${ws.id}`) : "" };
            out.push(byClass[key]);
        }
        if (root._watching) {
            for (const n of Object.keys(root._procs))
                if (AppsConfig.anyMatches(AppsConfig.editorProcesses, n))
                    out.push({ key: `p:${n}`, name: n, kind: "process", count: root._procs[n], toplevel: null, workspace: "" });
        }
        return out;
    }
    readonly property int count: editors.reduce((a, e) => a + e.count, 0)

    function focus(editor): void { if (editor?.toplevel) Hypr.focusWindow(editor.toplevel.address); }
}
