#!/usr/bin/env bash
# dragon-island — coherence of pre-instalation.md with the code (run by tests/run-all.sh):
#   1. every ```bash block of pre-instalation.md passes `bash -n`
#   2. every step referenced by lib/checks.sh (CHECK_STEP) exists as "## Paso N — Title" with that exact title
#   3. the package line of Step 3 equals packages/base.txt
#   4. every package named in `pacman -S` / `yay -S` commands exists (pacman -Si / yay -Si, when available)
#   5. the generated package table is up to date
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$REPO_DIR/pre-instalation.md"
fails=0
bad() { echo "✘ $*"; fails=$((fails + 1)); }
ok()  { echo "✔ $*"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# 1. bash blocks → one file each
awk -v dir="$TMP" '
    /^```bash$/ { n++; f = sprintf("%s/block-%03d.sh", dir, n); on = 1; next }
    /^```$/ && on { on = 0; close(f); next }
    on { print > f }' "$DOC"
count=0
for f in "$TMP"/block-*.sh; do
    count=$((count + 1))
    bash -n "$f" 2>"$TMP/err" || { bad "bash -n falla en el bloque $(basename "$f"):"; cat "$TMP/err"; sed 's/^/    /' "$f"; }
done
(( count > 0 )) && ok "$count bloques bash revisados con bash -n"

# 2. steps referenced by the checks exist, with the same title
mapfile -t entries < <(awk -F'"' '/^    \[[a-z]+\]="/ { print $2 }' "$REPO_DIR/lib/checks.sh")
for e in "${entries[@]}"; do
    num="${e%%|*}"; title="${e#*|}"
    if grep -qxF "## Paso $num — $title" "$DOC"; then :; else bad "lib/checks.sh apunta al «Paso $num — $title» y no existe en pre-instalation.md"; fi
done
(( ${#entries[@]} > 0 )) && ok "${#entries[@]} comprobaciones apuntan a pasos que existen"

# 3. base tools
doc_base="$(grep -E '^sudo pacman -S --needed git base-devel' "$DOC" | head -n1 | sed 's/^sudo pacman -S --needed //' | tr ' ' '\n' | sort | tr '\n' ' ')"
file_base="$(awk '/^[[:space:]]*(#|$)/ { next } { print $1 }' "$REPO_DIR/packages/base.txt" | sort | tr '\n' ' ')"
if [[ "$doc_base" == "$file_base" ]]; then ok "El Paso 3 coincide con packages/base.txt"; else bad "Paso 3 ($doc_base) ≠ packages/base.txt ($file_base)"; fi

# 4. package names in commands
if command -v pacman >/dev/null 2>&1; then
    pk_off=(); pk_aur=()
    while IFS= read -r line; do
        case "$line" in
            sudo\ pacman\ -S*) read -ra w <<<"$line"; for t in "${w[@]:3}"; do [[ "$t" == -* ]] || pk_off+=("$t"); done ;;
            yay\ -S\ *) read -ra w <<<"$line"; for t in "${w[@]:2}"; do [[ "$t" == -* ]] || pk_aur+=("$t"); done ;;
        esac
    done < <(cat "$TMP"/block-*.sh)
    for p in "${pk_off[@]}"; do
        [[ "$p" =~ ^[a-z0-9@._+-]+$ ]] || continue
        pacman -Si "$p" >/dev/null 2>&1 || bad "paquete oficial inexistente en los comandos: $p"
    done
    if command -v yay >/dev/null 2>&1; then
        for p in "${pk_aur[@]}"; do yay -Si "$p" >/dev/null 2>&1 || bad "paquete AUR inexistente en los comandos: $p"; done
    else echo "- yay no está: se omite la comprobación de paquetes AUR"; fi
    ok "paquetes citados en comandos: ${#pk_off[@]} oficiales, ${#pk_aur[@]} AUR"
else echo "- sin pacman: se omite la comprobación de nombres (ejecuta esto en Arch)"; fi

# 5. generated table
if "$REPO_DIR/scripts/gen-package-table.sh" --check; then ok "La tabla de paquetes está al día"; else bad "La tabla de paquetes está desactualizada"; fi

exit "$fails"
