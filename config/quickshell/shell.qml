// =============================================================================
// dragon-island — shell.qml
// One floating bar and one Dynamic Island overlay per monitor.
// DebugPanel is not started automatically: `qs ipc call debug toggle` loads it on demand.
// =============================================================================
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "modules/island"
import "debug"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        delegate: Component { Bar {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { IslandWindow {} }
    }

    LazyLoader {
        id: debugLoader
        active: false
        DebugPanel {}
    }

    IpcHandler {
        target: "debug"
        function toggle(): void { debugLoader.active = !debugLoader.active; }
    }
}
