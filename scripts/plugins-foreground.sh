#!/usr/bin/env bash
# =============================================================================
# dragon-island — plugins via hyprpm (hyprfocus from hyprland-plugins, and hyprglass). No hyprbars any more: the
# windows have no title bar (Quickshell draws their frame); an old install has it disabled here and by migration 037.
# MUST run in the foreground of a terminal INSIDE Hyprland: `hyprpm update` writes to /var/cache/hyprpm through a root
# helper and asks for the sudo password, so it fails under autostart or `gum spin`. Launched by modules/plugins.sh
# (inside Hyprland) or by autostart.lua in a visible Ghostty window while plugins.pending exists.
# hyprpm installs the commit/release pinned for the running Hyprland (7644cec / v0.9.1 for 0.56.x, see
# docs/TESTED-VERSIONS.md). Repeat `hyprpm update` after every Hyprland update.
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
PENDING="$STATE_DIR/plugins.pending"
LOG="$STATE_DIR/plugins.log"
PLUGINS_REPO="https://github.com/hyprwm/hyprland-plugins"
GLASS_REPO="https://github.com/hyprnux/hyprglass"
GLASS_EXPECTED="0.9.1"

# In the repo the helper is in ../lib; installed copies have it beside this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SESSION_HELPER="$SCRIPT_DIR/../lib/hyprland-session.sh"
[[ -f "$SESSION_HELPER" ]] || SESSION_HELPER="$STATE_DIR/hyprland-session.sh"
# shellcheck source=lib/hyprland-session.sh
. "$SESSION_HELPER"

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

# Keep a failed rebuild pending, including when a stale terminal cannot reach Hyprland.
touch "$PENDING"
if ! hyprland_session; then
    echo "ERROR: no se puede conectar con Hyprland. Abre una terminal nueva en Hyprland y ejecuta scripts/plugins-foreground.sh. Los plugins quedan pendientes." >&2
    exit 1
fi

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a "dragon-island" "$@" || true; }
finish() { if [[ -t 0 && -t 1 ]]; then echo; read -rp "Pulsa Enter para cerrar esta ventana..." _ || true; fi; }
trap finish EXIT

# hyprpm is not re-entrant
exec 9>"$STATE_DIR/hyprpm.lock"
flock 9

echo "==> dragon-island: plugins (hyprfocus, hyprglass)"
if ! command -v hyprpm >/dev/null 2>&1; then
    echo "ERROR: hyprpm no está instalado (en Arch es el paquete 'hyprpm'). Ejecuta: sudo pacman -S hyprpm" >&2
    notify "Plugins" "Falta el paquete hyprpm"
    exit 1
fi

echo "==> Cabeceras de Hyprland (hyprpm update; pide tu contraseña)..."
hyprpm update || { echo "ERROR: hyprpm update falló. Se reintentará en el próximo inicio de sesión." >&2; notify "Plugins" "hyprpm update falló. Revisa $LOG"; exit 1; }

listing="$(hyprpm list 2>/dev/null || true)"
grep -q "hyprland-plugins" <<<"$listing" || { echo "==> Añadiendo $PLUGINS_REPO ..."; hyprpm add "$PLUGINS_REPO"; }
grep -q "HyprGlass\|hyprglass" <<<"$listing" || { echo "==> Añadiendo $GLASS_REPO ..."; hyprpm add "$GLASS_REPO"; }

for p in hyprfocus hyprglass; do echo "==> Habilitando $p..."; hyprpm enable "$p"; done
# title bars are gone: an older install still has hyprbars enabled
hyprpm disable hyprbars >/dev/null 2>&1 || true

echo "==> Cargando los plugins y recargando la configuración..."
hyprpm reload -n
hyprctl reload

loaded="$(hyprctl plugin list 2>/dev/null || true)"
for p in hyprfocus hyprglass; do
    grep -qi "$p" <<<"$loaded" || { echo "ERROR: $p no aparece cargado. Revisa: hyprpm list · $LOG" >&2; notify "Plugins" "$p no se cargó. Revisa $LOG"; exit 1; }
done
grep -A4 -i "plugin hyprglass" <<<"$loaded" | grep -q "$GLASS_EXPECTED" \
    || echo "AVISO: la versión cargada de hyprglass no es la $GLASS_EXPECTED fijada para Hyprland 0.56.x (mira la línea Version de arriba)." >&2

rm -f "$PENDING" "$STATE_DIR/glass.pending"
touch "$STATE_DIR/firstrun.done"
notify "Plugins listos" "hyprfocus y hyprglass están activos."
echo "==> Listo. Si algo falla: hyprpm disable <plugin>"
