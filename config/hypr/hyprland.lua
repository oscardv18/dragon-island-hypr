-- =============================================================================
-- dragon-island — Hyprland Configuration (Hyprland 0.56.x stable)
-- Pure Lua configuration. hyprlang (.conf) is deprecated since 0.55.
-- =============================================================================

-- Modular configuration components
require("monitors")
require("env")
require("input")
require("look")
require("animations")
require("rules")
require("binds")
require("plugins")
require("glass")   -- hyprglass (optional): a no-op when the plugin is not loaded
require("autostart")
