#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module login — dragon-core SDDM theme (opt-in). Only with SDDM. With Plasma Login Manager nothing is changed:
# the commands to switch to SDDM are printed. Reversion: sddm/install-theme.sh --uninstall.
# =============================================================================
login_desc() { echo "Tema de login dragon-core para SDDM (opcional; no toca Plasma Login Manager)"; }
login_sudo() { echo "systemctl enable sddm (si no hay gestor de acceso) y sddm/install-theme.sh (copia a /usr/share/sddm, /etc/sddm.conf.d)"; }
login_packages() { pkg_list "$REPO_DIR/packages/pacman-login.txt"; }

login_check() { [[ -f /etc/sddm.conf.d/10-dragon-core.conf ]] && grep -q "dragon-core" /etc/sddm.conf.d/10-dragon-core.conf; }

login_plan() {
    echo "  · paquetes: $(login_packages | tr '\n' ' ')"
    echo "  · sddm/install-theme.sh en primer plano (copia el tema; respaldo .bak-dragon de lo que reemplaza)"
    echo "  · Plasma Login Manager: no cambia nada, solo imprime cómo pasar a SDDM"
}

login_apply() {
    case "$(display_manager)" in
        sddm) ;;
        plasmalogin)
            box "#f9ae58" "Plasma Login Manager detectado: el tema de login solo funciona con SDDM" \
                "Para pasar a SDDM (no se ejecuta por ti):" \
                "  sudo systemctl disable plasmalogin" \
                "  sudo systemctl enable sddm" \
                "  (reinicia después)" \
                "Para volver:" \
                "  sudo systemctl disable sddm && sudo systemctl enable plasmalogin" \
                "Luego repite: ./install.sh --modules login"
            return 0 ;;
        none) ;;   # bare install: SDDM is installed and enabled below
        *) log_warn "Hay otro gestor de acceso ($(display_manager)): se omite el tema de login (Paso 6 de $PRE_DOC)."; return 0 ;;
    esac
    ensure_via pacman login_packages  || log_warn "Faltan paquetes del tema (sddm / qt6)."
    if [[ "$(display_manager)" == none ]]; then
        confirm_sudo "Habilitar SDDM como gestor de acceso (no había ninguno activo)" systemctl enable sddm.service \
            || { log_warn "SDDM no quedó habilitado: sudo systemctl enable sddm"; MANUAL_ITEMS+=("Gestor de acceso: sudo systemctl enable sddm"); return 0; }
    fi
    if $DRY_RUN; then echo "[dry-run] $REPO_DIR/sddm/install-theme.sh"; return 0; fi
    $NO_SUDO && { log_warn "Sin sudo (--no-sudo): ejecuta luego $REPO_DIR/sddm/install-theme.sh"; return 0; }
    if confirm "[sudo] Instalar el tema de login dragon-core (el script pregunta antes de cada paso con sudo)"; then
        DRAGON_ASSUME_YES="$($PLAN_CONFIRMED && echo 1 || echo 0)" "$REPO_DIR/sddm/install-theme.sh" || log_warn "install-theme.sh no terminó; reintenta: $REPO_DIR/sddm/install-theme.sh"
    else
        log_info "Omitido. Cuando quieras: $REPO_DIR/sddm/install-theme.sh   (probar sin sudo: --test)"
    fi
    return 0
}

login_revert() {
    if $DRY_RUN; then echo "[dry-run] $REPO_DIR/sddm/install-theme.sh --uninstall"; return 0; fi
    "$REPO_DIR/sddm/install-theme.sh" --uninstall || log_warn "No se pudo quitar el tema: $REPO_DIR/sddm/install-theme.sh --uninstall"
}
