#!/usr/bin/env bash
# 040 — deploy the private island activity log with backups for copied installations.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
if ! command -v python3 >/dev/null 2>&1; then
    log_warn "Falta Python estándar (requerido por core); reintenta después de instalarlo."
    exit 10
fi
# shellcheck source=lib/activity.sh
. "$REPO_DIR/lib/activity.sh"
activity_setup
