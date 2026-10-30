// =============================================================================
// dragon-island — Commands.qml
// Service: long shell commands, reported by the zsh hooks of config/zsh/dragon.zsh (never polled).
// =============================================================================
/**
 * The hooks run in the background (`… &!`), so the prompt never waits for Quickshell:
 *   preexec  starts `sleep <threshold>; qs ipc call commands started <id> <command> <cwd>` and remembers its pid
 *   precmd   kills that sleeper; if the command lasted ≥ the threshold, `qs ipc call commands finished …`
 * The threshold comes from settings.json (longCommandSeconds, read once when the shell starts; this service filters
 * again with the live value).
 * "Is the terminal in front?": a single Ghostty process serves every window, so a pid does not identify one. A
 * finished command only raises the island notice when the active window is NOT a terminal whose title shows that
 * command's folder (zsh puts "user@host:~/path" in the title) — a heuristic, documented in HANDOFF 8c.
 *
 * Properties:
 *   - running: list<var> [readonly] ({ id, command, cwd, since (ms) }: commands past the threshold, still running)
 *   - recent: list<var> [readonly] ({ id, command, code, seconds, cwd, at (ms) }: last 12 finished, newest first)
 *
 * Functions:
 *   - formatDuration(seconds: int): string ("48s", "2m14s", "1h03m")
 *   - clearRecent(): void
 *
 * Signals:
 *   - done(var cmd) ({ command, code, seconds, cwd }: finished while its terminal was not in front)
 *
 * IPC (`qs ipc call commands <fn>`): started(key: string, command: string, cwd: string), finished(command: string,
 *   code: int, seconds: int, cwd: string, key: string), list(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property var running: []
    property var recent: []

    signal done(var cmd)

    function formatDuration(seconds: int): string {
        const s = Math.max(0, Math.round(seconds));
        if (s < 60) return `${s}s`;
        if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
        return `${Math.floor(s / 3600)}h${String(Math.floor(s % 3600 / 60)).padStart(2, "0")}m`;
    }

    function clearRecent(): void { root.recent = []; }

    function _started(key: string, command: string, cwd: string): void {
        if (root.running.some(c => c.id === key)) return;
        root.running = root.running.concat([{ id: key, command: command, cwd: cwd, since: Date.now() - Settings.longCommandSeconds * 1000 }]);
    }

    function _terminalInFront(cwd: string): bool {
        if (!WindowContext.isDev) return false;
        const base = cwd.split("/").filter(p => p.length > 0).pop() ?? "";
        const title = Hypr.activeTitle;
        return base.length > 0 && title.includes(base);
    }

    function _finished(command: string, code: int, seconds: int, cwd: string, key: string): void {
        root.running = root.running.filter(c => c.id !== key && !(key.length === 0 && c.command === command));
        if (seconds < Settings.longCommandSeconds) return;
        const entry = { id: key, command: command, code: code, seconds: seconds, cwd: cwd, at: Date.now() };
        root.recent = [entry].concat(root.recent).slice(0, 12);
        if (!root._terminalInFront(cwd)) root.done(entry);
    }

    IpcHandler {
        target: "commands"
        function started(key: string, command: string, cwd: string): void { root._started(key, command, cwd); }
        function finished(command: string, code: int, seconds: int, cwd: string, key: string): void { root._finished(command, code, seconds, cwd, key); }
        function list(): string {
            return root.running.map(c => `en curso\t${c.command}\t${c.cwd}`)
                .concat(root.recent.map(c => `${c.code}\t${c.command}\t${root.formatDuration(c.seconds)}`)).join("\n");
        }
    }
}
