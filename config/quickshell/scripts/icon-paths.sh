#!/usr/bin/env bash
# icon-paths.sh <name>...  →  "name<TAB>/path/to/icon" for each icon name that is a file.
# Order: the shell's icon theme first (the `//@ pragma IconTheme` of shell.qml, e.g. Sweet-Purple = Sweet Folders on
# top of Candy) and the themes it Inherits (candy-icons, breeze-dark, Adwaita ...), then hicolor, pixmaps and the
# user's icons (the app's own), then any other installed theme. Absolute paths pass through.
# Used by services/Apps.qml (the dock and the orbital launcher draw real files: the image provider returned blank
# pixmaps for most app icons in the launcher window).
set -u
shell_qml="$(dirname -- "${BASH_SOURCE[0]}")/../shell.qml"
theme="${ICON_THEME:-$(sed -n 's|^//@ pragma IconTheme[[:space:]]\+||p' "$shell_qml" 2>/dev/null | head -n1 | tr -d '[:space:]')}"
theme="${theme:-hicolor}"

roots=(/usr/share/icons "$HOME/.local/share/icons")

# the theme and everything it Inherits, in order (breadth first, each once)
chain=()
queue=("$theme")
declare -A seen=()
while [[ ${#queue[@]} -gt 0 ]]; do
    t="${queue[0]}"; queue=("${queue[@]:1}")
    [[ -n "$t" && -z "${seen[$t]:-}" ]] || continue
    seen[$t]=1
    for r in "${roots[@]}"; do
        if [[ -f "$r/$t/index.theme" ]]; then
            chain+=("$r/$t")
            IFS=',' read -r -a parents <<< "$(sed -n 's/^Inherits=//p' "$r/$t/index.theme" | head -n1)"
            queue+=("${parents[@]}")
        fi
    done
done

first_in_theme() {   # first_in_theme <theme dir> <name>
    local t="$1" n="$2" f
    for f in "$t"/apps/scalable/"$n".svg "$t"/apps/*/"$n".svg "$t"/apps/*/"$n".png \
             "$t"/*/apps/"$n".svg "$t"/*/apps/"$n".png "$t"/*/*/"$n".svg "$t"/*/*/"$n".png; do
        [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
    done
    return 1
}

fallback_dirs=()
for sz in 256x256 128x128 512x512 96x96 64x64 48x48 scalable 32x32; do
    fallback_dirs+=("/usr/share/icons/hicolor/$sz/apps" "$HOME/.local/share/icons/hicolor/$sz/apps")
done
fallback_dirs+=(/usr/share/pixmaps "$HOME/.local/share/pixmaps")

for name in "$@"; do
    [[ -n "$name" ]] || continue
    if [[ "$name" == /* && -f "$name" ]]; then printf '%s\t%s\n' "$name" "$name"; continue; fi
    found=""
    for t in "${chain[@]}"; do
        found="$(first_in_theme "$t" "$name")" && break
        found=""
    done
    if [[ -z "$found" ]]; then
        for d in "${fallback_dirs[@]}"; do
            for ext in png svg xpm; do
                if [[ -f "$d/$name.$ext" ]]; then found="$d/$name.$ext"; break 2; fi
            done
        done
    fi
    if [[ -z "$found" ]]; then
        # shellcheck disable=SC2012
        found="$(ls -1 /usr/share/icons/*/*/apps/"$name".{svg,png} /usr/share/icons/*/apps/*/"$name".{svg,png} 2>/dev/null | head -n1)"
    fi
    [[ -n "$found" ]] && printf '%s\t%s\n' "$name" "$found"
done
exit 0
