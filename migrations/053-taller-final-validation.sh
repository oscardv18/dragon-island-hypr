#!/usr/bin/env bash
# 053 — concurrent DB initialization, HEAD without agents and removal of stale pane previews.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/mem.sh
. "$REPO_DIR/lib/mem.sh"
# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"
mem_setup
herdr_bridge_setup
deploy_item "$REPO_DIR/config/quickshell" "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
