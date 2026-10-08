#!/usr/bin/env bash
# 014 — notch dashboard tabs (apps in the background · AI): installs the default settings file
# ~/.config/dragon-island/background-apps.json (never overwritten: it is the user's) and refreshes the shell and the
# Hyprland rules/glass (new layer namespace "dragon-background-apps") when they are installed as copies.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
dest="$CFG/dragon-island/background-apps.json"
old="$CFG/dragon-island/bottom-islands.json"
if [[ -e "$old" && ! -e "$dest" ]]; then run mv -- "$old" "$dest"; fi
if [[ -e "$dest" ]]; then
    log_info "Ya existe $dest: no se toca."
else
    run mkdir -p "$(dirname "$dest")"
    run cp -- "$REPO_DIR/config/dragon-island/background-apps.json" "$dest"
    log_info "Creado $dest"
fi

# copies of the configs (symlinked installs already see the repo)
for item in quickshell hypr; do
    if [[ -d "$CFG/$item" && ! -L "$CFG/$item" ]]; then deploy_item "$REPO_DIR/config/$item" "$CFG/$item"; fi
done
exit 0
