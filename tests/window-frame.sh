#!/usr/bin/env bash
# dragon-island — the frame of the focused window, without a session:
#   * config/hypr/framewatch.lua under plain Lua with a fake `hl`: the feed line has the documented 11 fields (x / y
#     local to the monitor), "none" without a focused window, and the file is written ONLY when something changed
#     (Quickshell redraws on every write, so a write per timer tick would be a redraw per tick).
#   * the 1 px native border of look.lua is the one Theme.frame describes (cyan 30 % / black 30 %, 1 px).
#   * no hyprbars left in the Hyprland config except the safety net of plugins.lua.
set -Euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "✔ $*"; }
bad() { echo "✘ $*"; fails=$((fails + 1)); }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

if command -v lua >/dev/null 2>&1; then
    cat > "$T/run.lua" <<'EOF'
-- a fake hl: one window on a monitor at x = 1366, a timer we tick by hand, events we fire by hand
local handlers, timers = {}, {}
local win = { address = "0xabc", at = { x = 1376, y = 47 }, size = { x = 600, y = 400 }, fullscreen = 0,
              floating = true, mapped = true, hidden = false,
              monitor = { x = 1366, y = 0, name = "HDMI-A-1" }, workspace = { name = "3" } }
local active = win
hl = {
    get_active_window = function() return active end,
    get_config = function(k) return ({ ["decoration.rounding"] = 14, ["general.border_size"] = 1 })[k] end,
    on = function(ev, fn) handlers[ev] = fn end,
    timer = function(fn) timers[#timers + 1] = fn; return {} end,
}
local writes = 0
local real_open = io.open
io.open = function(p, m) if m == "w" then writes = writes + 1 end return real_open(p, m) end
dofile(arg[1])
local function line() local f = real_open(os.getenv("XDG_RUNTIME_DIR") .. "/dragon-window-frame"); local l = f:read("*l"); f:close(); return l end
local function tick() for _, t in ipairs(timers) do t() end end
print("first=" .. line())
local w0 = writes
for _ = 1, 5 do tick() end
print("idle-writes=" .. (writes - w0))
win.at.x = 1400; tick()
print("moved=" .. line() .. " writes=" .. (writes - w0))
active = nil; handlers["window.active"]()
print("none=" .. line())
EOF
    out="$(XDG_RUNTIME_DIR="$T" lua "$T/run.lua" "$REPO_DIR/config/hypr/framewatch.lua" 2>&1)"
    first="$(sed -n 's/^first=//p' <<<"$out")"
    check "framewatch: línea con 11 campos" test "$(awk -F'\t' '{print NF}' <<<"$first")" = 11
    check "framewatch: x / y locales al monitor, borde y radio" test "$first" = "$(printf '0xabc\t10\t47\t600\t400\t0\t1\tHDMI-A-1\t3\t14\t1')"
    check "framewatch: sin cambios no escribe (temporizador en reposo)" grep -qx 'idle-writes=0' <<<"$out"
    check "framewatch: un cambio escribe una vez" grep -q $'^moved=0xabc\t34\t.* writes=1$' <<<"$out"
    check "framewatch: sin ventana enfocada → none" grep -qx 'none=none' <<<"$out"
else
    echo "- lua no está: se omite framewatch.lua"
fi

theme="$REPO_DIR/config/quickshell/Theme.qml" look="$REPO_DIR/config/hypr/look.lua"
cyan="$(sed -n 's/.*readonly property color cyan: *"#\([0-9a-fA-F]\{6\}\)".*/\1/p' "$theme" | head -1)"
check "Theme.frame.borderActive = alpha(cyan, 0.30) y look.lua igual" \
    test "$(grep -c 'borderActive:   root.alpha(root.cyan, 0.30)' "$theme")-$(grep -c "active_border = \"rgba(${cyan,,}4d)\"" "$look")" = "1-1"
check "Theme.frame.borderInactive = negro 30 % y look.lua igual (sin filo claro)" \
    test "$(grep -c 'borderInactive: Qt.rgba(0, 0, 0, 0.30)' "$theme")-$(grep -c 'inactive_border = "rgba(0000004d)"' "$look")" = "1-1"
check "borde nativo de 1 px en los dos" \
    test "$(grep -c 'readonly property real  border:         1$' "$theme")-$(grep -c 'border_size = 1,' "$look")" = "1-1"
check "hyprbars solo queda en la salvaguarda de plugins.lua" \
    test "$(grep -l 'hyprbars' "$REPO_DIR"/config/hypr/*.lua | xargs -n1 basename | tr '\n' ' ')" = "plugins.lua "

echo
if ((fails == 0)); then echo "contorno de ventanas: OK"; else echo "$fails comprobación(es) fallan"; fi
exit "$fails"
