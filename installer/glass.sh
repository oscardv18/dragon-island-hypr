#!/usr/bin/env bash
# =============================================================================
# dragon-island — optional component "Efecto cristal (hyprglass)"
# Installs the hyprglass plugin with hyprpm, in the foreground (visible terminal) because hyprpm
# needs a running Hyprland and may ask for the sudo password. Launched by install.sh when it runs
# inside Hyprland, or by autostart.lua at the next Hyprland login while glass.pending exists.
# hyprpm installs the release made for the running Hyprland (v0.9.1 for 0.56.2).
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
PENDING="$STATE_DIR/glass.pending"
LOG="$STATE_DIR/glass.log"
REPO_URL="https://github.com/hyprnux/hyprglass"
EXPECTED_VERSION="0.9.1"   # the release pinned for Hyprland 0.56.2

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "No se detectó una sesión de Hyprland. hyprglass se instalará en el próximo inicio de sesión en Hyprland."
    exit 0
fi

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "dragon-island" "$@" || true
    fi
}

finish() {
    if [[ -t 0 && -t 1 ]]; then
        echo
        read -rp "Pulsa Enter para cerrar esta ventana..." _ || true
    fi
}
trap finish EXIT

# hyprpm is not re-entrant: wait for firstrun.sh (hyprbars / hyprfocus) if it is running
exec 9>"$STATE_DIR/hyprpm.lock"
flock 9

echo "==> dragon-island: efecto cristal (hyprglass)"
if ! command -v hyprpm >/dev/null 2>&1; then
    echo "ERROR: hyprpm no está instalado (en Arch es el paquete 'hyprpm'). Ejecuta: sudo pacman -S hyprpm" >&2
    notify "hyprglass" "Falta el paquete hyprpm"
    exit 1
fi

echo "==> Preparando cabeceras de Hyprland (hyprpm update)..."
hyprpm update || {
    echo "ERROR: hyprpm update falló. Se reintentará en el próximo inicio de sesión." >&2
    notify "hyprglass" "hyprpm update falló. Revisa $LOG"
    exit 1
}

if ! hyprpm list 2>/dev/null | grep -q "hyprglass"; then
    echo "==> Añadiendo $REPO_URL ..."
    hyprpm add "$REPO_URL"
fi

echo "==> Habilitando hyprglass..."
hyprpm enable hyprglass

echo "==> Cargando el plugin y recargando la configuración..."
hyprpm reload -n
hyprctl reload

echo "==> Comprobando con hyprctl plugin list..."
listing="$(hyprctl plugin list 2>/dev/null || true)"
echo "$listing" | grep -A4 -i "hyprglass" || true
if ! grep -qi "hyprglass" <<<"$listing"; then
    echo "ERROR: hyprglass no aparece cargado. Revisa: hyprpm list · $LOG" >&2
    notify "hyprglass" "El plugin no se cargó. Revisa $LOG"
    exit 1
fi
if ! grep -A4 -i "plugin hyprglass" <<<"$listing" | grep -q "$EXPECTED_VERSION"; then
    echo "AVISO: la versión cargada no es la $EXPECTED_VERSION fijada para Hyprland 0.56.2 (mira la línea Version de arriba)." >&2
fi

rm -f "$PENDING"
notify "hyprglass listo" "Efecto cristal activo en la barra, popovers y notificaciones."
echo "==> Listo. Si algo falla, quita la casilla 'Efecto cristal' o ejecuta: hyprpm disable hyprglass"
