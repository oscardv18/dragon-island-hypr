-- =============================================================================
-- Window frame feed (ajuste de ventanas): the real geometry of the focused window, for the frame Quickshell draws
-- around it (config/quickshell/services/WindowFrame.qml + modules/frame/FrameWindow.qml: a top line and four cyan
-- corner brackets, the same FrameDecor as the popovers).
--
-- Hyprland has no IPC event for "a window moved / was resized" (drag, resize, a tiled neighbour opening…), so this
-- reads it here, in the compositor, where it is cheap: on the focus / workspace / fullscreen events right away, and
-- with a light timer that only compares numbers. The file is written ONLY when something changed, so Quickshell (an
-- inotify watch, no timer) redraws only when the geometry or the focus really change.
--
-- $XDG_RUNTIME_DIR/dragon-window-frame, one line, tab-separated:
--   address  x  y  width  height  fullscreen  floating  monitor  workspace  rounding  border
-- (x / y local to the monitor, logical px, the window's own box without the border; fullscreen = Hyprland's mode:
-- 0 none, 1 maximized, 2 fullscreen, 3 both) — or "none" when no window has the focus.
-- =============================================================================

local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/dragon-window-frame"
local POLL_MS = 50   -- 20 checks per second: smooth enough to follow a drag, nothing when the numbers do not change

local last = nil
local deco = { rounding = 0, border = 0 }

local function read_deco()
    local ok_r, r = pcall(hl.get_config, "decoration.rounding")
    local ok_b, b = pcall(hl.get_config, "general.border_size")
    deco.rounding = ok_r and tonumber(r) or 0
    deco.border = ok_b and tonumber(b) or 0
end

local function snapshot()
    local w = hl.get_active_window()
    if not w or not w.mapped or w.hidden then return "none" end
    local m = w.monitor
    if not m then return "none" end
    return table.concat({
        tostring(w.address),
        math.floor(w.at.x - m.x + 0.5), math.floor(w.at.y - m.y + 0.5),
        math.floor(w.size.x + 0.5), math.floor(w.size.y + 0.5),
        tostring(w.fullscreen or 0), w.floating and "1" or "0",
        tostring(m.name), w.workspace and tostring(w.workspace.name) or "",
        tostring(deco.rounding), tostring(deco.border),
    }, "\t")
end

local function publish()
    local ok, line = pcall(snapshot)
    if not ok or line == last then return end
    local f = io.open(path, "w")
    if not f then return end
    f:write(line, "\n")
    f:close()
    last = line
end

read_deco()

for _, ev in ipairs({ "window.active", "window.open", "window.close", "window.fullscreen", "window.move_to_workspace",
                      "window.minimize", "workspace.active", "workspace.special_active", "monitor.layout_changed" }) do
    hl.on(ev, publish)
end
hl.on("config.reloaded", function()
    read_deco()
    last = nil
    publish()
end)

hl.timer(publish, { timeout = POLL_MS, type = "repeat" })
publish()
