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
    PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_profiles.py"
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
