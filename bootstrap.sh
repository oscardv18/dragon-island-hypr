#!/usr/bin/env bash
# =============================================================================
# dragon-island — bootstrap: installs git + gum if missing, clones the repo and launches install.sh.
# Preferred way (you can read everything first):   git clone <repo> && cd dragon-island-hypr && ./install.sh
# Alternative:  curl -fsSL <raw-url>/bootstrap.sh -o bootstrap.sh ; less bootstrap.sh ; bash bootstrap.sh [install.sh options]
# Read the script BEFORE running anything fetched from the internet. Requirements: pre-instalation.md.
# =============================================================================
set -Eeuo pipefail

REPO_URL="${DRAGON_REPO:-https://github.com/oscardv18/dragon-island-hypr.git}"
DEST="${DRAGON_DIR:-$HOME/dragon-island-hypr}"

[[ $EUID -ne 0 ]] || { echo "ERROR: no ejecutes bootstrap.sh como root." >&2; exit 1; }
[[ -f /etc/os-release ]] || { echo "ERROR: sistema no reconocido." >&2; exit 1; }
# shellcheck source=/dev/null
. /etc/os-release
[[ "$ID" =~ ^(arch|endeavouros|cachyos)$ || " ${ID_LIKE:-} " == *" arch "* ]] \
    || { echo "ERROR: solo Arch y derivadas (EndeavourOS, Arch, CachyOS). Ver docs/INSTALL.md." >&2; exit 1; }

# when piped (curl | bash) stdin is not a terminal: take answers from /dev/tty
if [[ ! -t 0 && -r /dev/tty ]]; then exec </dev/tty; fi

missing=()
for t in git gum; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Faltan: ${missing[*]}. Se instalarán con:  sudo pacman -S --needed ${missing[*]}"
    read -r -p "¿Continuar? [s/N] " a
    [[ "$a" =~ ^[sSyY]$ ]] || { echo "Cancelado. Instálalos tú (pre-instalation.md, Paso 3) y repite."; exit 1; }
    sudo pacman -S --needed "${missing[@]}"
fi

if [[ -d "$DEST/.git" ]]; then
    echo "Ya existe $DEST: se actualiza (git pull --ff-only)."
    git -C "$DEST" pull --ff-only || echo "AVISO: no se pudo actualizar; se usa la copia local."
else
    git clone "$REPO_URL" "$DEST"
fi

cd "$DEST"
exec ./install.sh "$@"
