#!/usr/bin/env bash
# dragon-island — migrations of the «ajuste de ventanas» in a temporary HOME (no live Hyprland):
#   036 refreshes a stale copied glass.lua / rules.lua with a backup, leaves a current copy alone, writes nothing in
#   dry-run and is idempotent (exit 10).
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

echo
if ((fails == 0)); then echo "migraciones del ajuste de ventanas: OK"; else echo "$fails comprobación(es) fallan"; fi
exit "$fails"
