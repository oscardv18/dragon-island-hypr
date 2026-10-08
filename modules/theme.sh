#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module theme — fonts (Outfit, JetBrains Mono Nerd), icons (Candy + Sweet Folders = Sweet-Purple), Qt/GTK theming,
# example wallpapers. Qt/GTK variables are only set through hl.env (config/hypr/env.lua), never system-wide.
# =============================================================================
THEME_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

theme_desc() { echo "Fuentes, iconos Candy + Sweet Folders, tema Qt/GTK, fondos de ejemplo"; }
theme_sudo() { echo "pacman -S (paquetes)"; }
theme_packages() { pkg_list "$REPO_DIR/packages/pacman-theme.txt" "$REPO_DIR/packages/aur-theme.txt"; }

theme_check() {
    fc-list 2>/dev/null | grep -qi "outfit" && [[ -d /usr/share/icons/Sweet-Purple ]] && [[ -e "$THEME_CFG/gtk-3.0/settings.ini" ]]
}

theme_plan() {
    echo "  · paquetes: $(theme_packages | tr '\n' ' ')"
    echo "  · ~/.config/gtk-3.0 y gtk-4.0 settings.ini (respaldo si existían) y el tema de iconos en dconf"
    echo "  · ~/Pictures/Wallpapers: copia los fondos del repo (nunca reemplaza archivos existentes)"
}

theme_apply() {
    ensure_via pacman pkg_list "$REPO_DIR/packages/pacman-theme.txt" || log_warn "Paquetes de tema pendientes."
    ensure_via aur pkg_list "$REPO_DIR/packages/aur-theme.txt" || log_warn "Paquetes AUR de tema pendientes (fuentes / iconos)."
    deploy_item "$REPO_DIR/config/gtk-3.0/settings.ini" "$THEME_CFG/gtk-3.0/settings.ini"
    deploy_item "$REPO_DIR/config/gtk-4.0/settings.ini" "$THEME_CFG/gtk-4.0/settings.ini"
    apply_icon_theme

    local wp dir="$HOME/Pictures/Wallpapers"
    run mkdir -p "$dir"
    for wp in "$REPO_DIR"/assets/wallpapers/*; do
        [[ -e "$dir/$(basename "$wp")" ]] || run cp -n -- "$wp" "$dir/"
    done

    if ! $DRY_RUN && command -v fc-list >/dev/null 2>&1; then
        fc-list | grep -qi "Outfit" || log_warn "Fuente Outfit no encontrada (AUR ttf-outfit)."
        fc-list | grep -qiE "JetBrainsMono Nerd|JetBrains Mono Nerd" || log_warn "JetBrains Mono Nerd Font no encontrada."
        [[ -d /usr/share/icons/Sweet-Purple ]] || log_warn "Falta el tema de iconos Sweet-Purple (candy-icons-git + sweet-folders-icons-git)."
    fi
    return 0
}

theme_revert() {
    undeploy "$THEME_CFG/gtk-3.0/settings.ini"
    undeploy "$THEME_CFG/gtk-4.0/settings.ini"
    log_info "theme: ajustes GTK retirados. Fuentes, iconos y fondos se dejan."
}
