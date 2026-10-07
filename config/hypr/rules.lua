-- =============================================================================
-- Window & Layer Rules
-- =============================================================================

-- Suppress maximize events across all applications
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Floating windows for dialogs, settings and utility apps
hl.window_rule({
    name  = "float-utilities",
    match = {
        class = "(pavucontrol|org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent|nm-connection-editor|blueman-manager)",
    },
    float  = true,
    center = true,
})

-- Blur behind the Quickshell layers: native fallback, ONLY when hyprglass is not loaded (never two blurs
-- on one layer; with hyprglass, glass.lua does the layers). Every bar island, popover card and notification
-- card is drawn by a Quickshell window that is alpha 0 around its rounded rectangle, so the blur follows
-- the rounded shape (no BackgroundEffect region: Wayland regions are rectangles and left square tips).
-- ignore_alpha = 0.3: pixels with less alpha than that are not blurred. The notch (dragon-island) is
-- opaque black: no blur rule, ever. dragon-scrim (the 45 % black scrim) never gets blur either.
if not (hl.plugin and hl.plugin.hyprglass) then
    for _, ns in ipairs({ "dragon-bar", "dragon-popover", "dragon-notifications", "dragon-launcher", "dragon-planet", "dragon-wallpapers", "dragon-preview", "dragon-store" }) do
        hl.layer_rule({
            name         = "blur-" .. ns,
            match        = { namespace = "^" .. ns .. "$" },
            blur         = true,
            ignore_alpha = 0.3,
        })
    end
end

-- Package actions of the Tienda: a floating Ghostty (class org.dragonisland.Pkg) where sudo / the AUR helper ask for
-- the password; it is a translucent window, so it gets the same liquid glass as Ghostty
hl.window_rule({
    name   = "float-dragon-pkg",
    match  = { class = "^org\\.dragonisland\\.Pkg$" },
    float  = true,
    center = true,
    size   = { 900, 520 },
})

-- herdr (agents multiplexer): Ghostty with its own class, on workspace 5 ("agentes"). Tiled, so the usual
-- translucent-Ghostty liquid glass applies. Opened or focused by bin/dragon-herdr (SUPER + A).
hl.window_rule({
    name      = "herdr-workspace",
    match     = { class = "^org\\.dragonisland\\.Herdr$" },
    workspace = "5",
})

-- First-run setup terminal: floating and centered
hl.window_rule({
    name   = "float-firstrun",
    match  = { class = "^org\\.dragonisland\\.Setup$" },
    float  = true,
    center = true,
    size   = { 900, 560 },
})

-- The notch, popovers and panels animate themselves in QML: no compositor layer animation
hl.layer_rule({
    name    = "no-anim-dragon-island",
    match   = { namespace = "^dragon-(island|popover|launcher|planet|notifications|wallpapers|store|scrim|preview|dock|dock-edge)$" },
    no_anim = true,
})

-- -----------------------------------------------------------------------------
-- Per-app transparency (window opacity). Syntax: opacity = "<active> <inactive>".
-- Opt in by uncommenting; keep `fullscreen = false` so fullscreen windows stay opaque.
-- -----------------------------------------------------------------------------
-- hl.window_rule({
--     name    = "opacity-dolphin",
--     match   = { class = "^org\\.kde\\.dolphin$", fullscreen = false },
--     opacity = "0.92 0.88",
-- })
-- hl.window_rule({
--     name    = "opacity-code",
--     match   = { class = "^(code|Code|code-oss)$", fullscreen = false },
--     opacity = "0.93 0.90",
-- })

-- Safety net, always on: never any transparency on fullscreen windows or video players.
hl.window_rule({
    name    = "opaque-fullscreen",
    match   = { fullscreen = true },
    opacity = "1.0 override 1.0 override",
})
hl.window_rule({
    name    = "opaque-video-players",
    match   = { class = "^(mpv|vlc|celluloid|io\\.github\\.celluloid_player\\.Celluloid|haruna|org\\.kde\\.haruna|smplayer|totem|org\\.gnome\\.Totem)$" },
    opacity = "1.0 override 1.0 override",
})
