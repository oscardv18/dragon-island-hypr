//@ pragma IconTheme Sweet-Purple
// =============================================================================
// dragon-island — shell.qml
// Per monitor: the floating bar, the notch (dragon-island), popovers (dragon-popover), the modal panels
// (dragon-launcher) and notification popups (dragon-notifications) — each in its own layer window.
// DebugPanel is not started automatically: `qs ipc call debug toggle` loads it on demand.
// Animation speed follows the Settings service (`qs ipc call settings motion 0` = no animations).
// Icons: the pragma on line 1 pins Quickshell.iconPath / IconImage to Candy + Sweet Folders, independent of KDE.
// =============================================================================
import Quickshell
import Quickshell.Io
import QtQuick
import "."
import "services"
import "modules/bar"
import "modules/island"
import "modules/popovers"
import "modules/launcher"
import "modules/notifications"
import "modules/wallpapers"
import "modules/store"
import "modules/dock"
import "debug"

ShellRoot {
    id: root

    // Reduced motion: settings.json → KDE animation speed → 1.0 (see services/Settings.qml)
    Binding {
        target: Theme
        property: "motionScale"
        value: Settings.motionScale
    }

    // starts the wallpaper service: IPC target "wallpaper" and restoring the saved wallpaper at login
    Component.onCompleted: { Wallpaper.init(); Store.init(); Herdr.init(); }

    Variants {
        model: Quickshell.screens
        delegate: Component { Bar {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { IslandWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { PreviewWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { PopoverWindow {} }
    }

    // orbital launcher + power menu + clipboard + shortcuts: back ring, planet, launcher window (mapped in that order)
    Variants {
        model: Quickshell.screens
        delegate: Component { OrbitalLauncher {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { DockWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { WallpaperWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { StoreWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { ScrimWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { NotificationWindow {} }
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
