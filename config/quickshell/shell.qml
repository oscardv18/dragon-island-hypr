// =============================================================================
// dragon-island — shell.qml
// Main entry point for Quickshell desktop environment (Base Phase)
// =============================================================================
import Quickshell
import QtQuick
import "debug"

ShellRoot {
    id: root

    // During this base phase, DebugPanel is instantiated to verify all singletons and services
    DebugPanel {
        id: debugPanel
        visible: true
    }
}
