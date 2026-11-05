#!/usr/bin/env bash
# 192 — Starship en dos líneas (config/starship/starship.toml): arriba identidad, ruta completa (resumida solo si pasa
# de 5 carpetas), git con conteos, lenguajes con su logo y, a la derecha, duración, estado y hora; abajo solo ❯❯.
# ~/.config/starship.toml es una copia desligada (dragon-palette reescribe su bloque de colores), así que el cambio
# no le llega solo: si es el de Dragon, todo lo que está fuera del bloque de dragon-palette pasa a ser el del repo y
# el bloque se conserva (el acento del fondo actual). Un starship.toml que no es el de Dragon no se toca.
# La línea en blanco entre comandos pasa a zsh (config/zsh/dragon.zsh): llega con el enlace o con la sincronización.
# Idempotente; copia de seguridad con backup_copy antes de escribir. Respeta DRY_RUN.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/zsh-setup.sh
. "$REPO_DIR/lib/zsh-setup.sh"

src="$REPO_DIR/config/starship/starship.toml"
dest="$(starship_config_path)"
# sin starship.toml: el módulo shell nunca se aplicó aquí
[[ -e "$dest" ]] || exit 10
if [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    log_info "starship.toml enlazado al repo: ya tiene el prompt en dos líneas"
    exit 0
fi
if ! starship_is_dragon "$dest"; then
    log_info "starship.toml no es el de Dragon: no se toca ($dest)"
    exit 0
fi

# starship_merge <src> <dest> <out>: the repo's body + dest's dragon-palette block, validated as TOML.
# Prints "same" when dest already is that, "changed" after writing it to <out>.
merged="$(mktemp)"
trap 'rm -f -- "$merged"' EXIT
state="$(python3 -I - "$src" "$dest" "$merged" <<'PY'
import sys, tomllib
src, dest, out = (open(p, encoding="utf-8").read() if i < 2 else p for i, p in enumerate(sys.argv[1:]))
BEGIN = "# >>> dragon-palette"
body = src.split(BEGIN, 1)[0]
block = dest[dest.index(BEGIN):] if BEGIN in dest else (BEGIN + src.split(BEGIN, 1)[1] if BEGIN in src else "")
text = body + block
tomllib.loads(text)
if text == dest:
    print("same")
else:
    open(out, "w", encoding="utf-8").write(text)
    print("changed")
PY
)"
if [[ "$state" == same ]]; then
    log_info "starship.toml ya tiene el prompt en dos líneas: $dest"
    exit 0
fi
backup_copy "$dest"
run cp -- "$merged" "$dest"
log_info "starship.toml: prompt en dos líneas, con el bloque de dragon-palette intacto ($dest)"
