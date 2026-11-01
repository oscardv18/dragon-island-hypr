#!/usr/bin/env bash
# 062 — install bounded test gates so copied systems can run user project checks.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/taller-tools.sh
. "$REPO_DIR/lib/taller-tools.sh"
gate_setup
