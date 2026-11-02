#!/usr/bin/env bash
# 076 — dragon-files after the 5d audit (papelera, carreras, borrado protegido, Samba, miniaturas): redeploy the
# engines for copied installs. Symlinked installs already see them; deploy_item backs up what it replaces.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/files-tools.sh
. "$REPO_DIR/lib/files-tools.sh"
files_tools_setup
log_info "dragon-files actualizado con las correcciones de la auditoría 5d."
