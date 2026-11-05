#!/usr/bin/env bash
# shellcheck disable=SC2034  # MOD_* are read by install.sh / uninstall.sh
# =============================================================================
# module core — Hyprland + Quickshell + services + base configuration (mandatory)
# Interface (all modules): <m>_desc  <m>_sudo  <m>_check  <m>_plan  <m>_apply  <m>_revert  <m>_packages
# =============================================================================
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck source=lib/palette.sh
. "$REPO_DIR/lib/palette.sh"
# shellcheck source=lib/engines.sh
. "$REPO_DIR/lib/engines.sh"
# shellcheck source=lib/activity.sh
. "$REPO_DIR/lib/activity.sh"

# shellcheck source=lib/mem.sh
. "$REPO_DIR/lib/mem.sh"

# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"

# shellcheck source=lib/taller-tools.sh
. "$REPO_DIR/lib/taller-tools.sh"

# shellcheck source=lib/files-tools.sh
. "$REPO_DIR/lib/files-tools.sh"

# shellcheck source=lib/portal-tools.sh
. "$REPO_DIR/lib/portal-tools.sh"

# shellcheck source=lib/usb-audio.sh
. "$REPO_DIR/lib/usb-audio.sh"

core_desc() { echo "Hyprland, Quickshell, servicios y configuración base (obligatorio)"; }
core_sudo() { echo "pacman -S (paquetes), systemctl enable (NetworkManager, bluetooth, power-profiles-daemon), install en /etc/modprobe.d (audio USB)"; }
core_packages() { pkg_list "$REPO_DIR/packages/pacman-core.txt" "$REPO_DIR/packages/aur-core.txt"; }

core_check() {
    [[ "$(readlink -f "$CFG/hypr")" == "$(readlink -f "$REPO_DIR/config/hypr")" || -f "$CFG/hypr/hyprland.lua" ]] \
        && [[ -e "$CFG/quickshell/shell.qml" ]] && command -v Hyprland >/dev/null 2>&1 && command -v qs >/dev/null 2>&1
}

core_plan() {
    echo "  · paquetes oficiales: $(pkg_list "$REPO_DIR/packages/pacman-core.txt" | wc -l) · AUR: $(pkg_list "$REPO_DIR/packages/aur-core.txt" | tr '\n' ' ')"
    echo "  · enlaces (con respaldo): ~/.config/{hypr,kitty,ghostty,quickshell}, ~/.local/bin/{dragon-pkg,dragon-tiling}"
    echo "  · servicios del sistema (sudo, confirmado uno a uno): NetworkManager, bluetooth, power-profiles-daemon"
    echo "  · servicios de usuario: pipewire, pipewire-pulse, wireplumber"
    echo "  · audio USB (sudo, confirmado): /etc/modprobe.d/dragon-usb-audio.conf (micrófono de audífonos Jieli 4c4a:4155)"
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
    palette_terminal_deploy kitty
    palette_terminal_deploy ghostty
    deploy_item "$REPO_DIR/config/quickshell" "$CFG/quickshell"
    # settings of the notch dashboard's apps tab: only created, never overwritten (it is the user's file)
    if [[ ! -e "$CFG/dragon-island/background-apps.json" ]]; then
        run mkdir -p "$CFG/dragon-island"
        run cp -- "$REPO_DIR/config/dragon-island/background-apps.json" "$CFG/dragon-island/background-apps.json"
    fi
    deploy_item "$REPO_DIR/bin/dragon-pkg"   "$HOME/.local/bin/dragon-pkg"
    deploy_item "$REPO_DIR/scripts/tiling.sh" "$HOME/.local/bin/dragon-tiling"    # SUPER + CTRL + T, the bar chip, `qs ipc call tiling`
    palette_setup
    engines_setup
    activity_setup
    mem_setup
    herdr_bridge_setup
    taller_tools_setup
    prompt_setup
    gate_setup
    tokens_setup
    files_tools_setup
    portal_tools_setup
    portal_enable || log_info "Dragon Portal queda sin registrar (los diálogos de archivos siguen siendo los de GTK)."
    core_gpu_env
    usb_audio_quirks_setup || log_info "Audio USB sin aplicar: el micrófono de los audífonos Jieli 4c4a:4155 no grabará."

    # the neural core has one source (shared/neural-core): re-sync both copies
    if $DRY_RUN; then "$REPO_DIR/scripts/sync-shared.sh" --check || log_warn "NeuralCore/CoreIcon desincronizados (se corrigen al instalar)."
    else "$REPO_DIR/scripts/sync-shared.sh"; fi

    # the linear installer enables the services in its own phase (DRAGON_DEFER_SERVICES=1); update.sh and old flows do it here
    [[ "${DRAGON_DEFER_SERVICES:-}" == 1 ]] || core_services

    core_quickshell_reload

    # only one notification daemon per session: the Quickshell one
    local s
    for s in mako dunst swaync; do
        pkg_installed "$s" && log_warn "$s está instalado: si arranca en Hyprland competirá con las notificaciones de Quickshell."
    done
    return 0
}

# System and user services of the base session. Idempotent: an enabled service is left alone.
core_services() {
    local s
    for s in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl is-enabled --quiet "$s" 2>/dev/null; then log_info "Servicio $s ya habilitado."
        else confirm_sudo "Habilitar el servicio $s (red / bluetooth / perfiles de energía)" systemctl enable --now "$s" || true; fi
    done
    for s in pipewire pipewire-pulse wireplumber; do
        systemctl --user is-enabled --quiet "$s" 2>/dev/null || systemctl --user is-enabled --quiet "$s.socket" 2>/dev/null \
            || run systemctl --user enable --now "$s" || log_warn "No se pudo habilitar $s (usuario)."
    done
    return 0
}

# Quickshell is started by Hyprland's autostart. The installer never starts it: outside a Hyprland session it only says so; inside one,
# a shell that is already running with the previous configuration is restarted so it loads the new one.
core_quickshell_reload() {
    if ! in_hyprland; then log_info "Quickshell no se arranca fuera de Hyprland: se inicia solo al entrar en la sesión (cierra sesión y elige Hyprland)."; return 0; fi
    # a simulation must not even ask the running shell (qs creates its runtime directory)
    if $DRY_RUN; then echo "[dry-run] si Quickshell ya corre: qs kill; qs -d"; return 0; fi
    command -v qs >/dev/null 2>&1 || return 0
    [[ -n "$(qs list 2>/dev/null)" ]] || { log_info "Quickshell no está en marcha: Hyprland lo arrancará."; return 0; }
    log_info "Quickshell ya estaba en marcha: se reinicia con la configuración nueva."
    qs kill || true
    sleep 1
    qs -d >/dev/null 2>&1 </dev/null || log_warn "Quickshell no arrancó: ejecuta «qs -d» o reinicia la sesión."
}

core_revert() {
    local t
    for t in "$CFG/hypr" "$CFG/kitty" "$CFG/ghostty" "$CFG/quickshell" "$HOME/.local/bin/dragon-pkg" "$HOME/.local/bin/dragon-tiling"; do undeploy "$t"; done
    marker_unset "$HYPR_LOCAL" gpu "--"
    log_info "core: enlaces retirados. Paquetes y servicios se dejan (ver uninstall.sh --remove-packages)."
}
