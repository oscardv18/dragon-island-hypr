-- =============================================================================
-- Hyprland Plugins (hyprfocus; hyprglass lives in glass.lua)
-- Pinned for Hyprland 0.56.x stable via hyprpm
--
-- No title bars: hyprbars is gone (ajuste de ventanas, migration 037). Windows get the frame of the popovers instead
-- — a thin top line and four cyan corner brackets drawn by Quickshell (modules/frame/FrameWindow.qml) — plus a 1 px
-- native border (look.lua). Close / maximize / float / minimize are SUPER + Q / F / SHIFT + Space / M.
-- =============================================================================

hl.config({
    plugin = {
        hyprfocus = {
            -- none: "shrink" also fired on every workspace switch (focus moves to that workspace's window), so the
            -- windows shrank and grew back each time
            keyboard_focus_animation = "none",
            mouse_focus_animation    = "none",
            shrink_percentage        = 0.97,
        },
    },
})

-- Safety net for an install where hyprbars is still enabled in hyprpm (disabling it needs the password, migration
-- 037 asks): while it is loaded, no window gets its bar. Nothing else of hyprbars is configured any more.
if hl.plugin and hl.plugin.hyprbars then
    hl.window_rule({
        name               = "no-titlebars",
        match              = { class = ".*" },
        ["hyprbars:no_bar"] = true,
    })
end

-- hyprfocus animations guard
if hl.plugin and hl.plugin.hyprfocus then
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.7, bezier = "easeOutQuint" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "easeOutQuint" })
end
