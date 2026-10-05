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

-- Qt theming (decision): reuse the KDE platform theme that Plasma already installs,
-- so Dolphin and other Qt/KDE apps look the same as in the Plasma session (Breeze, fonts, icons).
-- Only set here, so it never leaks into Plasma. Alternative (not used): hyprqt6engine.
hl.env("QT_QPA_PLATFORMTHEME", "kde")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
