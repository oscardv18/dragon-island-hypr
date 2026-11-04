#!/usr/bin/env bash
# 190 — versión fijada de Hyprland (packages/pins.json): el primer arranque de plugins la valida antes de compilar y doctor la comprueba.
# Si el módulo plugins ya está instalado, actualiza sus copias (script de primer arranque + pins.sh + pins.json). En modo enlace
# (por defecto) el script ya apunta al repo, pero pins.sh/pins.json son nuevos junto a él. Idempotente; deploy_item hace el respaldo.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
[[ -e "$STATE_DIR/plugins-foreground.sh" || -L "$STATE_DIR/plugins-foreground.sh" ]] || exit 10     # el módulo plugins nunca se aplicó aquí
deploy_item "$REPO_DIR/scripts/plugins-foreground.sh" "$STATE_DIR/plugins-foreground.sh"
deploy_item "$REPO_DIR/lib/pins.sh" "$STATE_DIR/pins.sh"
deploy_item "$REPO_DIR/packages/pins.json" "$STATE_DIR/pins.json"
log_info "Plugins: versión de Hyprland fijada ($(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hyprland"])' "$REPO_DIR/packages/pins.json"))."
