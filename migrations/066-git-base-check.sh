#!/usr/bin/env bash
# 066 — refresh Git for base-branch reviews and merge simulation in copied installs.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
deploy_item "$REPO_DIR/dragon-core/dragon_git.py" "${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines/dragon_git.py"
deploy_item "$REPO_DIR/bin/dragon-git" "$HOME/.local/bin/dragon-git"
