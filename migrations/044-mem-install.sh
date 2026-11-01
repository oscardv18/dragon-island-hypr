#!/usr/bin/env bash
# 044 — install project memory, backing up a pre-existing database before schema creation.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
command -v python3 >/dev/null || exit 10
# shellcheck source=lib/mem.sh
. "$REPO_DIR/lib/mem.sh"
mem_setup
