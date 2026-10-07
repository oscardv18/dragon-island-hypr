#!/usr/bin/env bash
# =============================================================================
# dragon-island — store.sh: the data side of the "Tienda" panel (services/Store.qml)
# Everything here is read-only (no sudo, no database writes). The installs / removals run in a terminal through
# bin/dragon-pkg. LC_ALL=C so pacman's field names are the English ones whatever the system language.
#   refresh [force]            official list (pacman -Sl), installed sets, AUR list (cached, refreshed once a day)
#   search <query> <limit>     official first, then AUR:  repo <TAB> name <TAB> version <TAB> installed(0/1)
#   info <official|aur> <pkg>  Key <TAB> Value (pacman -Si / AUR helper -Siia)
#   qinfo <pkg>                Key <TAB> Value of an installed package (pacman -Qi)
#   pkgbuild <pkg>             the PKGBUILD of an AUR package (helper -Gpa)
#   installed <explicit|aur>   name <TAB> version
#   preview-remove <pkg>...    OK <TAB> name for every package pacman -Rs would remove, or ERR <TAB> line
#   updates                    repo <TAB> name <TAB> old <TAB> new   (checkupdates + AUR helper -Qua)
#   orphans                    names (pacman -Qdtq)
#   cache                      "size <TAB> <du -sh>" and "old <TAB> <n packages paccache would delete>"
# =============================================================================
set -u
export LC_ALL=C

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dragon-island"
OFFICIAL="$CACHE/pkg-official.txt"
AUR_LIST="$CACHE/aur-list.txt"
ALL="$CACHE/pkg-all.txt"

aur_helper() { command -v paru 2>/dev/null || command -v yay 2>/dev/null || true; }

# "Key : value" blocks of pacman / yay -i → "Key<TAB>Value" (continuation lines are joined)
normalise() {
    awk '
        match($0, /^[A-Za-z][A-Za-z ]*[A-Za-z] +: /) {
            if (key != "") print key "\t" val
            key = substr($0, 1, RLENGTH); sub(/ +: $/, "", key)
            val = substr($0, RLENGTH + 1); next
        }
        /^ +[^ ]/ && key != "" { s = $0; sub(/^ +/, "", s); val = val "  " s; next }
        END { if (key != "") print key "\t" val }'
}

cmd="${1:-}"
shift || true

case "$cmd" in
    refresh)
        mkdir -p "$CACHE"
        pacman -Sl 2>/dev/null | awk '{ print $1 " " $2 " " $3 }' > "$OFFICIAL.tmp" && mv -f "$OFFICIAL.tmp" "$OFFICIAL"
        pacman -Qq 2>/dev/null > "$ALL"
        h="$(aur_helper)"
        if [[ -n "$h" ]]; then
            if [[ "${1:-}" == force || ! -s "$AUR_LIST" || -n "$(find "$AUR_LIST" -mmin +1440 2>/dev/null)" ]]; then
                "$h" -Slqa 2>/dev/null > "$AUR_LIST.tmp" && [[ -s "$AUR_LIST.tmp" ]] && mv -f "$AUR_LIST.tmp" "$AUR_LIST"
                rm -f "$AUR_LIST.tmp"
            fi
        fi
        echo 'done' ;;

    search)
        query="${1:-}"; limit="${2:-120}"
        [[ -n "${query// /}" ]] || exit 0
        [[ -s "$OFFICIAL" ]] || exit 0
        {
            awk -v q="$query" '
                function sub_seq(s, t,   i, j) { j = 1; for (i = 1; i <= length(s) && j <= length(t); i++) if (substr(s, i, 1) == substr(t, j, 1)) j++; return j > length(t) }
                function score(name, loose,   i, total, tok, p) {
                    total = 0
                    for (i = 1; i <= nt; i++) {
                        tok = toks[i]
                        if (name == tok) total += 100
                        else if (index(name, tok) == 1) total += 60
                        else if ((p = index(name, tok)) > 0) total += 40 - (p > 20 ? 20 : p)
                        else if (loose && length(tok) >= 3 && sub_seq(name, tok)) total += 8
                        else return -1
                    }
                    return total - length(name) / 100
                }
                # tier 0: every word is a prefix / substring; tier 1: fuzzy (letters in order, official only)
                BEGIN { nt = split(tolower(q), toks, / +/) }
                FILENAME == ARGV[1] { inst[$1] = 1; next }
                FILENAME == ARGV[2] { s = score(tolower($2), 1); if (s >= 0) printf "%d\t0\t%.3f\t%s\t%s\t%s\t%d\n", (s >= 30 ? 0 : 1), s, $1, $2, $3, ($2 in inst) ? 1 : 0; next }
                { s = score(tolower($1), 0); if (s >= 0) printf "0\t1\t%.3f\taur\t%s\t\t%d\n", s, $1, ($1 in inst) ? 1 : 0 }
            ' "$ALL" "$OFFICIAL" "$AUR_LIST" 2>/dev/null
        } | sort -t$'\t' -k1,1n -k2,2n -k3,3nr | head -n "$limit" | cut -f4- ;;

    info)
        src="${1:-}"; pkg="${2:-}"
        if [[ "$src" == aur ]]; then
            h="$(aur_helper)"; [[ -n "$h" ]] && "$h" -Siia "$pkg" 2>/dev/null | normalise
        else
            pacman -Si "$pkg" 2>/dev/null | normalise
        fi ;;

    qinfo)
        pacman -Qi "${1:-}" 2>/dev/null | normalise ;;

    pkgbuild)
        h="$(aur_helper)"
        if [[ -n "$h" ]]; then "$h" -Gpa "${1:-}" 2>&1; else echo "No hay yay ni paru."; fi ;;

    installed)
        if [[ "${1:-explicit}" == aur ]]; then
            pacman -Qm 2>/dev/null | awk '{ print $1 "\t" $2 }'
        else
            pacman -Qqm 2>/dev/null | sort > "$CACHE/.foreign.tmp" 2>/dev/null || : > "$CACHE/.foreign.tmp"
            pacman -Qe 2>/dev/null | awk 'NR == FNR { f[$1] = 1; next } !($1 in f) { print $1 "\t" $2 }' "$CACHE/.foreign.tmp" -
        fi ;;

    preview-remove)
        if out="$(pacman -Rsp --print-format '%n' "$@" 2>&1)"; then
            while IFS= read -r l; do [[ -n "$l" ]] && printf 'OK\t%s\n' "$l"; done <<< "$out"
        else
            while IFS= read -r l; do [[ -n "$l" ]] && printf 'ERR\t%s\n' "$l"; done <<< "$out"
        fi ;;

    updates)
        (checkupdates 2>/dev/null || true) | awk '{ print "official\t" $1 "\t" $2 "\t" $4 }'
        h="$(aur_helper)"
        [[ -n "$h" ]] && ("$h" -Qua 2>/dev/null || true) | awk '{ print "aur\t" $1 "\t" $2 "\t" $4 }' ;;

    orphans)
        pacman -Qdtq 2>/dev/null || true ;;

    cache)
        printf 'size\t%s\n' "$(du -sh /var/cache/pacman/pkg 2>/dev/null | cut -f1)"
        if command -v paccache >/dev/null 2>&1; then
            printf 'old\t%s\n' "$(paccache -d 2>/dev/null | awk '/finished dry run/ { n = $5 } END { print n + 0 }')"
        fi ;;

    *)
        echo "usage: $0 refresh|search|info|qinfo|pkgbuild|installed|preview-remove|updates|orphans|cache" >&2
        exit 2 ;;
esac
exit 0
