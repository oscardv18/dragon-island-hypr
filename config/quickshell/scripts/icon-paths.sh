#!/usr/bin/env bash
# icon-paths.sh <name>...  →  "name<TAB>/path/to/icon" for each icon name that is a file in the usual places
# (hicolor sizes from big to small, pixmaps, the user's icons, then any other installed theme). Absolute paths
# pass through. Used by services/Apps.qml: the orbital launcher draws real files (big icons from the image
# provider did not render in its window).
set -u
dirs=()
for sz in 256x256 128x128 512x512 96x96 64x64 48x48 scalable 32x32; do
    dirs+=("/usr/share/icons/hicolor/$sz/apps" "$HOME/.local/share/icons/hicolor/$sz/apps")
done
dirs+=(/usr/share/pixmaps "$HOME/.local/share/pixmaps")
for name in "$@"; do
    [[ -n "$name" ]] || continue
    if [[ "$name" == /* && -f "$name" ]]; then printf '%s\t%s\n' "$name" "$name"; continue; fi
    found=""
    for d in "${dirs[@]}"; do
        for ext in png svg xpm; do
            if [[ -f "$d/$name.$ext" ]]; then found="$d/$name.$ext"; break 2; fi
        done
    done
    if [[ -z "$found" ]]; then
        # shellcheck disable=SC2012
        found="$(ls -1 /usr/share/icons/*/*/apps/"$name".{svg,png} /usr/share/icons/*/apps/*/"$name".{svg,png} 2>/dev/null | head -n1)"
    fi
    [[ -n "$found" ]] && printf '%s\t%s\n' "$name" "$found"
done
exit 0
