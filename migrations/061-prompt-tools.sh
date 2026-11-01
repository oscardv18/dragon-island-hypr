#!/usr/bin/env bash
# 061 — install the deterministic composer and editable Spanish templates with backups.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/taller-tools.sh
. "$REPO_DIR/lib/taller-tools.sh"
prompt_setup
