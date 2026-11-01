#!/usr/bin/env bash
# 045 — event-driven herdr bridge, retaining the no-argument session launcher.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"
herdr_bridge_setup
