// =============================================================================
// dragon-island — Activity.qml
// Service: the activity log of the island's time strip, through Codex's `dragon-activity` (~/.local/bin, full path).
//   dragon-activity add --kind agent|command|focus --name "<text>" --start <epoch> [--end <epoch>] [--status ok|fail|blocked]
//       → prints the id
//   dragon-activity end <id> [--status ok|fail]
//   dragon-activity range --from <epoch> --to <epoch> --json → {"items":[{id,kind,name,start,end,status}]} (end null = open)
// Herdr (an agent starts / stops working), Commands (≥ 30 s) and Focus call add / end. The strip asks for a range only
// while the island is expanded. Missing tool: everything is a no-op and `available` turns false (no log noise).
// =============================================================================
/**
 * Properties:
 *   - available: bool [readonly] (false once a call found dragon-activity missing)
 *   - items: list<var> [readonly] (last range: { id, kind, name, start, end, status }, epoch seconds; end -1 = open)
 *
 * Functions:
 *   - add(kind: string, name: string, start: int, end: int, status: string, onId: var): void
 *       (end ≤ 0 = still open; onId(id) gets the new id, may be null)
 *   - end(id: string, status: string): void
 *   - refresh(from: int, to: int): void (epoch seconds)
 *   - now(): int (epoch seconds)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-activity`
    property bool available: true
    property var items: []

    function now(): int { return Math.floor(Date.now() / 1000); }

    // one process per call: they are rare (an agent changing state, a long command, focus)
    Component {
        id: callComponent
        Process {
            id: proc
            property var onId: null
            property bool _done: false
            stdout: StdioCollector {
                onStreamFinished: {
                    const id = this.text.trim();
                    if (proc.onId) proc.onId(id.length > 0 ? id : null);
                    if (proc._done) proc.destroy(); else proc._done = true;
                }
            }
            onExited: (code, status) => {
                if (code === 127) root.available = false;
                if (proc._done) proc.destroy(); else proc._done = true;
            }
        }
    }

    function _call(args: var, onId: var): void {
        if (!root.available) { if (onId) onId(null); return; }
        const p = callComponent.createObject(root, { onId: onId });
        // sh: a missing tool exits 127 without a Quickshell warning
        p.exec(["sh", "-c", 'exec "$0" "$@" 2>/dev/null', root.tool].concat(args));
    }

    function add(kind: string, name: string, start: int, end: int, status: string, onId: var): void {
        const args = ["add", "--kind", kind, "--name", String(name).slice(0, 200), "--start", String(start)];
        if (end > 0) args.push("--end", String(end));
        if (status) args.push("--status", status);
        _call(args, onId ?? null);
    }
    function end(id: string, status: string): void {
        if (!id) return;
        const args = ["end", String(id)];
        if (status) args.push("--status", status);
        _call(args, null);
    }

    Process {
        id: rangeProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    root.items = (d.items ?? []).map(i => ({ id: String(i.id), kind: i.kind, name: i.name ?? "", start: Number(i.start),
                                                             end: i.end === null || i.end === undefined ? -1 : Number(i.end), status: i.status ?? "" }));
                } catch (e) { root.items = []; }
            }
        }
        onExited: (code, status) => { if (code === 127) root.available = false; }
    }
    function refresh(from: int, to: int): void {
        if (!root.available || rangeProc.running) return;
        rangeProc.exec(["sh", "-c", 'exec "$0" "$@" 2>/dev/null', root.tool, "range", "--from", String(from), "--to", String(to), "--json"]);
    }
}
