#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module shell — zsh + starship + eza/fzf/zoxide/fd/bat + zsh-autosuggestions/zsh-syntax-highlighting (packages) +
# fzf-tab (git clone). Never replaces your ~/.zshrc: it adds ONE sourced line between markers, after asking.
# The shared rules (plugin dir, Starship file, probe) live in lib/zsh-setup.sh.
# =============================================================================
SHELL_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck source=lib/palette.sh
. "$REPO_DIR/lib/palette.sh"
# shellcheck source=lib/zsh-setup.sh
. "$REPO_DIR/lib/zsh-setup.sh"

shell_desc() { echo "Terminal: zsh + starship + eza, fzf, fzf-tab, zoxide, fd, bat"; }
shell_sudo() { echo "pacman -S (paquetes); chsh solo si lo confirmas"; }
shell_packages() { pkg_list "$REPO_DIR/packages/pacman-shell.txt"; }

shell_check() { grep -qs ">>> dragon-island:zsh" "$HOME/.zshrc" || [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; }

shell_plan() {
    echo "  · paquetes: $(shell_packages | tr '\n' ' ')"
    echo "  · git clone de fzf-tab (si falta) en $(zsh_plugin_dir)"
    echo "  · UNA línea en ~/.zshrc entre marcadores, si la aceptas (tu archivo no se reemplaza; respaldo antes)"
    echo "  · ~/.config/starship.toml de Dragon (respaldo del que tengas si no es el de Dragon)"
}

# shell_ask <question>: default «Sí»; the accepted plan does not answer it. Drawn on the terminal even while the
# installer captures the module's output in its log.
shell_ask() {
    if [[ -z "${EV_ENGINE:-}" ]] && ! $ASSUME_YES && ! $DRY_RUN && have_tty; then
        confirm_explicit "$1" >/dev/tty 2>/dev/tty
    else
        confirm_explicit "$1"
    fi
}

# shell_todo <text>: something left for the user: a warning now and a line under «Queda para ti» in the summary
shell_todo() { log_warn "$1"; MANUAL_ITEMS+=("$1"); }

shell_apply() {
    local rc=0 zsh_bin
    ensure_via pacman shell_packages  || log_warn "Paquetes de la terminal pendientes."
    zsh_ensure_plugins || rc=1

    deploy_item "$REPO_DIR/config/zsh" "$SHELL_CFG/dragon-island/zsh"
    zsh_starship_deploy
    palette_setup

    if [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; then
        log_info "Tu ~/.zshrc ya es el del repo (instalación anterior): ya carga dragon.zsh."
    elif zsh_block_ok; then
        log_info "Ya está al día: zsh en $HOME/.zshrc"
    elif shell_ask "¿Añadir UNA línea a ~/.zshrc para cargar la configuración de Dragon OS? Se hace copia de seguridad antes y no se borra nada de lo tuyo."; then
        marker_set "$HOME/.zshrc" zsh "#" "$ZSH_LINE"
    else
        shell_todo "zsh: la terminal no carga Dragon hasta que añadas esta línea al final de ~/.zshrc:  $ZSH_LINE   (o repite: $REPO_DIR/install.sh --modules shell)"
    fi

    zsh_bin="$(command -v zsh 2>/dev/null || true)"
    [[ -x /usr/bin/zsh ]] && zsh_bin=/usr/bin/zsh
    if [[ -n "$zsh_bin" && "$(basename "$(getent passwd "$USER" | cut -d: -f7)")" != zsh ]]; then
        if shell_ask "Tu shell por defecto no es zsh, así que las terminales nuevas no cargarán Dragon. ¿Cambiarla a zsh con chsh -s $zsh_bin? (pide tu contraseña)"; then
            run chsh -s "$zsh_bin" || shell_todo "chsh falló (¿contraseña?). Cambia la shell a mano: chsh -s $zsh_bin"
        else
            shell_todo "Shell por defecto sin cambiar. Para usar zsh: chsh -s $zsh_bin (y vuelve a abrir la terminal)"
        fi
    fi
    return "$rc"
}

shell_revert() {
    marker_unset "$HOME/.zshrc" zsh "#"
    # legacy install: ~/.zshrc itself was a link to the repo's file (the old migration 002 backed yours up)
    [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]] && undeploy "$HOME/.zshrc"
    undeploy "$SHELL_CFG/dragon-island/zsh"
    undeploy "$SHELL_CFG/starship.toml"
    log_info "shell: línea retirada de ~/.zshrc. Si cambiaste el shell: chsh -s /bin/bash (o el que tuvieras)."
}
