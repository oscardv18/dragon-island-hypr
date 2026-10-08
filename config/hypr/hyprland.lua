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
require("tiling")   -- dwindle <-> scrolling per workspace: restores the saved modes (binds are in binds.lua)
require("plugins")
require("glass")   -- hyprglass (optional): a no-op when the plugin is not loaded
require("autostart")

-- Per-machine overrides (monitors, scale, GPU variables, keyboard layouts), written by install.sh and never
-- versioned (gitignored). Loaded last so it wins over the defaults above; a missing file is fine.
pcall(require, "local")
