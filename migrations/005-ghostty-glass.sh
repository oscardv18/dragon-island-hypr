#!/usr/bin/env bash
# 005 — Ghostty replaces kitty as the main terminal (SUPER+Return, launcher, setup windows), with liquid
# glass (hyprglass whitelist in glass.lua), visible glass on the bar / panels, and popovers under their capsule.
# This migration installs ghostty and links config/ghostty into ~/.config/ghostty (backup of any existing one).
# The Hyprland and Quickshell changes arrive with the repo (symlinks, or update.sh's copy sync) and are
# applied by the live reload at the end of update.sh. kitty stays installed and configured.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

if ! pacman -Qq ghostty >/dev/null 2>&1; then
    if confirm "Ghostty no está instalado. ¿Instalarlo con pacman?"; then
        run sudo pacman -S --needed --noconfirm ghostty
    else
        log_info "Sin Ghostty no hay terminal por defecto: se reintentará la próxima vez."
        exit 10
    fi
fi

SRC="$REPO_DIR/config/ghostty"
DEST="$HOME/.config/ghostty"
if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]]; then
    log_info "$HOME/.config/ghostty ya apunta al repo."
else
    deploy_item "$SRC" "$DEST"
fi
add_component core
exit 0
