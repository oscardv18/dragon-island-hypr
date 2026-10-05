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

    -- Only tuning options live under `gestures`; the gestures themselves are hl.gesture() calls
    -- (gestures.workspace_swipe / workspace_swipe_fingers no longer exist on 0.56).
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_invert   = true,
    },
})

-- 3-finger horizontal swipe switches workspaces
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
