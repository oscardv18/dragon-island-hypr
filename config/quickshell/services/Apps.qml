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
 *   - launch(entry: DesktopEntry): void (terminal apps run inside Ghostty)
 *   - launchById(id: string): void
 *   - iconFor(entry: DesktopEntry): string (a file:// URL when the icon is a file on disk, else the image provider)
 *
 * Signals:
 *   - launched(name: string)
 *
 *   - favorites: list<string> [readonly] (desktop entry ids, pinned first in the empty-query ring)
 *   - toggleFavorite(entry): void   isFavorite(entry): bool
 *   - ringEntries(query: string, max: int): list<DesktopEntry>
 *       empty query → favorites, then the most launched (max 16 by default); otherwise search(query)
 *   - calc(expr: string): string  ("" if it is not a plain arithmetic expression: digits and + - * / ( ) . % ^ only)
 *   - copy(text: string): void    (wl-copy)
 *   - runInTerminal(command: string): void (Ghostty, stays open until Enter)
 *
 * Launch counts and favorites persist in ~/.local/state/dragon-island/launcher.json
 * ({ "usage": { id: count }, "favorites": [id] }); the old Quickshell app-usage.json is read once if it is the only one.
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
    property var favorites: []

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    function _save(): void {
        usageFile.setText(JSON.stringify({ usage: root.usage, favorites: root.favorites }));
    }

    FileView {
        id: usageFile
        path: `${root.stateHome}/dragon-island/launcher.json`
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(usageFile.text()) || {};
                root.usage = d.usage || {};
                root.favorites = d.favorites || [];
            } catch (e) { root.usage = {}; root.favorites = []; }
        }
        onLoadFailed: legacy.reload()
    }

    // first run after the move: carry over the launch counts of the old file
    FileView {
        id: legacy
        path: Quickshell.statePath("app-usage.json")
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(legacy.text()) || {}; } catch (e) { root.usage = {}; }
        }
    }

    function isFavorite(entry): bool { return !!entry && root.favorites.indexOf(entry.id) >= 0; }

    function toggleFavorite(entry): void {
        if (!entry) return;
        root.favorites = root.isFavorite(entry) ? root.favorites.filter(i => i !== entry.id) : root.favorites.concat([entry.id]);
        root._save();
    }

    function ringEntries(query: string, max: int): var {
        const limit = max > 0 ? max : 16;
        if ((query || "").trim().length > 0) return root.search(query);
        const favs = root.favorites.map(id => root.list.find(e => e.id === id)).filter(e => e);
        const rest = root.search("").filter(e => favs.indexOf(e) < 0 && (root.usage[e.id] || 0) > 0);
        const all = favs.concat(rest);
        // few favourites / launches so far: fill the ring with the rest, alphabetically, so it is never sparse
        const filled = all.length >= 8 ? all : all.concat(root.list.filter(e => all.indexOf(e) < 0).slice(0, 12 - all.length));
        return filled.slice(0, limit);
    }

    function calc(expr: string): string {
        const e = (expr || "").trim();
        if (e.length === 0 || !/^[0-9+\-*\/().%^\s,]+$/.test(e)) return "";
        try {
            const v = Function(`"use strict"; return (${e.replace(/\^/g, "**").replace(/,/g, ".")});`)();
            if (typeof v !== "number" || !isFinite(v)) return "";
            return `${Math.round(v * 1e10) / 1e10}`;
        } catch (err) { return ""; }
    }

    function copy(text: string): void { Quickshell.execDetached(["wl-copy", text]); }

    function runInTerminal(command: string): void {
        Quickshell.execDetached(["ghostty", "-e", "sh", "-c", `${command}; printf '\nPulsa Enter para cerrar... '; read _`]);
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
        if (entry.runInTerminal) Quickshell.execDetached(["ghostty", "-e"].concat(entry.command));
        else entry.execute();
        const u = Object.assign({}, root.usage);
        u[entry.id] = (u[entry.id] || 0) + 1;
        root.usage = u;
        root._save();
        root.launched(entry.name);
    }

    function launchById(id: string): void {
        launch(DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id));
    }

    // Icon files, resolved once by scripts/icon-paths.sh: the orbital launcher draws real files (the image provider
    // returned blank pixmaps for most app icons in the launcher window)
    property var iconFiles: ({})

    Timer { id: resolveTimer; interval: 800; onTriggered: iconResolver.running = true }
    onListChanged: resolveTimer.restart()

    Process {
        id: iconResolver
        command: ["bash", `${Quickshell.shellDir}/scripts/icon-paths.sh`].concat(root.list.map(e => e.icon || "").filter(n => n.length > 0))
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of this.text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length === 2) map[f[0]] = f[1];
                }
                root.iconFiles = map;
            }
        }
    }

    function iconFor(entry): string {
        if (!entry) return "";
        const file = root.iconFiles[entry.icon || ""];
        if (file) return `file://${file}`;
        return Quickshell.iconPath(entry.icon || "", "application-x-executable");
    }

    signal launched(name: string)
}
