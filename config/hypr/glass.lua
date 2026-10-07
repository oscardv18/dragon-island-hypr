-- =============================================================================
-- hyprglass (optional): acrylic / "liquid glass" behind the Quickshell layers
-- Plugin: https://github.com/hyprnux/hyprglass  (hyprpm installs v0.9.1 for Hyprland 0.56.2)
-- Installed by the optional "Efecto cristal (hyprglass)" component of install.sh.
-- Everything is guarded: without the plugin nothing here runs and the native blur
-- (decoration.blur + layer rules in look.lua / rules.lua) is all you get.
-- Glass shows only where a Quickshell window asks for blur (BackgroundEffect.blurRegion on each
-- bar island, popover, notification card and launcher card), hence mask_mode = "region".
-- =============================================================================

if hl.plugin and hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        default_theme = "dark",
        -- soft magenta tint (0xRRGGBBAA, accent #c50ed2 at alpha 0x14 ≈ 8 %): the last two digits are the strength
        tint_color    = 0xc50ed214,
        layers        = { enabled = true },
    })

    -- Own preset for the shell: more blur than `pomme`, moderate refraction and chromatic
    -- aberration so the text on top stays readable.
    hg.preset("dragon-bar", {
        inherits             = "pomme",
        blur_strength        = 2.8,   -- blur radius scale (× 12 px)
        blur_iterations      = 4,     -- gaussian passes
        refraction_strength  = 0.35,  -- edge refraction, moderate
        chromatic_aberration = 0.2,   -- color fringing at the edges, moderate
        specular_strength    = 0.5,
        fresnel_strength     = 0.4,
        tint_color           = 0xc50ed214,
    })

    -- Layers that get glass (the preset applies to each namespace). One system per layer: the native
    -- blur rule of rules.lua is switched off for the same namespace (hyprglass replaces it anyway).
    for _, ns in ipairs({ "dragon-bar", "dragon-popover", "dragon-notifications", "dragon-launcher" }) do
        hg.layer(ns, { preset = "dragon-bar", mask_mode = "region" })
        if DragonBlurRules and DragonBlurRules[ns] then DragonBlurRules[ns]:set_enabled(false) end
    end

    -- The notch must stay opaque black
    hg.layer("dragon-island", { exclude = true })

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
