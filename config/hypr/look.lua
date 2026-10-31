-- =============================================================================
-- Appearance & Decoration (Sweet / Garuda Dragonized palette)
-- =============================================================================

local glass = require("glassstyle")

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 10,
		-- 1 px, very discreet: the focused window's frame (top line + four cyan corner brackets) is drawn by Quickshell
		-- (framewatch.lua → modules/frame/FrameWindow.qml); this border is what still reads if Quickshell restarts.
		-- Mirrors Theme.frame.border / borderActive / borderInactive. Never a light edge.
		border_size = 1,

		col = {
			active_border = "rgba(67e8f94d)", -- cyan #67e8f9 at 30 % (Theme.frame.borderActive)
			inactive_border = "rgba(0000004d)", -- black 30 %: a dark hairline, no white edge (Theme.frame.borderInactive)
		},

		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 14,
		rounding_power = 2.0,

		active_opacity = 1.0,
		inactive_opacity = 1.0, -- 0.95 made every inactive window translucent: it would get the liquid glass whenever it lost focus

		shadow = {
			enabled = true,
			range = 12,
			render_power = 3,
			color = 0x88000000,
		},

		-- Native blur (no plugin). Only 0.56.2 options: blur.variant / acrylic / glass are git-only.
		-- It applies to translucent windows and, through the layer rules in rules.lua, to the Quickshell layers.
		-- The glass style (glassstyle.lua) only changes the grain: «ahumado» = fine noise (the smoked material of
		-- docs/design/28-emergentes.png), «clasico» = clean blur. With «liquido» hyprglass draws the layers and windows
		-- instead (glass.lua) and this blur stays for anything hyprglass excludes. With the other two, glass.lua turns
		-- hyprglass' manage_window_blur off: left on, it took this blur away from every translucent window.
		blur = {
			enabled = true,
			size = 10, -- kernel radius per pass; bigger = softer, more GPU (the backdrop reads as shapes, not details)
			passes = 3, -- Kawase iterations; 3 is the quality / cost sweet spot
			vibrancy = 0.17, -- boosts saturation of what shows through the blur
			noise = glass.style == "clasico" and 0.0 or 0.03, -- fine grain: the "smoked" feel, also hides banding
			contrast = 0.9, -- <1 flattens the blurred background so text stays readable
			brightness = 0.8, -- <1 darkens the blurred background (matches the dark palette)
			popups = true, -- also blur xdg popups / context menus
			new_optimizations = true, -- cache the blur of static windows (big GPU saving)
		},
	},

	dwindle = {
		preserve_split = true,
	},

	-- Scrolling: the native layout of 0.56 (columns on a horizontal tape), the second tiling mode. Which workspaces use
	-- it is chosen at run time (SUPER + T, scripts/tiling.sh); dwindle stays the default. Same gaps / border / rounding.
	scrolling = {
		fullscreen_on_one_column = true, -- a single column fills the screen
		column_width = 0.5, -- default width of a column
		-- focus_fit_method      = 1,      -- 0 = centre the focused column, 1 = just fit it into view
		-- follow_focus          = true,   -- scroll the tape to the window that gets the focus
		-- follow_min_visible    = 0.4,
		-- explicit_column_widths = "0.333, 0.5, 0.667, 1.0",   -- what SUPER + R cycles through
		-- wrap_focus            = true,   -- left / right past the last column wraps around
		-- wrap_swapcol          = true,
		-- direction             = "right",
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		background_color = 0xff0b0c14, -- bg #0b0c14 (0xAARRGGBB)
		allow_session_lock_restore = true, -- if the lock client dies, a new one (hyprlock) can take the lock back
	},
})
