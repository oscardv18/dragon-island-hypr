#!/usr/bin/env bash
# 093 — the Taller and the explorer use the glass material (ahumado): Theme.qml (panel fills = Theme.glassFill) and
# rules.lua (the explorer's blur clipped to its 22 px radius). Copied installs only; a repo link already sees both.
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
deploy_copy "$REPO_DIR/config/quickshell/Theme.qml" "$config/quickshell/Theme.qml"
deploy_copy "$REPO_DIR/config/hypr/rules.lua" "$config/hypr/rules.lua"
((changed)) || exit 10
log_info "Taller y Archivos con cristal ahumado. Reinicia Quickshell y recarga Hyprland (hyprctl reload)."
