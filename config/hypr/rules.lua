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

-- Android Studio's standalone emulator uses class Emulator for the device AND its
-- separate toolbar/extended controls (observed on XWayland). Float the whole family
-- without centering/resizing each window: the emulator positions its own toolbar.
-- Keep its alpha/skin, but remove compositor frames, glass and pixel filtering.
hl.window_rule({
    name             = "android-emulator-clean",
    match            = { class = "^Emulator$" },
    float            = true,
    decorate         = false,
    border_size      = 0,
    rounding         = 0,
    no_shadow        = true,
    no_blur          = true,
    nearest_neighbor = false,
    opacity          = "1.0 override 1.0 override",
    tag              = "+hyprglass_disabled",
})
-- The Pixel skin has rounded outer corners, but its XWayland window exposes a
-- black rectangular backing. Clip only this device window, never its toolbar.
-- Radius calibrated for the ~300 px wide Pixel 10 Pro XL on the 768p display.
hl.window_rule({
    name           = "android-pixel-rounded-skin",
    match          = { class = "^Emulator$", title = "^Android Emulator - Pixel_10_Pro_XL:.*$" },
    rounding_power = 2.0,
})
-- 0.56.2's Lua rule parser caps rounding at 20; set_prop accepts the radius
-- needed by the phone skin. Apply on open/title and reload without a shell process.
local function clipPixelSkin(w)
    if w and w.class == "Emulator" and w.title:match("^Android Emulator %- Pixel_10_Pro_XL:") then
        hl.dispatch(hl.dsp.window.set_prop({ window = w, prop = "rounding", value = "48" }))
    end
end
hl.on("window.open", clipPixelSkin)
hl.on("window.title", clipPixelSkin)
hl.on("config.reloaded", function()
    for _, w in ipairs(hl.get_windows()) do clipPixelSkin(w) end
end)
if hl.plugin and hl.plugin.hyprbars then
    hl.window_rule({
        name               = "android-emulator-no-titlebar",
        match              = { class = "^Emulator$" },
        ["hyprbars:no_bar"] = true,
    })
end

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
    for _, ns in ipairs({ "dragon-bar", "dragon-popover", "dragon-notifications", "dragon-launcher", "dragon-wallpapers", "dragon-preview", "dragon-store", "dragon-herdr-help" }) do
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
    match   = { namespace = "^dragon-(island|popover|launcher|notifications|wallpapers|store|scrim|preview|dock|dock-edge|herdr-help)$" },
    no_anim = true,
})

-- -----------------------------------------------------------------------------
-- Per-app transparency (window opacity). Syntax: opacity = "<active> <inactive>".
-- Opt in by uncommenting; omit fullscreen matching to keep transparency in every window state.
-- -----------------------------------------------------------------------------
-- hl.window_rule({
--     name    = "opacity-dolphin",
--     match   = { class = "^org\\.kde\\.dolphin$" },
--     opacity = "0.92 0.88",
-- })
-- hl.window_rule({
--     name    = "opacity-code",
--     match   = { class = "^(code|Code|code-oss)$" },
--     opacity = "0.93 0.90",
-- })

-- Keep window transparency in every state so blur/glass remains visible. Video players stay opaque.
hl.window_rule({
    name    = "opaque-video-players",
    match   = { class = "^(mpv|vlc|celluloid|io\\.github\\.celluloid_player\\.Celluloid|haruna|org\\.kde\\.haruna|smplayer|totem|org\\.gnome\\.Totem)$" },
    opacity = "1.0 override 1.0 override",
})
