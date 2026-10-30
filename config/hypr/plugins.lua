-- =============================================================================
-- Hyprland Plugins (hyprbars & hyprfocus)
-- Pinned for Hyprland 0.56.x stable via hyprpm
-- =============================================================================

hl.config({
    plugin = {
        hyprbars = {
            bar_height                 = 30,
            bar_color                  = "rgba(161925ee)", -- surface0 (#161925)
            ["col.text"]               = "rgb(edebf5)",    -- text (#edebf5)
            bar_text_font              = "Outfit",
            bar_text_size              = 11,
            bar_text_weight            = "medium",
            bar_text_align             = "center",
            bar_buttons_alignment      = "left",
            -- off: with bar_blur the bar's native blur paints a darker band over the top ~40 px of every
            -- translucent window (the Ghostty glass); the bar color is nearly opaque anyway
            bar_blur                   = false,
            bar_part_of_window         = true,
            bar_precedence_over_border = true,
            bar_padding                = 12,
            bar_button_padding         = 8,
            icon_on_hover              = true,
            inactive_button_color      = "rgba(7f7a9359)", -- muted (#7f7a93) at 35 %
            on_double_click            = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
        },

        hyprfocus = {
            keyboard_focus_animation = "shrink",
            mouse_focus_animation    = "none",
            shrink_percentage        = 0.97,
        },
    },
})

-- Buttons guard: only call once hyprbars is loaded into the Hyprland state
if hl.plugin and hl.plugin.hyprbars then
    -- Left buttons: close, maximize, float, all in textSoft (#c8c4d8) with the icon in islandInk (#05040a) on hover.
    -- The pinned hyprbars has no hover colour per button, so close cannot turn red only on hover: it stays neutral.
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(c8c4d8)", fg_color = "rgb(05040a)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(c8c4d8)", fg_color = "rgb(05040a)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(c8c4d8)", fg_color = "rgb(05040a)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']] })
end

-- hyprfocus animations guard
if hl.plugin and hl.plugin.hyprfocus then
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.7, bezier = "easeOutQuint" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "easeOutQuint" })
end

