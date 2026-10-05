// =============================================================================
// dragon-island — shell.qml
// One floating bar and one Dynamic Island overlay per monitor.
// DebugPanel is not started automatically: `qs ipc call debug toggle` loads it on demand.
// Animation speed follows the Settings service (`qs ipc call settings motion 0` = no animations).
// =============================================================================
import Quickshell
import Quickshell.Io
import QtQuick
import "."
import "services"
import "modules/bar"
import "modules/island"
import "debug"

ShellRoot {
    id: root

    // Reduced motion: settings.json → KDE animation speed → 1.0 (see services/Settings.qml)
    Binding {
        target: Theme
        property: "motionScale"
        value: Settings.motionScale
    }

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
