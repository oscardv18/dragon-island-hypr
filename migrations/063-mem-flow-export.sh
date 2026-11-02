#!/usr/bin/env bash
# 063 — refresh flow statistics and bounded exports without changing the DB schema.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/mem.sh
. "$REPO_DIR/lib/mem.sh"
mem_setup
