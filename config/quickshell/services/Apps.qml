// =============================================================================
// dragon-island — Apps.qml
// Service: desktop entries for the launcher (fuzzy search + launch frequency)
// =============================================================================
/**
 * Properties:
 *   - list: list<DesktopEntry> [readonly] (alphabetical, NoDisplay/Hidden excluded)
 *   - count: int [readonly]
 *
 * Functions:
 *   - search(query: string): list<DesktopEntry>
 *       empty query → most launched first, then alphabetical
 *       otherwise fuzzy: name prefix > word prefix > substring > subsequence,
 *       also matching genericName / keywords / comment; ties broken by launch count
 *   - launch(entry: DesktopEntry): void (terminal apps run inside kitty)
 *   - launchById(id: string): void
 *   - iconFor(entry: DesktopEntry): string
 *
 * Signals:
 *   - launched(name: string)
 *
 * Launch counts persist in $XDG_STATE_HOME/quickshell/<shell>/app-usage.json (Quickshell.statePath).
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var list: DesktopEntries.applications.values.slice()
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    readonly property int count: list.length

    property var usage: ({})

    FileView {
        id: usageFile
        path: Quickshell.statePath("app-usage.json")
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(usageFile.text()) || {}; } catch (e) { root.usage = {}; }
        }
    }

    function scoreText(text: string, q: string): int {
        if (!text) return 0;
        const t = text.toLowerCase();
        if (t === q) return 1000;
        if (t.startsWith(q)) return 800;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 600;
        const idx = t.indexOf(q);
        if (idx >= 0) return 400 - Math.min(idx, 100);
        // subsequence: every query char in order; denser matches score higher
        let pos = -1, gaps = 0;
        for (const ch of q) {
            const next = t.indexOf(ch, pos + 1);
            if (next < 0) return 0;
            if (pos >= 0) gaps += next - pos - 1;
            pos = next;
        }
        return Math.max(1, 200 - gaps * 5);
    }

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();
        const uses = e => root.usage[e.id] || 0;
        if (q.length === 0) {
            return root.list.slice().sort((a, b) => (uses(b) - uses(a)) || (a.name || "").localeCompare(b.name || ""));
        }
        const scored = [];
        for (const e of root.list) {
            let s = scoreText(e.name, q);
            s = Math.max(s, Math.round(scoreText(e.genericName, q) * 0.6));
            for (const k of (e.keywords || [])) s = Math.max(s, Math.round(scoreText(k, q) * 0.5));
            if ((e.comment || "").toLowerCase().includes(q)) s = Math.max(s, 120);
            if (s > 0) scored.push({ e: e, s: s + Math.min(uses(e), 50) * 2 });
        }
        scored.sort((a, b) => (b.s - a.s) || (a.e.name || "").localeCompare(b.e.name || ""));
        return scored.map(x => x.e);
    }

    function launch(entry): void {
        if (!entry) return;
        if (entry.runInTerminal) Quickshell.execDetached(["kitty", "-e"].concat(entry.command));
        else entry.execute();
        const u = Object.assign({}, root.usage);
        u[entry.id] = (u[entry.id] || 0) + 1;
        root.usage = u;
        usageFile.setText(JSON.stringify(u));
        root.launched(entry.name);
    }

    function launchById(id: string): void {
        launch(DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id));
    }

    function iconFor(entry): string {
        if (!entry) return "";
        return Quickshell.iconPath(entry.icon || "", "application-x-executable");
    }

    signal launched(name: string)
}
