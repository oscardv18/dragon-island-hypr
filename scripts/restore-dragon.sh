#!/usr/bin/env bash
# =============================================================================
# dragon-island — restore a backup made by scripts/backup-dragon.sh.
#   scripts/restore-dragon.sh <backup-dir> [--with-keyrings] [--yes] [--dry-run]
# Verifies MANIFEST.sha256 first. Restores dragon.db (through SQLite, not cp) and ~/.config/dragon-island.
# Anything it would replace is first moved aside as <name>.pre-restore-<date>; nothing is deleted.
# The gnome-keyring files are restored ONLY with --with-keyrings (they replace your login keyring)
# and never while gnome-keyring-daemon is running.
# =============================================================================
set -Eeuo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
SRC=""
WITH_KEYRINGS=false
ASSUME_YES=false
DRY_RUN=false
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-keyrings) WITH_KEYRINGS=true ;;
        --yes|-y)        ASSUME_YES=true ;;
        --dry-run)       DRY_RUN=true ;;
        -h|--help)       usage; exit 0 ;;
        -*)              echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
        *)               if [[ -z "$SRC" ]]; then SRC="$1"; else echo "Sobra un argumento: $1" >&2; exit 2; fi ;;
    esac
    shift
done
[[ -n "$SRC" && -d "$SRC" ]] || { echo "Indica la carpeta del respaldo." >&2; usage >&2; exit 2; }

say() { printf '%s\n' "$*"; }
do_() { if $DRY_RUN; then printf '[dry-run]'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }
ask() {   # ask <question>: --yes answers yes; otherwise a real question on the terminal
    $ASSUME_YES && return 0
    [[ -t 0 ]] || { say "  (sin terminal: usa --yes para confirmar)"; return 1; }
    local a; read -r -p "$1 [s/N] " a; [[ "${a,,}" == s* || "${a,,}" == y* ]]
}
aside() {   # aside <path>: move an existing path out of the way, keeping it
    [[ -e "$1" || -L "$1" ]] || return 0
    do_ mv -- "$1" "$1.pre-restore-$STAMP"
    say "  ↪ lo anterior queda en $1.pre-restore-$STAMP"
}

sqlite_copy() {   # sqlite_copy <source> <destination>
    if command -v sqlite3 >/dev/null 2>&1; then sqlite3 "$1" ".backup '$2'"
    else
        python3 -I -c 'import sqlite3, sys
src = sqlite3.connect("file:%s?mode=ro" % sys.argv[1], uri=True); dst = sqlite3.connect(sys.argv[2])
with dst: src.backup(dst)
dst.close(); src.close()' "$1" "$2"
    fi
}

say "== Restaurar dragon-island desde $SRC =="
if [[ -f "$SRC/MANIFEST.sha256" ]]; then
    if (cd "$SRC" && sha256sum --quiet -c MANIFEST.sha256); then say "  ✔ huellas del respaldo correctas"
    else echo "  ✘ el respaldo no coincide con MANIFEST.sha256: no se restaura nada." >&2; exit 1; fi
else say "  ! sin MANIFEST.sha256: no se puede verificar el respaldo"; ask "¿Continuar sin verificar?" || exit 1; fi

if [[ -f "$SRC/dragon.db" ]]; then
    target="$DATA/dragon-island/dragon.db"
    if [[ -e "$target" ]]; then
        pgrep -f 'dragon-(mem|files)' >/dev/null 2>&1 && say "  ! hay herramientas de dragon-island en marcha; ciérralas antes si ves errores de base de datos"
        ask "¿Reemplazar $target? (lo actual se conserva aparte)" || { say "  - dragon.db: omitido"; target=""; }
    fi
    if [[ -n "$target" ]]; then
        do_ mkdir -p "$(dirname "$target")"
        if ! $DRY_RUN && [[ -e "$target" ]]; then
            # keep the current database consistently (sqlite .backup), then drop it and its WAL files
            sqlite_copy "$target" "$target.pre-restore-$STAMP" && say "  ↪ lo anterior queda en $target.pre-restore-$STAMP"
            rm -f -- "$target" "$target-wal" "$target-shm"
        fi
        do_ sqlite_copy "$SRC/dragon.db" "$target"
        $DRY_RUN || chmod 600 "$target"
        say "  ✔ dragon.db restaurada"
    fi
fi

if [[ -d "$SRC/config-dragon-island" ]]; then
    target="$CONFIG/dragon-island"
    if [[ -e "$target" ]]; then ask "¿Reemplazar $target? (lo actual se conserva aparte)" && aside "$target" || target=""; fi
    if [[ -n "$target" ]]; then do_ mkdir -p "$CONFIG"; do_ cp -a -- "$SRC/config-dragon-island" "$target"; say "  ✔ ~/.config/dragon-island restaurada"; fi
fi

if [[ -d "$SRC/keyrings" ]]; then
    if ! $WITH_KEYRINGS; then
        say "  - llaveros: el respaldo los tiene, pero NO se restauran sin --with-keyrings (sustituyen tu llavero de inicio de sesión)"
    elif pgrep -x gnome-keyring-d >/dev/null 2>&1 && ! $DRY_RUN; then
        echo "  ✘ gnome-keyring-daemon está en marcha: cierra la sesión gráfica, restaura desde una TTY y vuelve a entrar." >&2; exit 1
    else
        target="$DATA/keyrings"
        if ask "¿Reemplazar los llaveros de $target?"; then
            aside "$target"; do_ cp -a -- "$SRC/keyrings" "$target"; say "  ✔ llaveros restaurados (cierra sesión y entra de nuevo)"
        fi
    fi
fi
say ""
if $DRY_RUN; then say "Dry-run terminado: no se escribió nada."; else say "Listo. Lo anterior quedó junto a cada ruta con el sufijo .pre-restore-$STAMP."; fi
