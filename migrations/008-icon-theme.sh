#!/usr/bin/env bash
# 008 — icons: Candy + Sweet Folders (theme "Sweet-Purple") independent of KDE's preferences.
#   Qt:        hyprqt6engine (QT_QPA_PLATFORMTHEME in env.lua, only the Hyprland session) + hyprqt6engine.conf
#   GTK:       ~/.config/gtk-3.0 and gtk-4.0 settings.ini linked to the repo + dconf icon-theme
#   Quickshell: //@ pragma IconTheme in shell.qml
# The Hyprland / Quickshell files arrive with the repo; this installs the packages and sets the GTK side.
# Qt apps that are already open keep the old theme until they are restarted.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

# ---- packages ----
aur_missing=()
for p in hyprqt6engine candy-icons-git sweet-folders-icons-git; do
    pacman -Qq "$p" >/dev/null 2>&1 || aur_missing+=("$p")
done
if [[ ${#aur_missing[@]} -gt 0 ]]; then
    helper=""
    for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }; done
    if [[ -z "$helper" ]]; then
        log_warn "Faltan paquetes de AUR (${aur_missing[*]}) y no hay yay/paru: instálalos a mano."
        exit 10
    fi
    if confirm "Faltan paquetes de AUR para los iconos: ${aur_missing[*]}. ¿Instalarlos con $helper?"; then
        run "$helper" -S --needed --noconfirm "${aur_missing[@]}"
    else
        log_info "Sin los paquetes no se aplica el tema: se reintentará la próxima vez."
        exit 10
    fi
fi
pacman -Qq nwg-look >/dev/null 2>&1 || log_info "Opcional: sudo pacman -S nwg-look (ajustes GTK manuales)."

# ---- GTK settings.ini (backup of the existing ones, linked to the repo) ----
for v in 3.0 4.0; do
    src="$REPO_DIR/config/gtk-$v/settings.ini"
    dest="$HOME/.config/gtk-$v/settings.ini"
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "gtk-$v/settings.ini ya apunta al repo."
    else
        deploy_item "$src" "$dest"
    fi
done
apply_icon_theme

need_relogin "Tema de iconos Qt (hyprqt6engine): reinicia Dolphin y demás apps Qt abiertas, o cierra sesión"
exit 0
