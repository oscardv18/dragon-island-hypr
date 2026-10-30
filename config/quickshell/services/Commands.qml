// =============================================================================
// dragon-island — Commands.qml
// Service: long shell commands reported by the zsh hooks. Filled in phase 2 §3.2.
// =============================================================================
/**
 * Functions:
 *   - formatDuration(seconds: int): string ("48s", "2m14s", "1h03m")
 *
 * Signals:
 *   - done(var cmd) ({ command, code, seconds, cwd })
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    signal done(var cmd)

    function formatDuration(seconds: int): string {
        const s = Math.max(0, Math.round(seconds));
        if (s < 60) return `${s}s`;
        if (s < 3600) return `${Math.floor(s / 60)}m${String(s % 60).padStart(2, "0")}s`;
        return `${Math.floor(s / 3600)}h${String(Math.floor(s % 3600 / 60)).padStart(2, "0")}m`;
    }
}
