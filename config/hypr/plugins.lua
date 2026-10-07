-- =============================================================================
-- Hyprland Plugins (hyprbars & hyprfocus)
-- Pinned for Hyprland 0.56.x stable via hyprpm
-- =============================================================================

hl.config({
    plugin = {
        hyprbars = {
            bar_height                 = 30,
            bar_color                  = "rgba(161925ee)", -- surface0 (#161925)
            ["col.text"]               = "rgb(e6e8ef)",    -- text (#e6e8ef)
            bar_text_font              = "Outfit",
            bar_text_size              = 11,
            bar_text_weight            = "medium",
            bar_text_align             = "center",
            bar_buttons_alignment      = "left",
            bar_blur                   = true,
            bar_part_of_window         = true,
            bar_precedence_over_border = true,
            bar_padding                = 12,
            bar_button_padding         = 8,
            icon_on_hover              = true,
            inactive_button_color      = "rgb(3a3d55)",    -- muted (#3a3d55)
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
    -- Left buttons: close (error #ed254e), fullscreen (warn #f9ae58), float (ok #06c993)
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(ed254e)", fg_color = "rgb(ffffff)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(f9ae58)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(06c993)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']] })
end

-- hyprfocus animations guard
if hl.plugin and hl.plugin.hyprfocus then
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.7, bezier = "easeOutQuint" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "easeOutQuint" })
end

-- Ghostty is a see-through liquid-glass window: its hyprbars title bar must not be a solid strip on top.
-- A transparent bar keeps the close / fullscreen / float buttons and the title (dynamic hyprbars rule).
if hl.plugin and hl.plugin.hyprbars then
    hl.window_rule({
        name  = "ghostty-transparent-bar",
        match = { class = "^com\\.mitchellh\\.ghostty$" },
        ["hyprbars:bar_color"] = "rgba(00000000)",
    })
end
