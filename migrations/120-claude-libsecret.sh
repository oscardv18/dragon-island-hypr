#!/usr/bin/env bash
# 120 — Electron under Hyprland must select the existing Secret Service explicitly.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# Only configure launchers which actually support this flags file.
launcher="$(command -v claude-desktop || true)"
[[ -n "$launcher" ]] || exit 10
grep -qF 'claude-desktop-flags.conf' "$launcher" || { log_warn 'Launcher de Claude sin archivo de flags; revisar docs/KEYRING.md.'; exit 10; }
while IFS= read -r target; do backup_copy "$target"; done < <(python3 "$REPO_DIR/scripts/claude-keyring.py" --backups)
if $DRY_RUN; then
    python3 "$REPO_DIR/scripts/claude-keyring.py" --dry-run
else
    python3 "$REPO_DIR/scripts/claude-keyring.py"
fi
