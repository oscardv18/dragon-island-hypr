#!/usr/bin/env bash
# =============================================================================
# dragon-island — plugins via hyprpm (hyprfocus from hyprland-plugins, and hyprglass). No hyprbars any more: the
# windows have no title bar (Quickshell draws their frame); an old install has it disabled here and by migration 037.
# MUST run in the foreground of a terminal INSIDE Hyprland: `hyprpm update` writes to /var/cache/hyprpm through a root
# helper and asks for the sudo password, so it fails under autostart or `gum spin`. Launched by modules/plugins.sh
# (inside Hyprland) or by autostart.lua in a visible Ghostty window while plugins.pending exists.
# hyprpm installs the commit/release pinned for the running Hyprland (see
# docs/TESTED-VERSIONS.md). Repeat `hyprpm update` after every Hyprland update.
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
PENDING="$STATE_DIR/plugins.pending"
LOG="$STATE_DIR/plugins.log"
PLUGINS_REPO="https://github.com/hyprwm/hyprland-plugins"
GLASS_REPO="https://github.com/hyprnux/hyprglass"
GLASS_EXPECTED="$(declare -F pin_get >/dev/null && pin_get hyprglass || true)"   # empty: no pinned version to compare

# In the repo the helper is in ../lib; installed copies have it beside this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SESSION_HELPER="$SCRIPT_DIR/../lib/hyprland-session.sh"
[[ -f "$SESSION_HELPER" ]] || SESSION_HELPER="$STATE_DIR/hyprland-session.sh"
# shellcheck source=lib/hyprland-session.sh
. "$SESSION_HELPER"
PINS_HELPER="$SCRIPT_DIR/../lib/pins.sh"
[[ -f "$PINS_HELPER" ]] || PINS_HELPER="$STATE_DIR/pins.sh"
# shellcheck source=lib/pins.sh
[[ -f "$PINS_HELPER" ]] && . "$PINS_HELPER"

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

# Keep a failed rebuild pending, including when a stale terminal cannot reach Hyprland.
touch "$PENDING"
if ! hyprland_session; then
    echo "ERROR: no se puede conectar con Hyprland. Abre una terminal nueva en Hyprland y ejecuta scripts/plugins-foreground.sh. Los plugins quedan pendientes." >&2
    exit 1
fi

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a "dragon-island" "$@" || true; }
# First-run step (autostart.lua launches this while plugins.pending exists): the user sees what is going on through notifications.
DONE=false
finish() {
    local rc=$?
    if ! $DONE && (( rc != 0 )); then notify "Plugins con error" "No se pudieron compilar los plugins. Se reintenta en el próximo inicio de sesión. Registro: $LOG"; fi
    if [[ -t 0 && -t 1 ]]; then echo; read -rp "Pulsa Enter para cerrar esta ventana..." _ || true; fi
}
trap finish EXIT

# hyprpm is not re-entrant
exec 9>"$STATE_DIR/hyprpm.lock"
flock 9

notify "Compilando plugins…" "hyprfocus y hyprglass: puede tardar unos minutos. Si pide la contraseña, escríbela en la ventana que se abre."
echo "==> dragon-island: plugins (hyprfocus, hyprglass)"
if ! command -v hyprpm >/dev/null 2>&1; then
    echo "ERROR: hyprpm no está instalado (en Arch es el paquete 'hyprpm'). Ejecuta: sudo pacman -S hyprpm" >&2
   
    exit 1
fi

# The plugins and plugins.lua are written for one Hyprland series (packages/pins.json): compiling against another would build
# something that cannot load. Stop BEFORE compiling and say what to do; the step stays pending.
if declare -F hyprland_pin_check >/dev/null; then
    pin_msg="$(hyprland_pin_check)"; pin_rc=$?
    echo "==> Versión: $pin_msg"
    if (( pin_rc == 1 )); then
        echo "ERROR: la versión de Hyprland no es la fijada. No se compila nada. Qué hacer:" >&2
        echo "  1) cd al repositorio y git pull (puede traer ya la versión nueva fijada), luego ./update.sh" >&2
        echo "  2) si ya estás al día: tu Hyprland es más nuevo/viejo que lo probado; alinea el paquete (sudo pacman -Syu) o espera la actualización del repo" >&2
        exit 1
    fi
fi

echo "==> Cabeceras de Hyprland (hyprpm update; pide tu contraseña)..."
hyprpm update || { echo "ERROR: hyprpm update falló. Se reintentará en el próximo inicio de sesión." >&2; exit 1; }

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
    grep -qi "$p" <<<"$loaded" || { echo "ERROR: $p no aparece cargado. Revisa: hyprpm list · $LOG" >&2; exit 1; }
done
if [[ -n "$GLASS_EXPECTED" ]]; then
    grep -A4 -i "plugin hyprglass" <<<"$loaded" | grep -q "$GLASS_EXPECTED" \
        || echo "AVISO: la versión cargada de hyprglass no es la $GLASS_EXPECTED fijada (mira la línea Version de arriba)." >&2
fi

rm -f "$PENDING" "$STATE_DIR/glass.pending"
touch "$STATE_DIR/firstrun.done"
DONE=true
notify "Plugins listos" "hyprfocus y hyprglass están activos."
echo "==> Listo. Si algo falla: hyprpm disable <plugin>"
