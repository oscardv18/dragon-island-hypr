#!/usr/bin/env bash
# 030 — owned palette files + one terminal include; preserve and back up user configs.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# migration-env creates state unconditionally; keep even a standalone dry-run read-only.
if [[ "${DRY_RUN:-false}" == true ]]; then
    STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island}"
    LOG="${LOG:-/dev/null}"; BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups/palette}"
    MANIFEST="${MANIFEST:-$STATE_DIR/manifest}"
    ASSUME_YES="${ASSUME_YES:-false}"; LINK_MODE="${LINK_MODE:-symlink}"
    # shellcheck source=lib/common.sh
    . "$REPO_DIR/lib/common.sh"
else
    # shellcheck source=lib/migration-env.sh
    . "$REPO_DIR/lib/migration-env.sh"
fi
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
if ! command -v python3 >/dev/null 2>&1; then
    log_warn "Falta Python: aplica 031 y repite la actualización para instalar las plantillas."
    exit 10
fi
# shellcheck source=lib/palette.sh
. "$REPO_DIR/lib/palette.sh"
palette_setup
