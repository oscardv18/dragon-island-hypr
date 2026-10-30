#!/usr/bin/env bash
# 031 — Pillow is needed only to extract an image; apply/reset use the stdlib.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-false}"; ASSUME_YES="${ASSUME_YES:-false}"
LOG="${LOG:-/dev/null}"
# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
if command -v python3 >/dev/null 2>&1 && python3 -c 'from PIL import Image' >/dev/null 2>&1; then
    log_info "Python + Pillow ya están disponibles."
    exit 0
fi
confirm "¿Instalar python y python-pillow para extraer la paleta del fondo?" || exit 10
ensure_pacman python python-pillow || exit 10
