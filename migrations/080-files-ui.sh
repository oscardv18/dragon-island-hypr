#!/usr/bin/env bash
# 080 — deploy the explorer UI and window rules to copied installations.
# No session commands: restart Quickshell after integration to load new types.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
config="${XDG_CONFIG_HOME:-$HOME/.config}"
changed=0
refresh() {
    local src="$1" dest="$2" parent
    # Never write through a linked config or subdirectory (repo links are already current).
    parent="$dest"
    while [[ "$parent" != "$config" && "$parent" != / ]]; do
        [[ -L "$parent" ]] && return 0
        parent="$(dirname "$parent")"
    done
    [[ -f "$dest" ]] && cmp -s "$src" "$dest" && return 0
    backup_copy "$dest"
    run mkdir -p "$(dirname "$dest")"
    run cp -a -- "$src" "$dest"
    changed=1
}
if [[ -d "$config/quickshell" ]]; then
    for file in Theme.qml Icons.qml shell.qml services/qmldir services/Keybinds.qml \
        services/Files.qml services/FilesRequest.qml services/FileOps.qml services/Devices.qml services/Archives.qml; do
        refresh "$REPO_DIR/config/quickshell/$file" "$config/quickshell/$file"
    done
    for src in "$REPO_DIR"/config/quickshell/modules/files/*; do
        refresh "$src" "$config/quickshell/modules/files/${src##*/}"
    done
fi
if [[ -d "$config/hypr" ]]; then
    refresh "$REPO_DIR/config/hypr/rules.lua" "$config/hypr/rules.lua"
fi
if ((changed == 0)); then exit 10; fi
log_info "Explorador desplegado. Tras integrar las herramientas, reinicia Quickshell y recarga Hyprland."
