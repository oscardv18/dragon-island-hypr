#!/usr/bin/env bash
# dragon-island — phase 4 migrations in a temporary HOME: 025 adds only the missing settings and keeps the user's,
# 026 replaces a stale copied config (with a backup) and leaves a current one alone; both idempotent (exit 10).
set -Euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "✔ $*"; }
bad() { echo "✘ $*"; fails=$((fails + 1)); }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
mig() { env -u HYPRLAND_INSTANCE_SIGNATURE HOME="$T" XDG_CONFIG_HOME="" XDG_STATE_HOME="" ASSUME_YES=true "$@" >/dev/null 2>&1; }

mkdir -p "$T/.config/dragon-island"
s="$T/.config/dragon-island/settings.json"
echo '{"switcherOrbital":false,"barStyle":"C"}' > "$s"
mig bash "$REPO_DIR/migrations/025-gravity-launcher-settings.sh"; code=$?
check "025 aplica (código $code)" test "$code" -eq 0
check "025 añade lo que falta y respeta switcherOrbital=false" \
    test "$(jq -c '[.launcherGravity, .switcherOrbital, .reduceMotion, .barStyle]' "$s")" = '[true,false,false,"C"]'
mig bash "$REPO_DIR/migrations/025-gravity-launcher-settings.sh"; code=$?
check "025 es idempotente (código $code)" test "$code" -eq 10
rm -f "$s"
mig env DRY_RUN=true bash "$REPO_DIR/migrations/025-gravity-launcher-settings.sh"
check "025 en dry-run no escribe" test ! -e "$s"

cp -r "$REPO_DIR/config/hypr" "$T/.config/hypr"
cp -r "$REPO_DIR/config/quickshell" "$T/.config/quickshell"
mig bash "$REPO_DIR/migrations/026-switcher-keybinds.sh"; code=$?
check "026 no toca una copia al día (código $code)" test "$code" -eq 10
sed -i 's/qs ipc call switcher next/OLD/' "$T/.config/hypr/binds.lua"
mig bash "$REPO_DIR/migrations/026-switcher-keybinds.sh"; code=$?
check "026 aplica (código $code)" test "$code" -eq 0
check "026 pone los atajos nuevos" grep -q 'qs ipc call switcher next' "$T/.config/hypr/binds.lua"
# shellcheck disable=SC2329  # called through check
has_backup() { compgen -G "$T/.local/state/dragon-island/backups/*/.config/hypr/binds.lua" >/dev/null; }
check "026 guardó copia" has_backup
mig bash "$REPO_DIR/migrations/026-switcher-keybinds.sh"; code=$?
check "026 es idempotente (código $code)" test "$code" -eq 10
exit $(( fails > 0 ))
