#!/usr/bin/env bash
# dragon-core — install / test / remove the SDDM login theme.
#
#   ./install-theme.sh --test        preview the theme in a window (no sudo, changes nothing)
#   ./install-theme.sh               install + activate (asks before every sudo step)
#   ./install-theme.sh --uninstall   deactivate + remove (restores the previous config)
#
# The greeter runs as the 'sddm' user and cannot read your home, so the theme is COPIED
# to /usr/share/sddm/themes (never symlinked). Re-run after `git pull` to update it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/dragon-core"
DEST="/usr/share/sddm/themes/dragon-core"
CONF="/etc/sddm.conf.d/10-dragon-core.conf"

say()  { printf '\033[35m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
ask()  { local a; read -r -p "$1 [s/N] " a; [[ "$a" =~ ^[sSyY]$ ]]; }

display_manager() {
    local unit
    unit="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    case "$unit" in
        *sddm*) echo sddm ;;
        *plasmalogin*|*plasma-login*) echo plasmalogin ;;
        "") echo none ;;
        *) basename "$unit" .service ;;
    esac
}

greeter_bin() {
    command -v sddm-greeter-qt6 2>/dev/null || command -v sddm-greeter 2>/dev/null || true
}

do_test() {
    local bin; bin="$(greeter_bin)"
    [[ -n "$bin" ]] || { warn "sddm no está instalado: sudo pacman -S --needed sddm"; exit 1; }
    say "Vista previa (cierra la ventana para salir). La contraseña no se usa en modo prueba."
    "$bin" --test-mode --theme "$SRC"
}

check_deps() {
    local missing=()
    for p in sddm qt6-declarative qt6-svg; do pacman -Q "$p" &>/dev/null || missing+=("$p"); done
    if ((${#missing[@]})); then
        warn "Faltan paquetes: ${missing[*]}"
        ask "¿Instalarlos ahora con sudo pacman -S --needed ${missing[*]}?" || exit 1
        sudo pacman -S --needed "${missing[@]}"
    fi
}

check_keyboard() {
    local x11
    x11="$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}')"
    say "Distribución de teclado del login (X11 Layout): ${x11:-sin definir}"
    if [[ "$x11" != us* ]]; then
        warn "El login debe arrancar en 'us' (como escribes la contraseña); el tema fuerza el índice 0."
        if ask "¿Configurar el login como us,latam (sudo localectl set-x11-keymap us,latam)?"; then
            sudo localectl set-x11-keymap us,latam
        fi
    fi
}

do_install() {
    local dm; dm="$(display_manager)"
    say "Gestor de inicio activo: $dm"
    case "$dm" in
        sddm) ;;
        plasmalogin)
            local unit; unit="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
            warn "Usas Plasma Login Manager ($unit): no carga temas QML de SDDM."
            cat <<TXT
  Para usar dragon-core hay que volver a SDDM (Plasma seguirá entrando igual desde SDDM):
      sudo pacman -S --needed sddm
      sudo systemctl disable $unit
      sudo systemctl enable sddm.service
  Reversión:
      sudo systemctl disable sddm.service && sudo systemctl enable $unit
  Ejecuta esos comandos tú mismo si estás de acuerdo y vuelve a correr este script.
TXT
            exit 0 ;;
        *) warn "No reconozco el gestor '$dm'. Solo instalo en SDDM."; exit 1 ;;
    esac

    check_deps
    say "Se va a: copiar el tema a $DEST y crear $CONF ([Theme] Current=dragon-core)."
    ask "¿Continuar (pide sudo)?" || exit 0

    sudo install -d -m 755 "$DEST" "$DEST/components" "$DEST/fonts"
    sudo install -m 644 "$SRC"/*.qml "$SRC"/metadata.desktop "$SRC"/theme.conf "$SRC"/preview.png "$SRC"/LICENSE "$DEST/"
    sudo install -m 644 "$SRC"/components/*.qml "$DEST/components/"
    sudo install -m 644 "$SRC"/fonts/*.ttf "$DEST/fonts/"

    sudo install -d -m 755 /etc/sddm.conf.d
    [[ -f "$CONF" ]] && sudo cp -a "$CONF" "$CONF.bak-dragon"
    printf '[Theme]\nCurrent=dragon-core\n' | sudo tee "$CONF" >/dev/null

    # warn about other files that also set the theme (the last one read wins)
    if grep -ls '^Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null | grep -v "$CONF" ; then
        warn "Esos archivos también definen [Theme] Current=. SDDM lee /etc/sddm.conf.d en orden alfabético y /etc/sddm.conf al final: revisa que no sobrescriban dragon-core."
    fi

    check_keyboard
    say "Listo. Pruébalo sin reiniciar: $0 --test   ·   Se verá en el próximo arranque o al cerrar sesión."
}

do_uninstall() {
    ask "¿Desactivar y borrar dragon-core (pide sudo)?" || exit 0
    if [[ -f "$CONF.bak-dragon" ]]; then sudo mv -f "$CONF.bak-dragon" "$CONF"; else sudo rm -f "$CONF"; fi
    sudo rm -rf "$DEST"
    say "Eliminado. SDDM vuelve al tema anterior (Breeze por defecto)."
}

case "${1:-}" in
    --test) do_test ;;
    --uninstall) do_uninstall ;;
    ""|--install) do_install ;;
    *) echo "uso: $0 [--test|--install|--uninstall]"; exit 2 ;;
esac
