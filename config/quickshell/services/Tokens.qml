// Today's token use from local Claude Code / Codex logs through the optional `dragon-tokens` (read only, no network).
/**
 * Properties:
 *   - available: bool — ~/.local/bin/dragon-tokens exists (checked when activated); the card hides itself otherwise
 *   - today: {claude: {in, out, cache}|null, codex: {in, out}|null} — null means «not understood» and shows «—»
 *   - status: ok|loading|unavailable|error · message
 * Functions:
 *   - activate(value) — the Agentes tab is visible: one read now and one per minute; nothing runs otherwise
 *   - format(n): "182 k" / "1,2 M" / "—"
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-tokens`
    property bool active: false
    property bool available: false
    property string status: "unavailable"
    property string message: ""
    property var today: ({ claude: null, codex: null })
    Component { id: request; ToolRequest {} }
    function activate(value): void { active = value; if (active) refresh(); }
    function refresh(): void {
        const p = request.createObject(root, { callback: r => {
            available = r.ok || r.error?.code !== "missing_tool";
            if (r.ok) { today = { claude: r.claude ?? null, codex: r.codex ?? null }; status = "ok"; message = ""; }
            else { status = available ? "error" : "unavailable"; message = r.error?.message ?? ""; }
        } });
        p.exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', tool, "today", "--json"]);
    }
    function format(n): string {
        if (n === null || n === undefined) return "—";
        return n >= 1e6 ? (n / 1e6).toFixed(1).replace(".", ",") + " M" : n >= 1e3 ? Math.round(n / 1e3) + " k" : String(n);
    }
    Timer { interval: 60000; repeat: true; running: root.active && root.available; onTriggered: root.refresh() }
}
