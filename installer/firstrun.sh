#!/usr/bin/env bash
# =============================================================================
# dragon-island — first-session setup (hyprpm plugins)
# Launched once by autostart.lua inside a Ghostty window, because hyprpm needs a
# running Hyprland and may ask for the sudo password to install headers.
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
MARKER="$STATE_DIR/firstrun.done"
LOG="$STATE_DIR/firstrun.log"

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

[[ -f "$MARKER" ]] && exit 0

# hyprpm is not re-entrant: wait for glass.sh (hyprglass) if it is running
exec 9>"$STATE_DIR/hyprpm.lock"
flock 9

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "No se detectó una sesión de Hyprland. Se pospone la configuración de plugins."
    exit 0
fi

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "dragon-island" "$@" || true
    fi
}

finish() {
    echo
    read -rp "Pulsa Enter para cerrar esta ventana..." _ || true
}
trap finish EXIT

echo "==> dragon-island: primer arranque"
if ! command -v hyprpm >/dev/null 2>&1; then
    echo "ERROR: hyprpm no está instalado (en Arch es el paquete 'hyprpm'). Ejecuta: sudo pacman -S hyprpm" >&2
    notify "Plugins" "Falta el paquete hyprpm"
    exit 1
fi
echo "==> Descargando cabeceras de Hyprland (hyprpm update)..."
if ! hyprpm update; then
    notify "Plugins" "hyprpm update falló. Revisa $LOG"
    echo "ERROR: hyprpm update falló. Se reintentará en el próximo inicio de sesión." >&2
    exit 1
fi

if ! hyprpm list 2>/dev/null | grep -q "hyprland-plugins"; then
    echo "==> Añadiendo hyprwm/hyprland-plugins..."
    hyprpm add https://github.com/hyprwm/hyprland-plugins
fi

echo "==> Habilitando hyprbars y hyprfocus..."
hyprpm enable hyprbars
hyprpm enable hyprfocus

echo "==> Cargando plugins y recargando la configuración..."
hyprpm reload -n
hyprctl reload

touch "$MARKER"
notify "Plugins listos" "hyprbars y hyprfocus están activos."
echo "==> Listo."
