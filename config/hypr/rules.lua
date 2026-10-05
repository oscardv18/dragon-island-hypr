-- =============================================================================
-- Window & Layer Rules
-- =============================================================================

-- Suppress maximize events across all applications
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Floating windows for dialogs, settings and utility apps
hl.window_rule({
    name  = "float-utilities",
    match = {
        class = "(pavucontrol|org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent|nm-connection-editor|blueman-manager)",
    },
    float  = true,
    center = true,
})

-- Layer rules for Quickshell components
hl.layer_rule({
    name         = "blur-dragon-bar",
    match        = { namespace = "^dragon-bar$" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name         = "blur-dragon-island",
    match        = { namespace = "^dragon-island$" },
    blur         = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name         = "blur-dragon-popover",
    match        = { namespace = "^dragon-popover$" },
    blur         = true,
    ignore_alpha = 0.5,
})
