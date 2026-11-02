#!/usr/bin/env bash
# shellcheck disable=SC2034
# Neovim configuration only; network/plugin restoration is deferred to first use.
# shellcheck source=lib/editor.sh
. "$REPO_DIR/lib/editor.sh"

editor_desc() { echo 'Neovim personal: LazyVim, Laravel/Blade, frontend, Rust y Go'; }
editor_sudo() { echo 'pacman -S (Neovim y herramientas; plugins sin sudo en el primer uso)'; }
editor_packages() { pkg_list "$REPO_DIR/packages/pacman-editor.txt"; }
editor_check() { nvim_version_ok && [[ -f "$(nvim_config_dir)/init.lua" ]]; }
editor_plan() {
    echo "  · paquetes: $(editor_packages | tr '\n' ' ')"
    echo '  · configuración personal en ~/.config/nvim según LINK_MODE, con backup_copy de lo anterior'
    echo '  · primer uso: confirmar restauración del lockfile (180 s máximo); sin red abre sin plugins'
}
editor_apply() {
    ensure_via pacman editor_packages || log_warn 'Dependencias de Neovim pendientes.'
    nvim_deploy || return 1
    nvim_version_ok || log_warn 'Neovim >= 0.12 pendiente: instala/actualiza el paquete antes de abrir esta configuración.'
    log_info 'Neovim preparado. Abre nvim y confirma; :DragonNvimRestore permite reintentar sin reinstalar.'
}
editor_revert() { nvim_revert; }
