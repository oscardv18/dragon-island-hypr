#!/usr/bin/env bash
# =============================================================================
# dragon-island — hyprpm first-run setup script
# Runs once inside an active Hyprland graphical session to build and enable plugins.
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
MARKER="$STATE_DIR/firstrun.done"
LOG="$STATE_DIR/firstrun.log"

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

if [[ -f "$MARKER" ]]; then
    exit 0
fi

# Ensure running inside Hyprland
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "Aviso: no se detectó una sesión activa de Hyprland. Se pospone la configuración de plugins."
    exit 0
fi

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "dragon-island" "$@"
    fi
}

notify "dragon-island" "Compilando e inicializando plugins de Hyprland (hyprbars, hyprfocus)..."

echo "==> Actualizando cabeceras de Hyprland con hyprpm..."
if hyprpm update; then
    echo "==> Agregando repositorio oficial hyprland-plugins..."
    if ! hyprpm list 2>/dev/null | grep -q "hyprland-plugins"; then
        hyprpm add https://github.com/hyprwm/hyprland-plugins || true
    fi

    echo "==> Habilitando hyprbars..."
    hyprpm enable hyprbars || true

    echo "==> Habilitando hyprfocus..."
    hyprpm enable hyprfocus || true

    echo "==> Recargando plugins en la sesión activa..."
    hyprpm reload -n || true

    notify "dragon-island" "Plugins de Hyprland instalados y activados con éxito."
    touch "$MARKER"
    echo "==> Primer arranque completado con éxito."
else
    notify "dragon-island" "Aviso: 'hyprpm update' falló. Revisa $LOG"
    echo "Error: hyprpm update no pudo completar la compilación de cabeceras." >&2
fi
