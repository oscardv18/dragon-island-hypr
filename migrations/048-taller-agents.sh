#!/usr/bin/env bash
# 048 — deploy the Taller agent queue and memory-only pane preview.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
deploy_item "$REPO_DIR/config/quickshell" "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"
herdr_bridge_setup
