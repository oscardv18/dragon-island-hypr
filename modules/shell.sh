#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module shell — zsh + starship + eza/fzf/zoxide/fd/bat + fzf-tab. Never replaces your ~/.zshrc:
# it adds ONE sourced line between markers.
# =============================================================================
# shellcheck disable=SC2016  # the line is written literally into ~/.zshrc
ZSH_LINE='source "${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh/dragon.zsh"'
SHELL_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

shell_desc() { echo "Terminal: zsh + starship + eza, fzf, fzf-tab, zoxide, fd, bat"; }
shell_sudo() { echo "pacman -S (paquetes); chsh solo si lo confirmas"; }
shell_packages() { pkg_list "$REPO_DIR/packages/pacman-shell.txt"; }

shell_check() { grep -qs ">>> dragon-island:zsh" "$HOME/.zshrc" || [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; }

shell_plan() {
    echo "  · paquetes: $(shell_packages | tr '\n' ' ')"
    echo "  · git clone de zsh-autosuggestions, zsh-syntax-highlighting y fzf-tab (si faltan)"
    echo "  · UNA línea en ~/.zshrc entre marcadores (tu archivo no se reemplaza; respaldo antes)"
    echo "  · ~/.config/starship.toml (respaldo si ya tienes uno)"
}

# zsh plugin clones: oh-my-zsh's custom dir when the user has oh-my-zsh, ours otherwise
shell_plugin_dir() {
    local omz="${ZSH:-$HOME/.oh-my-zsh}"
    if [[ -d "$omz/custom/plugins" ]]; then echo "${ZSH_CUSTOM:-$omz/custom}/plugins"
    else echo "${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/zsh-plugins"; fi
}

shell_apply() {
    ensure_via pacman shell_packages  || log_warn "Paquetes de la terminal pendientes."
    local dir name repo
    dir="$(shell_plugin_dir)"
    for name in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
        repo="zsh-users/$name"; [[ "$name" == fzf-tab ]] && repo="Aloxaf/fzf-tab"
        if [[ -d "$dir/$name" ]]; then log_info "Plugin $name ya está en $dir"
        else run mkdir -p "$dir"; run git clone --depth 1 "https://github.com/$repo.git" "$dir/$name"; fi
    done

    deploy_item "$REPO_DIR/config/zsh" "$SHELL_CFG/dragon-island/zsh"
    deploy_item "$REPO_DIR/config/starship/starship.toml" "$SHELL_CFG/starship.toml"

    if [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; then
        log_info "Tu ~/.zshrc ya es el del repo (instalación anterior): ya carga dragon.zsh."
    else
        marker_set "$HOME/.zshrc" zsh "#" "$ZSH_LINE"
    fi

    if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]] && command -v zsh >/dev/null 2>&1; then
        if confirm "Tu shell por defecto no es zsh. ¿Cambiarla con chsh -s /usr/bin/zsh? (pide tu contraseña)"; then
            run chsh -s /usr/bin/zsh || log_warn "chsh falló: ejecútalo a mano: chsh -s /usr/bin/zsh"
        fi
    fi
    return 0
}

shell_revert() {
    marker_unset "$HOME/.zshrc" zsh "#"
    undeploy "$SHELL_CFG/dragon-island/zsh"
    undeploy "$SHELL_CFG/starship.toml"
    log_info "shell: línea retirada de ~/.zshrc. Si cambiaste el shell: chsh -s /bin/bash (o el que tuvieras)."
}
