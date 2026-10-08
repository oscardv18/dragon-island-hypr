#!/usr/bin/env bash
# dragon-island · tema de fastfetch
#   ./install.sh              instala la config y el logo en ~/.config/fastfetch (con respaldo)
#   ./install.sh --zsh        además añade UNA línea (entre marcadores) a ~/.zshrc para el wrapper
#   ./install.sh --uninstall  quita lo instalado y restaura el respaldo
#   ./install.sh --preview    muestra el resultado ahora mismo (ASCII)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
DI="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/backups/fastfetch-$(date +%Y%m%d-%H%M%S)"
ZRC="${ZDOTDIR:-$HOME}/.zshrc"
BEGIN="# >>> dragon-island fastfetch >>>"
END="# <<< dragon-island fastfetch <<<"

say()  { printf '\033[35m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }

install_files() {
    command -v fastfetch >/dev/null || warn "fastfetch no está instalado: sudo pacman -S --needed fastfetch jq"
    command -v jq >/dev/null || warn "falta jq (lo usa la línea «Teclado»): sudo pacman -S --needed jq"
    mkdir -p "$CFG" "$DI"
    local f
    for f in config.jsonc dragon-logo.txt dragon-core.png; do
        if [[ -e "$CFG/$f" && ! -L "$CFG/$f" ]] && ! cmp -s "$HERE/config/$f" "$CFG/$f"; then
            mkdir -p "$STATE"; cp -a "$CFG/$f" "$STATE/$f"; say "respaldo de $f → $STATE"
        fi
        install -m 644 "$HERE/config/$f" "$CFG/$f"
    done
    install -m 644 "$HERE/zsh/fastfetch.zsh" "$DI/fastfetch.zsh"
    say "instalado en $CFG"
}

add_zsh() {
    touch "$ZRC"
    if grep -qF "$BEGIN" "$ZRC"; then say "$ZRC ya tiene el bloque (nada que hacer)"; return; fi
    [[ -e "$ZRC" ]] && { mkdir -p "$STATE"; cp -a "$ZRC" "$STATE/.zshrc"; }
    {
        printf '\n%s\n' "$BEGIN"
        printf '[[ -f "%s/fastfetch.zsh" ]] && source "%s/fastfetch.zsh"\n' "$DI" "$DI"
        printf '%s\n' "$END"
    } >> "$ZRC"
    say "añadido el bloque a $ZRC (abre una terminal nueva)"
}

uninstall() {
    local f d last=""
    for f in config.jsonc dragon-logo.txt dragon-core.png; do rm -f "$CFG/$f"; done
    rm -f "$DI/fastfetch.zsh"
    # los nombres llevan fecha: el último del glob es el respaldo más reciente
    for d in "${XDG_STATE_HOME:-$HOME/.local/state}"/dragon-island/backups/fastfetch-*; do [[ -d "$d" ]] && last="$d"; done
    if [[ -n "$last" ]]; then
        for f in config.jsonc dragon-logo.txt dragon-core.png; do [[ -e "$last/$f" ]] && cp -a "$last/$f" "$CFG/$f"; done
        say "restaurado desde $last"
    fi
    if [[ -f "$ZRC" ]] && grep -qF "$BEGIN" "$ZRC"; then
        local tmp; tmp="$(mktemp)"
        awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$ZRC" > "$tmp" && cat "$tmp" > "$ZRC"; rm -f "$tmp"
        say "bloque quitado de $ZRC"
    fi
}

case "${1:-}" in
    "")          install_files ;;
    --zsh)       install_files; add_zsh ;;
    --uninstall) uninstall ;;
    --preview)   DRAGON_FF_ASCII=1 fastfetch -c "$HERE/config/config.jsonc" --logo "$HERE/config/dragon-logo.txt" ;;
    *) echo "uso: $0 [--zsh|--uninstall|--preview]"; exit 2 ;;
esac
