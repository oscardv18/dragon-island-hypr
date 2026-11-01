#!/usr/bin/env bash
# 055 — deploy Docker/Git adapters and their shared secret filter, also for copied installs.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/taller-tools.sh
. "$REPO_DIR/lib/taller-tools.sh"
taller_tools_setup
