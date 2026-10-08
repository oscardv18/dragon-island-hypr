#!/usr/bin/env bash
# 011 — herdr (agents multiplexer): official installer (not in the repos or the AUR; no root), the Dragonized config,
# the dragon-herdr launcher (SUPER + A), and the zsh completion (~/.zfunc/_herdr). herdr updates itself: `herdr update`.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

ensure_herdr || { log_info "Se reintentará la próxima vez."; exit 10; }
deploy_herdr

# a running server picks the new config up without restarting (and without closing the panes)
if [[ -x "$HOME/.local/bin/herdr" && -S "$HOME/.config/herdr/herdr.sock" ]]; then
    "$HOME/.local/bin/herdr" server reload-config >/dev/null 2>&1 || true
fi
exit 0
