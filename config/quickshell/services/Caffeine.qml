// =============================================================================
// dragon-island — Caffeine.qml
// Service: keep the screen awake (idle inhibitor). The inhibitor itself needs a window, so each bar window
// owns an IdleInhibitor bound to `enabled` (modules/bar/Bar.qml).
// =============================================================================
/**
 * Properties:
 *   - enabled: bool
 *
 * Functions:
 *   - toggle(): void
 *
 * IPC (`qs ipc call caffeine <fn>`): toggle(), current(): bool
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool enabled: false

    function toggle(): void { root.enabled = !root.enabled; }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.toggle(); }
        function current(): bool { return root.enabled; }
    }
}
