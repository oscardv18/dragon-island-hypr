-- =============================================================================
-- Environment Variables
-- Session-specific variables set here to ensure safe coexistence with KDE Plasma.
-- =============================================================================

-- Wayland & Desktop Session
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit Backends
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- SDL: Wayland first, X11 fallback for games bundling an old SDL
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")

-- Qt theming: hyprqt6engine (AUR), configured in hyprqt6engine.conf next to this file (icon theme
-- Sweet-Purple = Candy + Sweet Folders). It replaces the former "kde" platform theme, so the Hyprland
-- session no longer reads KDE's preferences (kdeglobals). Only set here (hl.env), never in /etc/environment
-- or ~/.profile, so it cannot leak into Plasma, which keeps its own platform theme.
hl.env("QT_QPA_PLATFORMTHEME", "hyprqt6engine")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
