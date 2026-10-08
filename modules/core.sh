#!/usr/bin/env bash
# shellcheck disable=SC2034  # MOD_* are read by install.sh / uninstall.sh
# =============================================================================
# module core — Hyprland + Quickshell + services + base configuration (mandatory)
# Interface (all modules): <m>_desc  <m>_sudo  <m>_check  <m>_plan  <m>_apply  <m>_revert  <m>_packages
# =============================================================================
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

core_desc() { echo "Hyprland, Quickshell, servicios y configuración base (obligatorio)"; }
core_sudo() { echo "pacman -S (paquetes), systemctl enable (NetworkManager, bluetooth, power-profiles-daemon)"; }
core_packages() { pkg_list "$REPO_DIR/packages/pacman-core.txt" "$REPO_DIR/packages/aur-core.txt"; }

core_check() {
    [[ "$(readlink -f "$CFG/hypr")" == "$(readlink -f "$REPO_DIR/config/hypr")" || -f "$CFG/hypr/hyprland.lua" ]] \
        && [[ -e "$CFG/quickshell/shell.qml" ]] && command -v Hyprland >/dev/null 2>&1 && command -v qs >/dev/null 2>&1
}

core_plan() {
    echo "  · paquetes oficiales: $(pkg_list "$REPO_DIR/packages/pacman-core.txt" | wc -l) · AUR: $(pkg_list "$REPO_DIR/packages/aur-core.txt" | tr '\n' ' ')"
    echo "  · enlaces (con respaldo): ~/.config/{hypr,kitty,ghostty,quickshell}, ~/.local/bin/dragon-pkg"
    echo "  · servicios del sistema (sudo, confirmado uno a uno): NetworkManager, bluetooth, power-profiles-daemon"
    echo "  · servicios de usuario: pipewire, pipewire-pulse, wireplumber"
    echo "  · GPU: solo escribe variables en ~/.config/hypr/local.lua si es NVIDIA (no instala drivers)"
}

# GPU environment goes ONLY to local.lua, between markers (NVIDIA: Hyprland wiki variables; AMD/Intel: none)
core_gpu_env() {
    detect_gpu
    if [[ "$GPU_VENDOR" == "nvidia" ]]; then
        marker_set "$HYPR_LOCAL" gpu "--" 'hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")'
    else
        log_info "GPU $GPU_VENDOR: no hacen falta variables de entorno."
        marker_unset "$HYPR_LOCAL" gpu "--"
    fi
}

core_apply() {
    ensure_via pacman pkg_list "$REPO_DIR/packages/pacman-core.txt" || log_warn "Paquetes oficiales pendientes: el resto continúa."
    ensure_via aur pkg_list "$REPO_DIR/packages/aur-core.txt" || log_warn "Paquetes AUR pendientes."

    deploy_item "$REPO_DIR/config/hypr"      "$CFG/hypr"
    deploy_item "$REPO_DIR/config/kitty"     "$CFG/kitty"
    deploy_item "$REPO_DIR/config/ghostty"   "$CFG/ghostty"
    deploy_item "$REPO_DIR/config/quickshell" "$CFG/quickshell"
    # settings of the notch dashboard's apps tab: only created, never overwritten (it is the user's file)
    if [[ ! -e "$CFG/dragon-island/background-apps.json" ]]; then
        run mkdir -p "$CFG/dragon-island"
        run cp -- "$REPO_DIR/config/dragon-island/background-apps.json" "$CFG/dragon-island/background-apps.json"
    fi
    deploy_item "$REPO_DIR/bin/dragon-pkg"   "$HOME/.local/bin/dragon-pkg"
    core_gpu_env

    # the neural core has one source (shared/neural-core): re-sync both copies
    if $DRY_RUN; then "$REPO_DIR/scripts/sync-shared.sh" --check || log_warn "NeuralCore/CoreIcon desincronizados (se corrigen al instalar)."
    else "$REPO_DIR/scripts/sync-shared.sh"; fi

    local s
    for s in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl is-enabled --quiet "$s" 2>/dev/null; then log_info "Servicio $s ya habilitado."
        else confirm_sudo "Habilitar el servicio $s (red / bluetooth / perfiles de energía)" systemctl enable --now "$s" || true; fi
    done
    for s in pipewire pipewire-pulse wireplumber; do
        systemctl --user is-enabled --quiet "$s" 2>/dev/null || systemctl --user is-enabled --quiet "$s.socket" 2>/dev/null \
            || run systemctl --user enable --now "$s" || log_warn "No se pudo habilitar $s (usuario)."
    done

    # only one notification daemon per session: the Quickshell one
    for s in mako dunst swaync; do
        pkg_installed "$s" && log_warn "$s está instalado: si arranca en Hyprland competirá con las notificaciones de Quickshell."
    done
    return 0
}

core_revert() {
    local t
    for t in "$CFG/hypr" "$CFG/kitty" "$CFG/ghostty" "$CFG/quickshell" "$HOME/.local/bin/dragon-pkg"; do undeploy "$t"; done
    marker_unset "$HYPR_LOCAL" gpu "--"
    log_info "core: enlaces retirados. Paquetes y servicios se dejan (ver uninstall.sh --remove-packages)."
}
