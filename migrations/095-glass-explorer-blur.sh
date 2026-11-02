#!/usr/bin/env bash
# 095 — the explorer's blur is clipped to its 22 px radius (rules.lua, set_prop rounding). The panel fills themselves (Theme.qml) are
# main's migration 094. Copied installs only; a repo link already sees it.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
config="${XDG_CONFIG_HOME:-$HOME/.config}"
changed=0
deploy_copy() {   # <repo file> <installed file>: never through a link; back up what it replaces
    local src="$1" dest="$2"
    [[ -f "$dest" && ! -L "$dest" && ! -L "$(dirname -- "$dest")" ]] || return 0
    cmp -s -- "$src" "$dest" && return 0
    backup_copy "$dest"
    run cp -a -- "$src" "$dest"
    changed=1
}
deploy_copy "$REPO_DIR/config/hypr/rules.lua" "$config/hypr/rules.lua"
((changed)) || exit 10
log_info "Blur del explorador recortado a su radio. Recarga Hyprland (hyprctl reload)."
