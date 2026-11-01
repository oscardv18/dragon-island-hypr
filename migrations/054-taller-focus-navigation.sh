#!/usr/bin/env bash
# 054 — dismiss shell overlays before agent navigation so the terminal receives keyboard focus.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
deploy_item "$REPO_DIR/config/quickshell" "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
