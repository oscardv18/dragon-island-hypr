#!/usr/bin/env bash
# 019 — standalone Android Emulator: floating, without compositor decorations.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ ! -f "$config_root/hypr/hyprland.lua" ]]; then
    log_info "Hyprland de dragon-island no está instalado: se omite."
    exit 10
fi
source_file="$REPO_DIR/config/hypr/rules.lua"
target_file="$config_root/hypr/rules.lua"
if [[ "$(readlink -f "$source_file")" != "$(readlink -f "$target_file")" ]]; then
    deploy_item "$source_file" "$target_file"
fi
log_info "Reglas del emulador Android desplegadas; las ventanas existentes deben reabrirse para flotar."
