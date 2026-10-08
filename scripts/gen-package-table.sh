#!/usr/bin/env bash
# dragon-island — markdown table of everything the installer can install, generated from packages/*.txt.
#   gen-package-table.sh           print the table
#   gen-package-table.sh --inject  rewrite the block between the package markers of pre-instalation.md
#   gen-package-table.sh --check   exit 1 when pre-instalation.md is out of date (used by tests/check-docs.sh)
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$REPO_DIR/pre-instalation.md"
BEGIN='<!-- packages:begin (generado por scripts/gen-package-table.sh; no editar a mano) -->'
END='<!-- packages:end -->'

table() {
    echo "| Paquete | Módulo | Origen |"
    echo "|---|---|---|"
    local f mod src name
    for f in base pacman-core aur-core pacman-shell pacman-theme aur-theme pacman-login pacman-plugins; do
        case "$f" in
            base) mod="(previo, Paso 3)"; src="oficial" ;;
            pacman-*) mod="${f#pacman-}"; src="oficial" ;;
            aur-*) mod="${f#aur-}"; src="AUR" ;;
        esac
        while read -r name; do echo "| \`$name\` | $mod | $src |"; done < <(awk '/^[[:space:]]*(#|$|@)/ { next } { print $1 }' "$REPO_DIR/packages/$f.txt")
    done
    awk '/^[[:space:]]*(#|$)/ { next } /^@/ { sec = substr($1, 2); next } { split($1, a, ":"); printf "| `%s` | extras (%s) | %s |\n", a[2], sec, (a[1] == "aur" ? "AUR" : "oficial") }' "$REPO_DIR/packages/extras.txt"
    echo "| \`herdr\` | extras | instalador oficial (sin root, ~/.local/bin) |"
    echo "| \`zsh-autosuggestions\`, \`zsh-syntax-highlighting\`, \`fzf-tab\` | shell | git clone |"
    echo "| \`hyprbars\`, \`hyprfocus\`, \`hyprglass\` | plugins | hyprpm |"
    echo "| Mis apps: $(awk '/^[[:space:]]*(#|$)/ { next } { printf "%s ", $1 }' "$REPO_DIR/packages/user-pacman.txt" "$REPO_DIR/packages/user-aur.txt") | extras (myapps) | lo que instalaste desde la Tienda |"
}

render() {  # the whole document with the block replaced
    awk -v b="$BEGIN" -v e="$END" -v tbl="$(table)" '
        $0 == b { print; print tbl; skip = 1; next }
        $0 == e { skip = 0 }
        !skip { print }' "$DOC"
}

case "${1:-}" in
    "") table ;;
    --inject) tmp="$(mktemp)"; render > "$tmp"; cat "$tmp" > "$DOC"; rm -f "$tmp" ;;
    --check) diff -q <(render) "$DOC" >/dev/null || { echo "pre-instalation.md: la tabla de paquetes está desactualizada (scripts/gen-package-table.sh --inject)"; exit 1; } ;;
    *) echo "Uso: $0 [--inject|--check]" >&2; exit 2 ;;
esac
