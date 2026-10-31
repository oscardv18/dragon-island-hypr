-- =============================================================================
-- hyprglass (optional): liquid glass on Ghostty and acrylic glass behind the Quickshell layers
-- Plugin: https://github.com/hyprnux/hyprglass  (hyprpm installs v0.9.1 for Hyprland 0.56.2)
-- Installed by the optional "Efecto cristal (hyprglass)" component of install.sh.
-- Everything is guarded: without the plugin nothing here runs and the native blur
-- (rules.lua, created only when hyprglass is absent) is all you get.
--
-- * Windows: every translucent window gets glass, including maximized and fullscreen windows.
--   Browsers, editors and video players are excluded by class below.
-- * Layers (bar, popovers, notifications, launcher, wallpaper picker): glass masked by ALPHA
--   (mask_mode = "alpha"): it appears where the layer has alpha above mask_threshold, i.e. the visible
--   rounded island / card, so corners are clean (a "region" mask is a rectangle: square tips). The shapes
--   are translucent (Theme.glassBg 30 %, panels 42 %) so the glass shows through; the threshold sits below.
--
-- Only with the «liquido» glass style (glassstyle.lua, Ajustes › Apariencia). With «ahumado» / «clasico» the plugin
-- stays loaded but inactive (windows and layers off) and the native blur of look.lua / rules.lua does the work.
-- =============================================================================

local glass = require("glassstyle")

if glass.hyprglass and not glass.liquid then
    -- installed but inactive: one call turns windows and layers off (`hyprctl reload` re-reads this, so it is live).
    -- manage_window_blur / layers.manage_blur (both true by default) make hyprglass take the NATIVE blur away from the
    -- windows and layers it would glass, so there is never a double blur. They keep doing that with `enabled = false`:
    -- that is what left Ghostty / kitty with the wallpaper sharp behind them after the pulido (ahumado by default).
    -- Off here, the native blur of look.lua is back on every translucent window.
    hl.plugin.hyprglass.config({
        enabled            = false,
        manage_window_blur = false,
        layers             = { enabled = false, manage_blur = false },
    })
end

if glass.liquid then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled        = true,   -- windows: every translucent one gets the glass; the exclusions are the tags below
        -- hyprglass draws the windows and layers it glasses and takes the native blur off them (no double blur);
        -- explicit because the other styles turn both off and a reload must bring them back
        manage_window_blur = true,
        default_theme  = "dark",
        default_preset = "dragon-liquid",   -- one look for every window (skip_opaque_windows, on by default, ignores opaque ones)
        -- live_resample re-renders the glass when what is behind it changes (a video wallpaper): cap it at
        -- a low fps instead of the default 30 (see the measurements in HANDOFF.md)
        layers        = { enabled = true, manage_blur = true, live_resample_fps = 8 },
    })

    -- ---- liquid glass for Ghostty: the look of hyprglass' README screenshot ----
    -- Built from the plugin's DEFAULTS (not from `glass`): moderate blur (the backdrop is still recognisable),
    -- refraction only on the rim (refraction_spread 0 = flat centre, no dome), a soft bevel + specular light on
    -- the edge, and a dark navy tint with a hint of violet. High spread / lens / blur smears and warps it.
    hg.preset("dragon-liquid", {
        blur_strength        = 1.6,
        blur_iterations      = 3,
        refraction_strength  = 0.6,
        refraction_spread    = 0.0,   -- distortion only at the rim
        refraction_flow      = 0.3,
        edge_thickness       = 0.06,
        lens_distortion      = 0.1,   -- no dome magnification
        chromatic_aberration = 0.4,
        specular_strength    = 0.7,
        fresnel_strength     = 0.5,
        bevel_strength       = 0.5,
        bevel_size           = 3.0,
        self_sample          = 0.0,
        tint_color           = 0x0b102060,   -- dark navy (RRGGBBAA), alpha = strength
        dark                 = { brightness = 1.0, contrast = 1.0, saturation = 0.9, adaptive_dim = 0.5 },
    })

    -- ---- the layers get the SAME liquid glass as Ghostty (inherit dragon-liquid); only the rim width changes
    -- with the size of the shape, because edge_thickness is a fraction of its smallest side ----
    hg.preset("dragon-bar", {         -- bar islands, 40 px high: 0.2 = an 8 px rim
        inherits             = "dragon-liquid",
        blur_strength        = 2.0,
        edge_thickness       = 0.2,
        bevel_size           = 2.0,
    })
    hg.preset("dragon-card", {        -- notification cards (~90 px high)
        inherits             = "dragon-liquid",
        edge_thickness       = 0.12,
        bevel_size           = 2.5,
    })
    hg.preset("dragon-panel", {       -- popovers, launcher, wallpaper picker (300+ px)
        inherits             = "dragon-liquid",
        edge_thickness       = 0.06,
    })

    -- mask_threshold 0.1: the Quickshell fills are translucent (Theme.glassBg 18 %, panels 30 %), so the glass shows through
    hg.layer("dragon-bar",           { preset = "dragon-bar",   mask_mode = "alpha", mask_threshold = 0.1 })
    hg.layer("dragon-notifications", { preset = "dragon-card",  mask_mode = "alpha", mask_threshold = 0.1 })
    hg.layer("dragon-launcher", { preset = "dragon-liquid", mask_mode = "alpha", mask_threshold = 0.1 })
    hg.layer("dragon-switcher", { preset = "dragon-liquid", mask_mode = "alpha", mask_threshold = 0.1 })   -- Alt+Tab orbital
    hg.layer("dragon-overview", { preset = "dragon-liquid", mask_mode = "alpha", mask_threshold = 0.1 })   -- SUPER + Tab
    for _, ns in ipairs({ "dragon-popover", "dragon-wallpapers", "dragon-preview", "dragon-store", "dragon-herdr-help", "dragon-settings" }) do
        hg.layer(ns, { preset = "dragon-panel", mask_mode = "alpha", mask_threshold = 0.1 })
    end

    -- The notch must stay opaque black; the scrim is a flat dim, not glass
    hg.layer("dragon-island", { exclude = true })
    hg.layer("dragon-dock",   { exclude = true })   -- the dock is opaque black like the notch
    hg.layer("dragon-scrim",  { exclude = true })
    hg.layer("dragon-desktop", { exclude = true })  -- the invisible right-click catcher on the desktop (Bottom layer)

    -- ---- windows ----
    -- Liquid glass goes on every window that is actually translucent (Ghostty, kitty, Quickshell-less GTK/Qt
    -- apps with transparency, ...). hyprglass skips opaque windows on its own (skip_opaque_windows), so apps
    -- without transparency cost nothing. Neovim runs inside a terminal, so it gets its terminal's glass.
    --
    -- Never glass: browsers and code editors (it looks bad there), whatever the app id / casing.
    hl.window_rule({
        name  = "glass-off-browsers-and-editors",
        match = { class = "(?i)^(brave.*|google-chrome.*|chromium.*|chrome.*|firefox.*|librewolf.*|vivaldi.*|microsoft-edge.*|code|code-oss|code-url-handler|codium|vscodium|visual-studio-code|cursor|windsurf.*|antigravity.*|zed|dev\\.zed\\.zed.*|sublime_text|sublime_merge|jetbrains-.*|idea.*|pycharm.*|webstorm.*|clion.*|goland.*|rider.*|phpstorm.*|rustrover.*|datagrip.*|android-studio.*|kate|org\\.kde\\.kate|org\\.kde\\.kwrite|kwrite|org\\.kde\\.kdevelop|gedit|org\\.gnome\\.gedit|org\\.gnome\\.texteditor|gnome-text-editor|emacs|lapce|helix|geany|mousepad|pluma|xed)$" },
        tag   = "+hyprglass_disabled",
    })
    -- Keep glass through maximize/fullscreen/restore. A state-dependent disabling tag can linger
    -- after restoring a window, leaving its transparent background without glass or native blur.
    hl.window_rule({
        name  = "glass-keep-terminals",
        match = { class = "^(com\\.mitchellh\\.ghostty|com\\.mitchellh\\.ghostty\\..*|kitty|org\\.dragonisland\\.(Herdr|Pkg|Setup))$" },
        tag   = "-hyprglass_disabled",
    })
    hl.window_rule({
        name  = "glass-off-video-players",
        match = { class = "^(mpv|vlc|celluloid|io\\.github\\.celluloid_player\\.Celluloid|haruna|org\\.kde\\.haruna|smplayer|totem|org\\.gnome\\.Totem)$" },
        tag   = "+hyprglass_disabled",
    })
end
