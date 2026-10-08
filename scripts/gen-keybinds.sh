#!/usr/bin/env bash
# dragon-island — reference table of every Hyprland bind, generated from the REAL config (`hyprctl binds -j`, so it needs a
# running Hyprland). Rows with the same "Grupo · Texto" description are merged, like the SUPER+F1 panel does.
#   gen-keybinds.sh           print the markdown
#   gen-keybinds.sh --inject  rewrite the block between the binds markers of docs/KEYBINDS.md
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$REPO_DIR/docs/KEYBINDS.md"
BEGIN='<!-- binds:begin (generado por scripts/gen-keybinds.sh desde hyprctl binds -j; no editar a mano) -->'
END='<!-- binds:end -->'

[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || { echo "Hace falta una sesión de Hyprland (hyprctl binds -j)." >&2; exit 1; }
command -v jq >/dev/null || { echo "Falta jq (sudo pacman -S jq)." >&2; exit 1; }

table() {
    hyprctl binds -j | jq -r '
        def mods: [ (if (.modmask / 64 | floor) % 2 == 1 then "SUPER" else empty end),
                    (if (.modmask / 8 | floor) % 2 == 1 then "ALT" else empty end),
                    (if (.modmask / 4 | floor) % 2 == 1 then "CTRL" else empty end),
                    (if (.modmask / 1 | floor) % 2 == 1 then "SHIFT" else empty end) ];
        map(select(.description != "")
            | {group: (.description | split(" · ")[0]), text: (.description | split(" · ")[1:] | join(" · ")),
               keys: ((mods + [.key]) | join(" + "))})
        | group_by(.group)
        | .[]
        | "### \(.[0].group)\n\n| Atajo | Acción |\n|---|---|\n"
          + ( group_by(.text) | map("| \(map("`\(.keys)`") | unique | join(" · ")) | \(.[0].text) |") | join("\n") ) + "\n"'
}

case "${1:-}" in
    "") table ;;
    --inject)
        tbl="$(table)"; tmp="$(mktemp)"
        awk -v b="$BEGIN" -v e="$END" -v tbl="$tbl" '$0 == b { print; print tbl; skip = 1; next } $0 == e { skip = 0 } !skip { print }' "$DOC" > "$tmp"
        cat "$tmp" > "$DOC"; rm -f "$tmp" ;;
    *) echo "Uso: $0 [--inject]" >&2; exit 2 ;;
esac
