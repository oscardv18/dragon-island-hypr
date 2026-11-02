#!/usr/bin/env bash
# 075 — SUPER+E opens the explorer once its UI is deployed (080, on the UI branch).
# Window rules belong to 080, so these migrations can be integrated without overlap.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
config="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ ! -f "$config/quickshell/services/Files.qml" ]]; then
    log_info "SUPER+E pendiente hasta desplegar las pantallas (080); se reintentará."
    exit 10
fi
dest="$config/hypr/binds.lua"
# A repo link already sees the new bind. Never write through a linked directory.
[[ -d "$config/hypr" && ! -L "$config/hypr" && ! -L "$dest" ]] || exit 10
[[ -f "$dest" ]] && cmp -s "$REPO_DIR/config/hypr/binds.lua" "$dest" && exit 10
backup_copy "$dest"
run cp -a -- "$REPO_DIR/config/hypr/binds.lua" "$dest"
log_info "SUPER+E abre Archivos. Recarga Hyprland después de integrar 080 y reiniciar Quickshell."
