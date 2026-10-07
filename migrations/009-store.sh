#!/usr/bin/env bash
# 009 — "Tienda" panel (SUPER + I): search / install / remove / update pacman + AUR packages.
# Installs pacman-contrib (checkupdates, paccache) if missing and links bin/dragon-pkg into ~/.local/bin (the floating
# terminal that runs the privileged actions). The panel, the Hyprland bind (SUPER+I), the window rule of the terminal
# (class org.dragonisland.Pkg) and the glass for the dragon-store layer arrive with the repo.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

if ! pacman -Qq pacman-contrib >/dev/null 2>&1; then
    if confirm "Falta pacman-contrib (checkupdates y paccache para la Tienda). ¿Instalarlo con pacman?"; then
        run sudo pacman -S --needed --noconfirm pacman-contrib || { log_warn "No se pudo instalar pacman-contrib: hazlo a mano."; exit 10; }
    else
        log_info "Se reintentará la próxima vez."
        exit 10
    fi
fi

if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
    log_warn "No hay paru ni yay: la Tienda solo podrá instalar paquetes de los repositorios oficiales."
fi

SRC="$REPO_DIR/bin/dragon-pkg"
DEST="$HOME/.local/bin/dragon-pkg"
run chmod +x "$SRC"
if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]]; then
    log_info "dragon-pkg ya está enlazado."
else
    run mkdir -p "$HOME/.local/bin"
    deploy_item "$SRC" "$DEST"
fi
run mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/dragon-island"
exit 0
