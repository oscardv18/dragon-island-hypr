#!/usr/bin/env bash
# 041 — Refresh the installed plugin runner and deploy its read-only session helper.
# Backup copies before replacement; symlinks already see repo changes. No session reload or sudo here.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

[[ -e "$STATE_DIR/plugins-foreground.sh" || -L "$STATE_DIR/plugins-foreground.sh" ]] || exit 10
changed=0
for item in scripts/plugins-foreground.sh lib/hyprland-session.sh; do
    src="$REPO_DIR/$item"
    dest="$STATE_DIR/${item##*/}"
    if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then continue; fi
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then continue; fi
    deploy_item "$src" "$dest"
    changed=1
done
[[ $changed -eq 1 ]] || exit 10
