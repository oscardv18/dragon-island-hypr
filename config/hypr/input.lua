-- =============================================================================
-- Input Configuration & Touchpad Gestures
-- =============================================================================

hl.config({
    input = {
        kb_layout  = "es,us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 to 1.0, 0 means no modification

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },

    gestures = {
        workspace_swipe          = true,
        workspace_swipe_fingers  = 3,
        workspace_swipe_distance = 300,
        workspace_swipe_invert   = true,
    },
})
