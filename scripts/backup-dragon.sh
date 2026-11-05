#!/usr/bin/env bash
# =============================================================================
# dragon-island — backup of what only lives on this machine (read-only on your files; writes only the destination).
#   scripts/backup-dragon.sh [--dest DIR] [--no-keyrings] [--dry-run]
# Copies:   dragon.db (SQLite .backup, never cp: a live database in WAL mode would come out inconsistent),
#           ~/.config/dragon-island (includes settings.json), gnome-keyring files (~/.local/share/keyrings).
# Lists (does NOT copy) what is sensitive and yours to back up: ssh, gpg, browser profiles, Docker volumes,
#           git branches that were never pushed.
# The destination is created with mode 700 and holds secrets (encrypted keyrings): keep it off shared disks.
# Pair: scripts/restore-dragon.sh. Never prints the content of any secret.
# =============================================================================
set -Eeuo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DB="$DATA/dragon-island/dragon.db"
KEYRINGS="$DATA/keyrings"
DEST=""
WITH_KEYRINGS=true
DRY_RUN=false

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)         DEST="${2:?--dest necesita una carpeta}"; shift ;;
        --dest=*)       DEST="${1#*=}" ;;
        --no-keyrings)  WITH_KEYRINGS=false ;;
        --dry-run)      DRY_RUN=true ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
[[ -n "$DEST" ]] || DEST="$HOME/dragon-backup-$(date +%Y%m%d-%H%M%S)"

say() { printf '%s\n' "$*"; }
do_() {   # do_ <command>...  (prints instead of running in --dry-run)
    if $DRY_RUN; then printf '[dry-run]'; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}

# sqlite_backup <source> <destination>: consistent copy of a live database (sqlite3 .backup, python3 as fallback)
sqlite_backup() {
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$1" ".backup '$2'"
    else
        python3 -I -c 'import sqlite3, sys
src = sqlite3.connect("file:%s?mode=ro" % sys.argv[1], uri=True); dst = sqlite3.connect(sys.argv[2])
with dst: src.backup(dst)
dst.close(); src.close()' "$1" "$2"
    fi
}

say "== Respaldo de dragon-island =="
say "Destino: $DEST $($DRY_RUN && echo '(dry-run: no se escribe nada)')"

if [[ -e "$DEST" ]] && [[ -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
    echo "El destino ya existe y no está vacío: $DEST (elige otro con --dest)." >&2; exit 1
fi
(umask 077; do_ mkdir -p "$DEST")

copied=()
if [[ -f "$DB" ]]; then
    do_ sqlite_backup "$DB" "$DEST/dragon.db"
    say "  ✔ dragon.db (copia consistente de SQLite)"; copied+=("dragon.db")
else say "  - dragon.db: no existe en $DB"; fi

if [[ -d "$CONFIG/dragon-island" ]]; then
    do_ cp -a -- "$CONFIG/dragon-island" "$DEST/config-dragon-island"
    say "  ✔ ~/.config/dragon-island$([[ -f "$CONFIG/dragon-island/settings.json" ]] && echo ' (incluye settings.json)')"; copied+=("config-dragon-island")
else say "  - ~/.config/dragon-island: no existe"; fi

if $WITH_KEYRINGS && [[ -d "$KEYRINGS" ]]; then
    do_ cp -a -- "$KEYRINGS" "$DEST/keyrings"
    say "  ✔ llaveros de gnome-keyring ($(find "$KEYRINGS" -maxdepth 1 -type f | wc -l) archivos; siguen cifrados, no se muestran)"; copied+=("keyrings")
elif $WITH_KEYRINGS; then say "  - llaveros: no hay $KEYRINGS"
else say "  - llaveros: omitidos (--no-keyrings)"; fi

# manifest with hashes (names and SHA-256 only) so restore can verify the copy
if ! $DRY_RUN; then
    manifest="$(mktemp)"
    ( cd "$DEST" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum ) > "$manifest"
    mv -- "$manifest" "$DEST/MANIFEST.sha256"
    chmod -R go-rwx "$DEST"
    say "  ✔ MANIFEST.sha256 (huellas para verificar al restaurar)"
fi

# --- what is sensitive and yours: listed, NEVER copied ---------------------------------------------
say ""
say "== Lo sensible que debes respaldar TÚ (no se copia, solo se lista) =="
list_path() {   # list_path <label> <path>
    if [[ -e "$2" ]]; then
        local n; n="$(find "$2" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)"
        say "  • $1: $2 ($n elementos)"
    fi
}
list_path "claves SSH" "$HOME/.ssh"
list_path "claves GPG" "${GNUPGHOME:-$HOME/.gnupg}"
for p in "$HOME/.mozilla" "$HOME/.librewolf" "$HOME/.zen" "$CONFIG/BraveSoftware" "$CONFIG/google-chrome" "$CONFIG/chromium" "$CONFIG/vivaldi" "$CONFIG/microsoft-edge"; do
    list_path "perfil de navegador" "$p"
done
if command -v docker >/dev/null 2>&1; then
    vols="$(docker volume ls -q 2>/dev/null || true)"
    if [[ -n "$vols" ]]; then say "  • volúmenes de Docker ($(wc -l <<<"$vols")): $(tr '\n' ' ' <<<"$vols" | cut -c1-200)"
        say "      (cópialos con: docker run --rm -v <volumen>:/v -v \$PWD:/b alpine tar czf /b/<volumen>.tgz -C /v .)"; fi
fi
unpushed=0
for root in ${DRAGON_REPOS:-$HOME/Devs $HOME/Projects $HOME/src}; do
    [[ -d "$root" ]] || continue
    while IFS= read -r gitdir; do
        repo="$(dirname "$gitdir")"
        while IFS= read -r line; do
            branch="${line%% *}"; upstream="${line#* }"
            if [[ "$upstream" == "$branch" || -z "$upstream" ]]; then
                say "  • rama sin subir: $repo → $branch (sin remoto)"; unpushed=$((unpushed + 1))
            elif [[ -n "$(git -C "$repo" log --oneline "$upstream..$branch" 2>/dev/null | head -1)" ]]; then
                say "  • commits sin subir: $repo → $branch (por delante de $upstream)"; unpushed=$((unpushed + 1))
            fi
        done < <(git -C "$repo" for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads 2>/dev/null)
    done < <(find "$root" -maxdepth 3 -name .git -type d 2>/dev/null)
done
(( unpushed > 0 )) || say "  • ramas de git: nada sin subir en ${DRAGON_REPOS:-~/Devs ~/Projects ~/src}"
say "  • también: contraseñas fuera del llavero, ~/Documents y lo que no esté en git."
say ""
if $DRY_RUN; then say "Dry-run terminado: no se escribió nada."; else say "Respaldo listo en $DEST (permisos 700). Restaurar: scripts/restore-dragon.sh $DEST"; fi
