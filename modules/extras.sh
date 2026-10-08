#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module extras — optional apps, each one asked for: Brave, Proton VPN, herdr, "Mis apps" (the Tienda's lists).
# Non-interactive selection: DRAGON_EXTRAS=brave,protonvpn,herdr,myapps (install.sh --extras ...).
# herdr is not packaged: its official installer is used (no root, ~/.local/bin).
# =============================================================================
EXTRAS_ALL=(brave protonvpn herdr myapps)
EXTRAS_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

extras_desc() { echo "Brave, Proton VPN, herdr y «Mis apps» (cada uno opcional)"; }
extras_sudo() { echo "pacman -S / yay -S de lo que elijas"; }
extras_packages() { extras_pkgs brave pacman; extras_pkgs brave aur; extras_pkgs protonvpn pacman; }

extras_check() { command -v herdr >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/herdr" ]] || pkg_installed brave-bin || pkg_installed proton-vpn-gtk-app; }

extras_plan() {
    echo "  · te pregunta cuáles: brave (AUR brave-bin), protonvpn (proton-vpn-gtk-app), herdr (instalador oficial), myapps (packages/user-*.txt)"
    echo "  · herdr: config + SUPER+A + completion de zsh; Proton VPN necesita el módulo keyring"
}

extras_selected() {
    local sel="${DRAGON_EXTRAS:-}"
    if [[ -z "$sel" ]]; then
        if $ASSUME_YES || ! has_gum; then sel="brave,protonvpn,herdr"
        else sel="$(gum choose --no-limit --header "Extras (Espacio marca, Enter confirma):" "${EXTRAS_ALL[@]}" | paste -sd, -)"; fi
    fi
    tr ',' '\n' <<<"$sel"
}

extras_apply() {
    local e
    while read -r e; do
        case "$e" in
            brave)     ensure_via aur extras_pkgs brave aur || true
                       deploy_item "$REPO_DIR/config/brave/brave-flags.conf" "$EXTRAS_CFG/brave-flags.conf" ;;
            protonvpn) ensure_via pacman extras_pkgs protonvpn pacman || true
                       grep -qs pam_gnome_keyring /etc/pam.d/sddm || log_warn "Proton VPN usa el llavero: instala también el módulo keyring." ;;
            herdr)     ensure_herdr || log_warn "herdr no se instaló: SUPER + A avisará hasta que ejecutes ./update.sh"
                       deploy_herdr ;;
            myapps)    ensure_via pacman read_plain_list "$REPO_DIR/packages/user-pacman.txt" || true
                       ensure_via aur read_plain_list "$REPO_DIR/packages/user-aur.txt" || true ;;
            "") ;;
            *) log_warn "Extra desconocido: $e" ;;
        esac
    done < <(extras_selected)
    return 0
}

extras_revert() {
    undeploy "$EXTRAS_CFG/herdr/config.toml"
    undeploy "$HOME/.local/bin/dragon-herdr"
    log_info "extras: configuración retirada. herdr se desinstala con su propio comando; los paquetes se dejan."
}
