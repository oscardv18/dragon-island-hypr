#!/usr/bin/env bash
# 073 — deploy usershare support; privileged preparation is explicitly manual.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/files-tools.sh
. "$REPO_DIR/lib/files-tools.sh"
files_tools_setup

log_info "Samba: preparación manual en $REPO_DIR/docs/FILES-SAMBA.md. No se cambió /etc ni el cortafuegos."
