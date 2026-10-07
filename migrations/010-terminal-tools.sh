#!/usr/bin/env bash
# 010 — advanced terminal: eza, fzf, fzf-tab, zoxide, fd, bat on the existing zsh + starship.
# Installs the packages, clones the fzf-tab plugin next to the other oh-my-zsh plugins, and deploys the files that
# config/zsh/.zshrc sources (aliases, fzf, fzf-tab, history) to ~/.config/dragon-island/zsh (symlink or copy as the rest).
# The prompt (starship) is not touched. Only for people who use the zsh component: skipped otherwise.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

# only if config/zsh/.zshrc is the user's ~/.zshrc (migration 002 / the zsh component)
if [[ "$(readlink -f "$HOME/.zshrc")" != "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; then
    log_info "$HOME/.zshrc no es el del repo (componente zsh): se omite."
    exit 10
fi

missing=()
for p in eza fzf zoxide fd bat; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [[ ${#missing[@]} -gt 0 ]]; then
    if confirm "Faltan paquetes para la terminal: ${missing[*]}. ¿Instalarlos con pacman?"; then
        run sudo pacman -S --needed --noconfirm "${missing[@]}" || { log_warn "No se pudieron instalar (¿sin terminal para sudo?): sudo pacman -S --needed ${missing[*]}"; exit 10; }
    else
        log_info "Se reintentará la próxima vez."
        exit 10
    fi
fi

ensure_omz     # clones fzf-tab (and anything else missing)

DEST="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh"
SRC="$REPO_DIR/config/zsh"
run mkdir -p "$(dirname "$DEST")"
if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]]; then
    log_info "$DEST ya apunta al repo."
else
    deploy_item "$SRC" "$DEST"
fi
exit 0
