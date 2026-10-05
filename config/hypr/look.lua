-- =============================================================================
-- Appearance & Decoration (Sweet / Garuda Dragonized palette)
-- =============================================================================

hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 12,
        border_size = 2,

        col = {
            -- Brand gradient: 135deg, accent (#c50ed2) -> violet (#7c3aed) -> cyan (#00c1e4)
            active_border   = { colors = { "rgba(c50ed2ff)", "rgba(7c3aedff)", "rgba(00c1e4ff)" }, angle = 135 },
            inactive_border = "rgba(262838cc)", -- outline #262838
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 14,
        rounding_power = 2.0,

        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = 0x88000000,
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            vibrancy          = 0.1696,
            noise             = 0.0117,
            contrast          = 0.8916,
            brightness        = 0.8172,
            popups            = true,
            new_optimizations = true,
            -- NOTE: decoration.blur.variant (frost, acrylic, etc.) and blur.glass.* / blur.acrylic.*
            -- DO NOT exist on Hyprland 0.56.2 stable (git-only).
            -- Standard Kawase dual-filter blur is used here.
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        vfr                      = true,
        background_color         = 0x0b0c14, -- #0b0c14
    },
})
