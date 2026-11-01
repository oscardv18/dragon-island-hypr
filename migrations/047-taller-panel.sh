#!/usr/bin/env bash
# 047 — Taller overlay and SUPER+T; tiling moves to SUPER+CTRL+T (user decision).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
deploy_item "$REPO_DIR/config/quickshell" "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
for file in binds.lua rules.lua glass.lua; do
    target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/$file"
    [[ "$(readlink -f "$target")" == "$(readlink -f "$REPO_DIR/config/hypr/$file")" ]] || deploy_item "$REPO_DIR/config/hypr/$file" "$target"
done
