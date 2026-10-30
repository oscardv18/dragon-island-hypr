#!/usr/bin/env bash
# dragon-island — phase 4 migrations in a temporary HOME: 025 adds only the missing settings and keeps the user's,
# 027 removes the Alt+Shift layout toggle from a copied input.lua and from the installer block of local.lua only;
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

# 027: Alt+Shift leaves kb_options (copied input.lua and the installer's block in local.lua; the user's lines stay)
rm -rf "$T/.config/hypr" "$T/.local/state"
mkdir -p "$T/.config/hypr"
printf '        kb_options = "ctrl:nocaps,grp:alt_shift_toggle",\n' > "$T/.config/hypr/input.lua"
printf '%s\n' '-- mine: grp:alt_shift_toggle' '-- >>> dragon-island:keyboard' \
    'hl.config({ input = { kb_layout = "us,es", kb_variant = ",", kb_options = "grp:alt_shift_toggle" } })' \
    '-- <<< dragon-island:keyboard' > "$T/.config/hypr/local.lua"
mig bash "$REPO_DIR/migrations/027-no-alt-shift-layout.sh"; code=$?
check "027 aplica (código $code)" test "$code" -eq 0
check "027 quita el conmutador y deja las demás opciones" grep -q 'kb_options = "ctrl:nocaps",' "$T/.config/hypr/input.lua"
check "027 limpia el bloque del instalador" grep -q 'kb_options = "" }' "$T/.config/hypr/local.lua"
check "027 no toca las líneas del usuario" grep -qx -- '-- mine: grp:alt_shift_toggle' "$T/.config/hypr/local.lua"
# shellcheck disable=SC2329  # called through check
has_input_backup() { compgen -G "$T/.local/state/dragon-island/backups/*/.config/hypr/input.lua" >/dev/null; }
check "027 guardó copia" has_input_backup
mig bash "$REPO_DIR/migrations/027-no-alt-shift-layout.sh"; code=$?
check "027 es idempotente (código $code)" test "$code" -eq 10
rm -f "$T/.config/hypr/input.lua" "$T/.config/hypr/local.lua"
ln -s "$REPO_DIR/config/hypr/input.lua" "$T/.config/hypr/input.lua"
mig bash "$REPO_DIR/migrations/027-no-alt-shift-layout.sh"; code=$?
check "027 no toca un input.lua enlazado al repo (código $code)" test "$code" -eq 10
check "el input.lua del repo ya no lo trae" bash -c "! grep -q 'kb_options.*grp:alt_shift_toggle' '$REPO_DIR/config/hypr/input.lua'"
exit $(( fails > 0 ))
