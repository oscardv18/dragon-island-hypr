#!/usr/bin/env bash
# 006 — dynamic islands: contextual capsules (privacy, recording, VPN, headset battery, caffeine, DND, updates,
# network speed), workspace icons + hover preview, window actions on hover, submap indicator.
# Needs `checkupdates` (pacman-contrib) for the updates counter; everything else is in the repo (symlink, or
# update.sh's copy sync) and applied by the live reload at the end of update.sh. New keybind (SUPER+SHIFT+R,
# record the screen) and layer rules (dragon-preview) arrive with config/hypr.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

if ! pacman -Qq pacman-contrib >/dev/null 2>&1; then
    if confirm "Falta pacman-contrib (checkupdates, contador de actualizaciones). ¿Instalarlo con pacman?"; then
        run sudo pacman -S --needed --noconfirm pacman-contrib
    else
        log_info "Sin pacman-contrib no hay contador de actualizaciones; el resto funciona. Se reintentará la próxima vez."
        exit 10
    fi
fi
exit 0
