-- =============================================================================
-- Tiling modes: dwindle (default) <-> scrolling, per workspace. The state lives in
-- ~/.local/state/dragon-island/tiling.json and is written / applied by scripts/tiling.sh
-- (installed as ~/.local/bin/dragon-tiling). Workspace rules set at run time are lost when the
-- session restarts or the config is reloaded, so both events re-apply the saved modes.
-- A missing or corrupt file means "everything dwindle" (the script just does nothing).
-- =============================================================================

local restore = "$HOME/.local/bin/dragon-tiling restore"

hl.on("hyprland.start", function() hl.exec_cmd(restore) end)
hl.on("config.reloaded", function() hl.exec_cmd(restore) end)
