#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module plugins — hyprbars + hyprfocus (hyprland-plugins) and hyprglass, via hyprpm.
# hyprpm needs a running Hyprland and sudo (it installs headers in /var/cache/hyprpm): it runs in the FOREGROUND of a
# terminal (never in autostart or under `gum spin`). Outside Hyprland the step is deferred to the first session.
# Repeat `hyprpm update` after every Hyprland update (update.sh does it when the version changed).
# =============================================================================
PLUGINS_SCRIPT="$REPO_DIR/scripts/plugins-foreground.sh"

plugins_desc() { echo "hyprbars, hyprfocus y hyprglass (efecto cristal) con hyprpm"; }
plugins_sudo() { echo "hyprpm update (instala cabeceras en /var/cache/hyprpm; hyprpm pide la contraseña)"; }
plugins_packages() { pkg_list "$REPO_DIR/packages/pacman-plugins.txt"; }

plugins_check() {
    command -v hyprctl >/dev/null 2>&1 && in_hyprland || return 1
    local l; l="$(hyprctl plugin list 2>/dev/null)"
    grep -qi hyprbars <<<"$l" && grep -qi hyprfocus <<<"$l" && grep -qi hyprglass <<<"$l"
}

plugins_plan() {
    echo "  · paquetes de compilación: $(plugins_packages | tr '\n' ' ')"
    echo "  · scripts/plugins-foreground.sh: hyprpm update/add/enable + hyprpm reload -n && hyprctl reload"
    echo "  · dentro de Hyprland: se ejecuta ahora en primer plano (pide sudo); fuera: en tu primer inicio de sesión"
}

plugins_apply() {
    ensure_via pacman plugins_packages  || log_warn "Faltan dependencias de hyprpm: la compilación puede fallar."
    run mkdir -p "$STATE_DIR"
    run chmod +x "$PLUGINS_SCRIPT"
    deploy_item "$PLUGINS_SCRIPT" "$STATE_DIR/plugins-foreground.sh"
    $DRY_RUN || touch "$STATE_DIR/plugins.pending"
    if in_hyprland && ! $DRY_RUN; then
        if confirm "[sudo] hyprpm va a instalar cabeceras de Hyprland (pide tu contraseña). ¿Compilar los plugins ahora, en primer plano?"; then
            "$PLUGINS_SCRIPT" || log_warn "Los plugins no se instalaron: se reintentarán en el próximo inicio de sesión en Hyprland."
        fi
    elif $DRY_RUN; then
        echo "[dry-run] $PLUGINS_SCRIPT   (hyprpm update; add; enable hyprbars hyprfocus hyprglass; reload)"
    else
        log_info "Fuera de Hyprland: los plugins se instalarán en tu primer inicio de sesión (se abre una terminal)."
    fi
    return 0
}

plugins_revert() {
    if in_hyprland && command -v hyprpm >/dev/null 2>&1 && ! $DRY_RUN; then
        local p; for p in hyprbars hyprfocus hyprglass; do hyprpm disable "$p" 2>/dev/null || true; done
        hyprpm reload -n 2>/dev/null || true
    else
        log_info "Para desactivar: hyprpm disable hyprbars; hyprpm disable hyprfocus; hyprpm disable hyprglass"
    fi
    undeploy "$STATE_DIR/plugins-foreground.sh"
    run rm -f "$STATE_DIR/plugins.pending"
}
