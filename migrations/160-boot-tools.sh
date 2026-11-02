#!/usr/bin/env bash
# 160 — dragon-boot (tema de arranque): despliega la CLI y su motor en el usuario (también en instalaciones por copia).
# No toca /boot ni /etc: eso lo hace el módulo opt-in `boot` con sudo y confirmación (docs/BOOT.md).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines"
deploy_item "$REPO_DIR/dragon-core/dragon_boot.py" "$data/dragon_boot.py"
deploy_item "$REPO_DIR/bin/dragon-boot" "$HOME/.local/bin/dragon-boot"
log_info "dragon-boot instalado. Vista previa sin tocar nada: dragon-boot preview --out /tmp/arranque.png · aplicar: ./install.sh --modules boot"
