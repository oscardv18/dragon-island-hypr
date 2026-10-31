#!/usr/bin/env bash
# dragon-island — migrations of the «ajuste de ventanas» in a temporary HOME (no live Hyprland):
#   036 refreshes a stale copied glass.lua / rules.lua with a backup, leaves a current copy alone, writes nothing in
#   dry-run and is idempotent (exit 10). 037 does the same for plugins.lua / rules.lua / autostart.lua and the copied
#   plugins-foreground.sh (no hyprbars left), and asks hyprpm to disable hyprbars only when it is enabled (a stub
#   hyprpm here: the real one is never called). 038 brings framewatch.lua / hyprland.lua / look.lua to a copied config
#   (a stale 2 px border included), with a backup, idempotent.
set -Euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "✔ $*"; }
bad() { echo "✘ $*"; fails=$((fails + 1)); }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
mig() { env -u HYPRLAND_INSTANCE_SIGNATURE HOME="$T" XDG_CONFIG_HOME="" XDG_STATE_HOME="" ASSUME_YES=true "$@" >/dev/null 2>&1; }
# shellcheck disable=SC2329  # called through check
has_backup() { compgen -G "$T/.local/state/dragon-island/backups/*/.config/hypr/$1" >/dev/null; }

# ---- 036: native blur on windows ----
mkdir -p "$T/.config"
cp -r "$REPO_DIR/config/hypr" "$T/.config/hypr"
mig bash "$REPO_DIR/migrations/036-window-blur.sh"; code=$?
check "036 no toca una copia al día (código $code)" test "$code" -eq 10
sed -i '/manage_window_blur = false,/d' "$T/.config/hypr/glass.lua"
cp "$T/.config/hypr/glass.lua" "$T/stale-glass.lua"
mig env DRY_RUN=true bash "$REPO_DIR/migrations/036-window-blur.sh"
check "036 en dry-run no escribe" cmp -s "$T/.config/hypr/glass.lua" "$T/stale-glass.lua"
mig bash "$REPO_DIR/migrations/036-window-blur.sh"; code=$?
check "036 aplica (código $code)" test "$code" -eq 0
check "036 apaga manage_window_blur fuera de líquido" grep -q 'manage_window_blur = false,' "$T/.config/hypr/glass.lua"
check "036 guardó copia" has_backup glass.lua
mig bash "$REPO_DIR/migrations/036-window-blur.sh"; code=$?
check "036 es idempotente (código $code)" test "$code" -eq 10

# ---- 037: no title bars ----
rm -rf "$T/.config/hypr" "$T/.local/state"
cp -r "$REPO_DIR/config/hypr" "$T/.config/hypr"
mkdir -p "$T/bin" "$T/.local/state/dragon-island"
cp "$REPO_DIR/scripts/plugins-foreground.sh" "$T/.local/state/dragon-island/plugins-foreground.sh"
# shellcheck disable=SC2016  # the stub's own $1 / $HOME, expanded when it runs
printf '%s\n' '#!/bin/sh' 'case "$1" in list) [ -f "$HOME/bars-on" ] && printf "  │ Plugin hyprbars\n  └─ enabled: true\n" ;; disable) rm -f "$HOME/bars-on"; echo "$2" >> "$HOME/disabled" ;; esac' > "$T/bin/hyprpm"
chmod +x "$T/bin/hyprpm"
mig037() { mig env PATH="$T/bin:$PATH" "$@" bash "$REPO_DIR/migrations/037-no-titlebars.sh"; }
mig037; code=$?
check "037 no toca nada al día y sin hyprbars (código $code)" test "$code" -eq 10
printf '%s\n' 'hl.plugin.hyprbars.add_button({})' >> "$T/.config/hypr/plugins.lua"
# shellcheck disable=SC2016  # literal line of the stale script
echo 'for p in hyprbars hyprfocus hyprglass; do hyprpm enable "$p"; done' >> "$T/.local/state/dragon-island/plugins-foreground.sh"
touch "$T/bars-on"
cp "$T/.config/hypr/plugins.lua" "$T/stale-plugins.lua"
mig037 DRY_RUN=true
check "037 en dry-run no escribe ni desactiva" test "$(cmp -s "$T/.config/hypr/plugins.lua" "$T/stale-plugins.lua" && echo same)-$([[ -e "$T/disabled" ]] && echo called)" = "same-"
mig037; code=$?
check "037 aplica (código $code)" test "$code" -eq 0
check "037 quita hyprbars de plugins.lua" cmp -s "$REPO_DIR/config/hypr/plugins.lua" "$T/.config/hypr/plugins.lua"
check "037 renueva plugins-foreground.sh copiado" cmp -s "$REPO_DIR/scripts/plugins-foreground.sh" "$T/.local/state/dragon-island/plugins-foreground.sh"
check "037 desactiva hyprbars en hyprpm" grep -qx hyprbars "$T/disabled"
check "037 guardó copia" has_backup plugins.lua
mig037; code=$?
check "037 es idempotente (código $code)" test "$code" -eq 10

# ---- 038: window frame ----
rm -rf "$T/.config/hypr" "$T/.local/state"
cp -r "$REPO_DIR/config/hypr" "$T/.config/hypr"
mig bash "$REPO_DIR/migrations/038-window-frame.sh"; code=$?
check "038 no toca una copia al día (código $code)" test "$code" -eq 10
rm -f "$T/.config/hypr/framewatch.lua"
sed -i 's/border_size = 1,/border_size = 2,/' "$T/.config/hypr/look.lua"
mig env DRY_RUN=true bash "$REPO_DIR/migrations/038-window-frame.sh"
check "038 en dry-run no escribe" test ! -e "$T/.config/hypr/framewatch.lua"
mig bash "$REPO_DIR/migrations/038-window-frame.sh"; code=$?
check "038 aplica (código $code)" test "$code" -eq 0
check "038 instala framewatch.lua" cmp -s "$REPO_DIR/config/hypr/framewatch.lua" "$T/.config/hypr/framewatch.lua"
check "038 deja el borde de 1 px" grep -q 'border_size = 1,' "$T/.config/hypr/look.lua"
check "038 guardó copia" has_backup look.lua
mig bash "$REPO_DIR/migrations/038-window-frame.sh"; code=$?
check "038 es idempotente (código $code)" test "$code" -eq 10

echo
if ((fails == 0)); then echo "migraciones del ajuste de ventanas: OK"; else echo "$fails comprobación(es) fallan"; fi
exit "$fails"
