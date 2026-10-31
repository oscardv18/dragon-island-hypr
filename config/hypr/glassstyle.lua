-- =============================================================================
-- Glass style (Ajustes › Apariencia › Cristal, services/Glass.qml): which material the Quickshell layers and the
-- translucent windows (Ghostty included) get. Read from ~/.config/dragon-island/glass-style when the config loads;
-- Quickshell writes that file and runs `hyprctl reload` when the user changes it, so the switch is live.
--
--   ahumado  native blur with fine grain (blur.noise), dark fill + a top light edge drawn by Quickshell (default)
--   clasico  native blur without grain, thin border, no light edge
--   liquido  hyprglass (glass.lua), only when the plugin is loaded; otherwise it falls back to ahumado
--
-- Never two blurs on one layer: rules.lua adds the native layer rules for every style but liquido, and glass.lua
-- turns hyprglass off (windows and layers) for every style but liquido.
-- =============================================================================

local M = {}

local valid = { ahumado = true, clasico = true, liquido = true }

local function read_style()
    local dir = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local f = io.open(dir .. "/dragon-island/glass-style", "r")
    if not f then return "ahumado" end
    local text = (f:read("*l") or ""):gsub("%s+", "")
    f:close()
    return valid[text] and text or "ahumado"
end

M.requested = read_style()
M.hyprglass = (hl.plugin and hl.plugin.hyprglass) and true or false
-- what is drawn: liquido without the plugin is ahumado
M.style = (M.requested == "liquido" and not M.hyprglass) and "ahumado" or M.requested
M.liquid = M.style == "liquido"

return M
