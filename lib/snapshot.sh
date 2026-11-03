#!/usr/bin/env bash
# =============================================================================
# dragon-island — pre-install snapshot and package list (sourced by install.sh, needs lib/common.sh).
#   snapshot_create   explicit package list in the installer state + snapper/timeshift snapshot when one exists
#   snapshot_recovery lines for the final report: how to go back
# Nothing runs without the usual sudo confirmation; --dry-run only says what it would do.
# =============================================================================
SNAPSHOT_KIND=""            # snapper | timeshift | "" (set by snapshot_create)
SNAPSHOT_PKGLIST=""         # path of the saved pacman -Qqe list

snapshot_tool() {
    if command -v snapper >/dev/null 2>&1 && [[ -e /etc/snapper/configs/root ]]; then echo snapper
    elif command -v timeshift >/dev/null 2>&1; then echo timeshift
    fi
}

snapshot_create() {
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    SNAPSHOT_PKGLIST="$STATE_DIR/pacman-Qqe-$ts.txt"
    if $DRY_RUN; then
        log_info "[dry-run] pacman -Qqe > $SNAPSHOT_PKGLIST"
    else
        mkdir -p "$STATE_DIR"
        if pacman -Qqe > "$SNAPSHOT_PKGLIST"; then log_info "Lista de paquetes explícitos guardada: $SNAPSHOT_PKGLIST ($(wc -l < "$SNAPSHOT_PKGLIST") paquetes)"
        else log_warn "No se pudo guardar la lista de paquetes."; SNAPSHOT_PKGLIST=""; fi
    fi
    SNAPSHOT_KIND="$(snapshot_tool)"
    case "$SNAPSHOT_KIND" in
        snapper)
            confirm_sudo "Instantánea previa con snapper (configuración root): punto de retorno antes de instalar" \
                snapper -c root create --description "dragon-island: antes de instalar" || SNAPSHOT_KIND="" ;;
        timeshift)
            confirm_sudo "Instantánea previa con Timeshift: punto de retorno antes de instalar" \
                timeshift --create --comments "dragon-island: antes de instalar" --tags O || SNAPSHOT_KIND="" ;;
        *)
            log_info "Sin snapper ni Timeshift: no hay instantánea (solo la lista de paquetes y los respaldos de configuración)." ;;
    esac
}

snapshot_recovery() {
    [[ -n "$SNAPSHOT_PKGLIST" ]] && printf '%s\n' "Paquetes de antes: sudo pacman -S --needed - < $SNAPSHOT_PKGLIST   (no quita lo nuevo; para eso, pacman -Rns)"
    case "$SNAPSHOT_KIND" in
        snapper)   printf '%s\n' "Instantánea: sudo snapper -c root list   y   sudo snapper -c root rollback <número>   (luego reinicia)" ;;
        timeshift) printf '%s\n' "Instantánea: sudo timeshift --list   y   sudo timeshift --restore" ;;
    esac
    printf '%s\n' "Configuración: ./uninstall.sh devuelve enlaces y respaldos (carpeta de respaldos: $BACKUP_DIR)"
    return 0
}
