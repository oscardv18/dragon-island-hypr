#!/usr/bin/env bash
# 018 — keep transparency and liquid glass through maximize/fullscreen/restore.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ ! -f "$config_root/hypr/hyprland.lua" ]]; then
    log_info "Hyprland de dragon-island no está instalado: se omite."
    exit 10
fi

# Deploy individual files: preserve local.lua and the installation's copy/symlink mode.
for config_file in glass.lua rules.lua; do
    source_file="$REPO_DIR/config/hypr/$config_file"
    target_file="$config_root/hypr/$config_file"
    if [[ "$(readlink -f "$source_file")" != "$(readlink -f "$target_file")" ]]; then
        deploy_item "$source_file" "$target_file"
    fi
done
if [[ -f "$config_root/kitty/kitty.conf" ]]; then
    if [[ "$(readlink -f "$REPO_DIR/config/kitty/kitty.conf")" != "$(readlink -f "$config_root/kitty/kitty.conf")" ]]; then
        deploy_item "$REPO_DIR/config/kitty/kitty.conf" "$config_root/kitty/kitty.conf"
    fi
fi
# update.sh reloads Hyprland; glass-keep-terminals removes stale dynamic disabling tags.
log_info "Cristal persistente en ventanas maximizadas, a pantalla completa y restauradas."
