#!/usr/bin/env bash
# 015 — tiling modes (dwindle ↔ scrolling, per workspace): installs ~/.local/bin/dragon-tiling (scripts/tiling.sh) and
# refreshes the Hyprland / Quickshell configs when they are installed as copies (new scrolling block, SUPER + T, tiling.lua,
# the bar chip). No saved state is created: without ~/.local/state/dragon-island/tiling.json every workspace is dwindle.
# (Named 015 to follow the numbering of this folder; it is the "2026-10-tiling-modes" migration.)
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

command -v jq >/dev/null 2>&1 || { log_warn "Falta jq (lo necesita dragon-tiling): sudo pacman -S jq"; exit 10; }
run chmod +x "$REPO_DIR/scripts/tiling.sh"
run mkdir -p "$HOME/.local/bin"
deploy_item "$REPO_DIR/scripts/tiling.sh" "$HOME/.local/bin/dragon-tiling"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
for item in hypr quickshell; do
    if [[ -d "$CFG/$item" && ! -L "$CFG/$item" ]]; then deploy_item "$REPO_DIR/config/$item" "$CFG/$item"; fi
done
exit 0
