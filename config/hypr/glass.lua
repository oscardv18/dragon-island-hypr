-- =============================================================================
-- hyprglass (optional): acrylic / "liquid glass" behind the Quickshell layers
-- Plugin: https://github.com/hyprnux/hyprglass  (hyprpm installs v0.9.1 for Hyprland 0.56.2)
-- Installed by the optional "Efecto cristal (hyprglass)" component of install.sh.
-- Everything is guarded: without the plugin nothing here runs and the native blur
-- (rules.lua, created only when hyprglass is absent) is all you get.
--
-- Glass is masked by ALPHA (mask_mode = "alpha"): it appears where the layer's pixels have alpha above
-- mask_threshold, i.e. exactly the visible rounded island / card. (A "region" mask would use the
-- ext-background-effect rectangle and leave square tips at rounded corners.) So every Quickshell window
-- is alpha 0 around its shapes, and the shapes' fill (Theme.glassBg 50 %, popovers 82 %) is above 0.3.
-- =============================================================================

if hl.plugin and hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        default_theme = "dark",
        -- live_resample re-renders the glass when what is behind it changes (a video wallpaper): cap it at
        -- a low fps instead of the default 30 (see the measurements in HANDOFF.md)
        layers        = { enabled = true, live_resample_fps = 8 },
    })

    -- Bar islands: strong blur, moderate refraction / aberration so text stays readable, a thin soft
    -- bevel as the island border and a very faint magenta tint (0xRRGGBBAA, accent #c50ed2 at alpha 0x14).
    hg.preset("dragon-bar", {
        inherits             = "pomme",
        blur_strength        = 2.8,   -- blur radius scale (× 12 px)
        blur_iterations      = 4,     -- gaussian passes
        refraction_strength  = 0.3,   -- edge refraction, moderate
        chromatic_aberration = 0.15,  -- color fringing at the edges, moderate
        specular_strength    = 0.4,
        fresnel_strength     = 0.35,
        bevel_strength       = 0.25,  -- thin lit line along the edge
        bevel_size           = 2.0,
        tint_color           = 0xc50ed214,
        adaptive_dim         = 0.85,  -- dims bright backdrops (light wallpapers, white windows) so text stays readable
        dark                 = { brightness = 0.74 },
    })

    -- Notifications, popovers, launcher and wallpaper picker: the same glass, a bit more opaque
    hg.preset("dragon-panel", {
        inherits             = "dragon-bar",
        blur_strength        = 2.4,
        tint_color           = 0xc50ed226,
        adaptive_dim         = 0.9,
        dark                 = { brightness = 0.72 },
    })

    hg.layer("dragon-bar",           { preset = "dragon-bar",   mask_mode = "alpha", mask_threshold = 0.3 })
    for _, ns in ipairs({ "dragon-popover", "dragon-notifications", "dragon-launcher", "dragon-wallpapers" }) do
        hg.layer(ns,                 { preset = "dragon-panel", mask_mode = "alpha", mask_threshold = 0.3 })
    end

    -- The notch must stay opaque black; the scrim is a flat dim, not glass
    hg.layer("dragon-island", { exclude = true })
    hg.layer("dragon-scrim",  { exclude = true })

    -- No glass on fullscreen windows or video players
    hl.window_rule({
        name  = "glass-off-fullscreen",
        match = { fullscreen = true },
        tag   = "+hyprglass_disabled",
    })
    hl.window_rule({
        name  = "glass-off-video-players",
        match = { class = "^(mpv|vlc|celluloid|io\\.github\\.celluloid_player\\.Celluloid|haruna|org\\.kde\\.haruna|smplayer|totem|org\\.gnome\\.Totem)$" },
        tag   = "+hyprglass_disabled",
    })
end
