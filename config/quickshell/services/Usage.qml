// =============================================================================
// dragon-island — Usage.qml
// Service: how much each app is used, from Codex's `dragon-usage` (frecency → the planet sizes of the Gravity launcher)
// =============================================================================
/**
 * `~/.local/bin/dragon-usage` (full path: Quickshell's PATH does not see ~/.local/bin):
 *   dragon-usage stats --json  → { "apps": [ { id, total, week, lastUsed, frecency } ] }   frecency 0–1
 *   dragon-usage record <id>   → one launch
 * Missing or broken command: `available` stays false and every value falls back to Apps' own launch counts,
 * silently (no warning in the log), so the launcher keeps opening apps.
 *
 * Properties:
 *   - available: bool [readonly] (the last stats call worked)
 *   - stats: var [readonly] (desktop id → { total, week, lastUsed, frecency })
 *
 * Functions:
 *   - refresh(): void              (re-read the stats; the launcher calls it each time it opens)
 *   - record(id: string): void     (one launch of that desktop entry id)
 *   - frecency(id: string): real   (0–1; without dragon-usage: Apps' launch count over the largest one)
 *   - week(id: string): int        (launches in the last 7 days; without dragon-usage: -1 = unknown)
 *   - detail(id: string, windows: int): string
 *       "3 ventanas abiertas · usado 41 veces esta semana" (each half only when known / non-zero)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string bin: `${Quickshell.env("HOME")}/.local/bin/dragon-usage`
    property bool available: false
    property var stats: ({})

    readonly property int _maxCount: {
        let m = 0;
        for (const k in Apps.usage) m = Math.max(m, Apps.usage[k] || 0);
        return m;
    }

    Process {
        id: statsProc
        // exit 3 = not installed: no error, no output
        command: ["sh", "-c", '[ -x "$1" ] || exit 3; exec "$1" stats --json 2>/dev/null', "sh", root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0) return;
                try {
                    const map = {};
                    for (const a of (JSON.parse(this.text).apps || [])) {
                        if (a && typeof a.id === "string") map[a.id] = a;
                    }
                    root.stats = map;
                    root.available = true;
                } catch (e) {
                    root.available = false;
                }
            }
        }
        onExited: (code, status) => { if (code !== 0) root.available = false; }
    }

    function refresh(): void {
        if (!statsProc.running) statsProc.running = true;
    }

    function record(id: string): void {
        if (!id) return;
        Quickshell.execDetached(["sh", "-c", '[ -x "$1" ] && exec "$1" record "$2" >/dev/null 2>&1; exit 0', "sh", root.bin, id]);
    }

    function frecency(id: string): real {
        const s = root.stats[id];
        if (s && typeof s.frecency === "number") return Math.max(0, Math.min(1, s.frecency));
        if (root.available) return 0;
        return root._maxCount > 0 ? (Apps.usage[id] || 0) / root._maxCount : 0;
    }

    function week(id: string): int {
        const s = root.stats[id];
        return s && typeof s.week === "number" ? s.week : (root.available ? 0 : -1);
    }

    function detail(id: string, windows: int): string {
        const parts = [];
        if (windows > 0) parts.push(windows === 1 ? "1 ventana abierta" : `${windows} ventanas abiertas`);
        const w = root.week(id);
        if (w > 0) parts.push(w === 1 ? "usado 1 vez esta semana" : `usado ${w} veces esta semana`);
        else if (w < 0 && (Apps.usage[id] || 0) > 0) parts.push(`abierto ${Apps.usage[id]} ${Apps.usage[id] === 1 ? "vez" : "veces"}`);
        return parts.join(" · ");
    }
}
