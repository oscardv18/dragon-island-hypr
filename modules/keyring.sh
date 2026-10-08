#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module keyring — gnome-keyring as the ONLY Secret Service (Proton VPN depends on it): portal routing, Brave flag
# and, if missing, the pam_gnome_keyring lines of the display manager (shown as a diff, confirmed, backup .bak-dragon).
# =============================================================================
KR_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
PAM_FILE="/etc/pam.d/sddm"

keyring_desc() { echo "gnome-keyring como único llavero (portal, Brave y PAM del login con copia .bak-dragon)"; }
keyring_sudo() { echo "solo si falta pam_gnome_keyring en $PAM_FILE (muestra el diff y pide confirmación)"; }
keyring_packages() { echo gnome-keyring; echo libsecret; }

keyring_check() { grep -qs pam_gnome_keyring "$PAM_FILE" && [[ -e "$KR_CFG/xdg-desktop-portal/hyprland-portals.conf" ]]; }

keyring_plan() {
    echo "  · ~/.config/xdg-desktop-portal/hyprland-portals.conf (portal de secretos → gnome-keyring) y ~/.config/brave-flags.conf"
    echo "  · $PAM_FILE: añade las 3 líneas de pam_gnome_keyring SOLO si faltan, tras mostrar el diff (copia .bak-dragon)"
    echo "  · el llavero «login» debe tener la misma contraseña que tu usuario y no usarse autologin"
}

# keyring_pam_candidate → writes the proposed PAM file to stdout (adds the three lines after the last line of each type)
keyring_pam_candidate() {
    awk '
        { lines[NR] = $0 }
        /^-?auth[[:space:]]/     { la = NR }
        /^-?password[[:space:]]/ { lp = NR }
        /^-?session[[:space:]]/  { ls = NR }
        END {
            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == la) print "-auth       optional    pam_gnome_keyring.so"
                if (i == lp) print "-password   optional    pam_gnome_keyring.so    use_authtok"
                if (i == ls) print "-session    optional    pam_gnome_keyring.so    auto_start"
            }
        }' "$PAM_FILE"
}

keyring_apply() {
    ensure_pacman gnome-keyring libsecret || true
    deploy_item "$REPO_DIR/config/xdg-desktop-portal/hyprland-portals.conf" "$KR_CFG/xdg-desktop-portal/hyprland-portals.conf"
    deploy_item "$REPO_DIR/config/brave/brave-flags.conf" "$KR_CFG/brave-flags.conf"
    run systemctl --user enable gnome-keyring-daemon.socket 2>/dev/null || true

    if [[ ! -f "$PAM_FILE" ]]; then
        log_info "No hay $PAM_FILE (¿Plasma Login Manager?): su PAM ya arranca gnome-keyring; no se toca nada."
    elif grep -q pam_gnome_keyring "$PAM_FILE"; then
        log_info "$PAM_FILE ya tiene pam_gnome_keyring."
    else
        local cand; cand="$(mktemp)"
        keyring_pam_candidate > "$cand"
        echo "── Cambio propuesto en $PAM_FILE ──"
        diff -u "$PAM_FILE" "$cand" || true
        if $DRY_RUN; then echo "[dry-run] sudo cp -n $PAM_FILE $PAM_FILE.bak-dragon && sudo install -m 644 <candidato> $PAM_FILE"
        elif $NO_SUDO; then log_warn "Sin sudo (--no-sudo): no se modifica $PAM_FILE."
        elif confirm "[sudo] ¿Aplicar este cambio a $PAM_FILE? (copia .bak-dragon antes)"; then
            sudo cp -n "$PAM_FILE" "$PAM_FILE.bak-dragon"
            sudo install -m 644 "$cand" "$PAM_FILE"
            log_info "Aplicado. Reversión: sudo cp $PAM_FILE.bak-dragon $PAM_FILE (o ./uninstall.sh --modules keyring)"
        fi
        rm -f "$cand"
    fi

    if pkg_installed kwallet; then
        local kw; kw="$(kreadconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled 2>/dev/null || true)"
        [[ "$kw" == "false" ]] || { log_warn "KWallet también ofrece el servicio de secretos y compite con gnome-keyring."
            log_warn "  kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false"; }
    fi
    return 0
}

keyring_revert() {
    undeploy "$KR_CFG/xdg-desktop-portal/hyprland-portals.conf"
    undeploy "$KR_CFG/brave-flags.conf"
    if [[ -f "$PAM_FILE.bak-dragon" ]]; then
        confirm_sudo "Restaurar $PAM_FILE desde la copia $PAM_FILE.bak-dragon" cp -f "$PAM_FILE.bak-dragon" "$PAM_FILE" || true
    fi
}
