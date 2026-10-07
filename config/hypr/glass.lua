-- =============================================================================
-- hyprglass (optional): liquid glass on Ghostty and acrylic glass behind the Quickshell layers
-- Plugin: https://github.com/hyprnux/hyprglass  (hyprpm installs v0.9.1 for Hyprland 0.56.2)
-- Installed by the optional "Efecto cristal (hyprglass)" component of install.sh.
-- Everything is guarded: without the plugin nothing here runs and the native blur
-- (rules.lua, created only when hyprglass is absent) is all you get.
--
-- * Windows: whitelist. `enabled = false` turns glass off everywhere; only Ghostty opts in with the
--   window tag hyprglass_enabled (+ its own preset), so Brave, Dolphin etc. stay untouched.
-- * Layers (bar, popovers, notifications, launcher, wallpaper picker): glass masked by ALPHA
--   (mask_mode = "alpha"): it appears where the layer has alpha above mask_threshold, i.e. the visible
--   rounded island / card, so corners are clean (a "region" mask is a rectangle: square tips). The shapes
--   are translucent (Theme.glassBg 30 %, panels 42 %) so the glass shows through; the threshold sits below.
-- =============================================================================

if hl.plugin and hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled       = false,   -- windows: whitelist (Ghostty tag below)
        default_theme = "dark",
        -- live_resample re-renders the glass when what is behind it changes (a video wallpaper): cap it at
        -- a low fps instead of the default 30 (see the measurements in HANDOFF.md)
        layers        = { enabled = true, live_resample_fps = 8 },
    })

    -- ---- liquid glass for Ghostty: strong, visible refraction at the edges (built on `glass`) ----
    hg.preset("dragon-liquid", {
        inherits             = "glass",
        blur_strength        = 3.0,
        blur_iterations      = 4,
        refraction_strength  = 5.0,   -- `glass` goes up to 8.0; raise it for a stronger edge deformation
        edge_thickness       = 0.10,  -- bezel width (fraction of the smallest dimension)
        lens_distortion      = 0.6,   -- dome magnification of the centre
        chromatic_aberration = 0.8,
        specular_strength    = 0.8,
        fresnel_strength     = 0.9,
        bevel_strength       = 0.6,
        bevel_size           = 8.0,
        self_sample          = 0.2,   -- a bit of the terminal's own content in its glass
        tint_color           = 0x14101c40,
        dark                 = { brightness = 0.9 },
    })

    -- ---- bar islands: noticeable but readable ----
    hg.preset("dragon-bar", {
        inherits             = "pomme",
        blur_strength        = 2.8,
        blur_iterations      = 4,
        refraction_strength  = 0.8,
        chromatic_aberration = 0.3,
        specular_strength    = 0.8,
        fresnel_strength     = 0.5,
        bevel_strength       = 0.5,   -- the lit line along the edge is the island's border
        bevel_size           = 2.0,
        tint_color           = 0xc50ed214,   -- very faint magenta (accent #c50ed2)
        adaptive_dim         = 0.6,   -- dims bright backdrops (light wallpapers, white windows): text stays readable
        dark                 = { brightness = 0.9 },
    })

    -- ---- notifications, popovers, launcher, wallpaper picker: same glass, a bit more tint ----
    hg.preset("dragon-panel", {
        inherits             = "dragon-bar",
        tint_color           = 0xc50ed233,
        adaptive_dim         = 0.7,
        dark                 = { brightness = 0.85 },
    })

    hg.layer("dragon-bar", { preset = "dragon-bar", mask_mode = "alpha", mask_threshold = 0.15 })
    for _, ns in ipairs({ "dragon-popover", "dragon-notifications", "dragon-launcher", "dragon-wallpapers" }) do
        hg.layer(ns, { preset = "dragon-panel", mask_mode = "alpha", mask_threshold = 0.15 })
    end

    -- The notch must stay opaque black; the scrim is a flat dim, not glass
    hg.layer("dragon-island", { exclude = true })
    hg.layer("dragon-scrim",  { exclude = true })

    -- ---- Ghostty: the only window with glass ----
    hl.window_rule({
        name  = "glass-ghostty",
        match = { class = "^com\\.mitchellh\\.ghostty$" },
        tag   = "+hyprglass_enabled",
    })
    hl.window_rule({
        name  = "glass-ghostty-preset",
        match = { class = "^com\\.mitchellh\\.ghostty$" },
        tag   = "+hyprglass_preset_dragon-liquid",
    })
    -- ... and none when it is fullscreen (disabled wins over enabled)
    hl.window_rule({
        name  = "glass-off-ghostty-fullscreen",
        match = { class = "^com\\.mitchellh\\.ghostty$", fullscreen = true },
        tag   = "+hyprglass_disabled",
    })
end
