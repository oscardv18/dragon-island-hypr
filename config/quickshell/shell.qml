//@ pragma IconTheme Dragon-Core
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
import "modules/herdrhelp"
import "modules/settings"
import "modules/capture"
import "modules/recording"
import "modules/idle"
import "modules/dock"
import "modules/switcher"
import "modules/overview"
import "modules/lock"
import "modules/frame"
import "modules/taller"
import "debug"

ShellRoot {
    id: root

    // Reduced motion: settings.json → KDE animation speed → 1.0 (see services/Settings.qml)
    Binding {
        target: Theme
        property: "motionScale"
        value: Settings.motionScale
    }

    // Bar style (A / B / C / D) and the D reveal: Theme derives every bar / notch size from them
    // focus mode shows the minimal bar (D) for its duration without touching the setting
    Binding {
        target: Theme
        property: "barStyle"
        value: Focus.active ? "D" : Settings.barStyle
    }
    Binding {
        target: Theme
        property: "barSize"
        value: Settings.barSize
    }
    Binding {
        target: Theme
        property: "barRevealed"
        value: BarState.revealed
    }

    // New identity: how much purple the active states carry (Settings → Apariencia)
    Binding {
        target: Theme
        property: "accentIntensity"
        value: Settings.accentIntensity
    }

    // Glass material (services/Glass.qml): ahumado · clasico · liquido; Theme derives the fills, border and light edge
    Binding {
        target: Theme
        property: "glassStyle"
        value: Glass.style
    }

    // Wallpaper palette (services/WallPalette.qml): Theme's accent tokens follow it while it is active
    Binding {
        target: Theme
        property: "paletteOn"
        value: WallPalette.active
    }
    Binding {
        target: Theme
        property: "wallPalette"
        value: ({ accent: WallPalette.accent, accentSoft: WallPalette.accentSoft, accentDeep: WallPalette.accentDeep,
                  glow: WallPalette.glow, onAccent: WallPalette.onAccent, tint: WallPalette.tint })
    }

    // starts the wallpaper service: IPC target "wallpaper" and restoring the saved wallpaper at login
    Component.onCompleted: { Wallpaper.init(); Store.init(); Herdr.init(); Taller.init(); Tiling.refresh(); Tray.init(); }

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

    // orbital launcher (neural core) + power menu + clipboard + shortcuts: one window per monitor
    Variants {
        model: Quickshell.screens
        delegate: Component { LauncherWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { DockWindow {} }
    }

    // Alt+Tab orbital (services/Switcher.qml): mapped only while the ring is shown
    Variants {
        model: Quickshell.screens
        delegate: Component { SwitcherWindow {} }
    }

    // workspaces overview, SUPER + Tab (services/Overview.qml)
    Variants {
        model: Quickshell.screens
        delegate: Component { OverviewWindow {} }
    }

    // the empty desktop's right click opens the orbital wallpaper picker (Bottom layer, under every window)
    Variants {
        model: Quickshell.screens
        delegate: Component { DesktopCatcher {} }
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
        delegate: Component { HerdrHelpWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { TallerWindow {} }
    }

    // capture overlay (SUPER + SHIFT + S): the frozen screen, the selection and the actions
    Variants {
        model: Quickshell.screens
        delegate: Component { CaptureWindow {} }
    }

    // the frame of the focused window (no title bars): top line + corner brackets, like the popovers (FrameDecor)
    Variants {
        model: Quickshell.screens
        delegate: Component { FrameWindow { locked: lock.locked } }
    }

    // recording mode: a thin red frame around every screen (RecordingMode.showFrame)
    Variants {
        model: Quickshell.screens
        delegate: Component { RecordingFrame {} }
    }

    // idle sequence: the dim layer (Idle.warning)
    Variants {
        model: Quickshell.screens
        delegate: Component { DimWindow {} }
    }

    // Ajustes (SUPER + F2): no scrim, the bar stays visible while its style changes
    Variants {
        model: Quickshell.screens
        delegate: Component { SettingsWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { ScrimWindow {} }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component { NotificationWindow {} }
    }

    // session lock (replaces hyprlock, which stays as fallback). IPC: `qs ipc call lock lock`. Only one WlSessionLock may exist.
    Lock {
        id: lock
        notifCount: Notifs.unreadCount
        captures: Notifs.notifications.filter(n => n.appName === "Capturas").length
        wifiOn: Network.connected
        muted: Audio.muted
        // the apps with unread notifications, most unread first (satellites on the lock's orbit)
        notifApps: {
            const by = {};
            for (const n of Notifs.unreadList()) {
                const app = n.appName || "";
                if (app.length === 0 || app === "Capturas") continue;
                (by[app] = by[app] || { name: app, icon: Notifs.iconFor(n), count: 0 }).count++;
            }
            return Object.values(by).sort((a, b) => b.count - a.count).slice(0, 3);
        }
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
