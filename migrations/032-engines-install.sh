#!/usr/bin/env bash
# 032 — install offline launcher/usage/clipboard engines, backing up prior commands and data.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# migration-env creates state; a standalone dry-run must leave no files at all.
if [[ "${DRY_RUN:-false}" == true ]]; then
    STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island}"
    LOG="${LOG:-/dev/null}"; BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups/engines}"
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
    log_warn "Falta Python estándar (paquete python, ya requerido por core); reintenta tras instalarlo."
    exit 10
fi
# shellcheck source=lib/engines.sh
. "$REPO_DIR/lib/engines.sh"
engines_setup
