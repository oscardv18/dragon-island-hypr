#!/usr/bin/env bash
# 052 — runtime fixes: terminal focus, structural IDs and closed SQLite backup handles.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/mem.sh
. "$REPO_DIR/lib/mem.sh"
mem_setup
# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"
herdr_bridge_setup
