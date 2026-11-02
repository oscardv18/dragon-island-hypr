#!/usr/bin/env bash
# 100 — Dragon Portal: deploy `dragon-portal` and its two engine files (also for copied installs). Does NOT register the backend (102 does).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/portal-tools.sh
. "$REPO_DIR/lib/portal-tools.sh"
portal_tools_setup
log_info "dragon-portal instalado. Falta registrarlo (migración 102) y reiniciar xdg-desktop-portal."
