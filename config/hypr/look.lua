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
        inactive_opacity = 1.0,   -- 0.95 made every inactive window translucent: it would get the liquid glass whenever it lost focus

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = 0x88000000,
        },

        -- Native blur (no plugin). Only 0.56.2 options: blur.variant / acrylic / glass are git-only.
        -- It applies to layers through the layer rules in rules.lua (bar, popovers, notifications, launcher).
        blur = {
            enabled           = true,
            size              = 8,      -- kernel radius per pass; bigger = softer, more GPU
            passes            = 3,      -- Kawase iterations; 3 is the quality / cost sweet spot
            vibrancy          = 0.17,   -- boosts saturation of what shows through the blur
            noise             = 0.02,   -- fine grain on top: the "frosted acrylic" feel, hides banding
            contrast          = 0.9,    -- <1 flattens the blurred background so text stays readable
            brightness        = 0.85,   -- <1 darkens the blurred background (matches the dark palette)
            popups            = true,   -- also blur xdg popups / context menus
            new_optimizations = true,   -- cache the blur of static windows (big GPU saving)
        },
    },

    dwindle = {
        preserve_split = true,
    },

    -- Scrolling: the native layout of 0.56 (columns on a horizontal tape), the second tiling mode. Which workspaces use
    -- it is chosen at run time (SUPER + T, scripts/tiling.sh); dwindle stays the default. Same gaps / border / rounding.
    scrolling = {
        fullscreen_on_one_column = true,   -- a single column fills the screen
        column_width             = 0.5,    -- default width of a column
        -- focus_fit_method      = 1,      -- 0 = centre the focused column, 1 = just fit it into view
        -- follow_focus          = true,   -- scroll the tape to the window that gets the focus
        -- follow_min_visible    = 0.4,
        -- explicit_column_widths = "0.333, 0.5, 0.667, 1.0",   -- what SUPER + R cycles through
        -- wrap_focus            = true,   -- left / right past the last column wraps around
        -- wrap_swapcol          = true,
        -- direction             = "right",
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = 0xff0b0c14, -- bg #0b0c14 (0xAARRGGBB)
        allow_session_lock_restore = true,     -- if the lock client dies, a new one (hyprlock) can take the lock back
    },
})
