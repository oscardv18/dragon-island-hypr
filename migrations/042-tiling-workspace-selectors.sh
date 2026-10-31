#!/usr/bin/env bash
# 042 — Refresh a copied dragon-tiling: Hyprland 0.57 needs bare IDs for numbered workspace rules.
# Saved tiling.json is unchanged; tiling.lua restores it on reload. Backup before replacing a copied runner.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

src="$REPO_DIR/scripts/tiling.sh"
dest="$HOME/.local/bin/dragon-tiling"
[[ -e "$dest" || -L "$dest" ]] || exit 10
if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then exit 10; fi
if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then exit 10; fi
deploy_item "$src" "$dest"
