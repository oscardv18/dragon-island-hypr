#!/usr/bin/env bash
# =============================================================================
# dragon-island — environment for migrations/*.sh: defaults for the variables update.sh exports, so a
# migration also runs on its own (`bash migrations/001-….sh`, optionally with DRY_RUN=true).
# Sourced after REPO_DIR is set.
# =============================================================================
PROJECT="dragon-island"
STATE_DIR="${STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT}"
LOG="${LOG:-$STATE_DIR/update.log}"
BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)}"
MANIFEST="${MANIFEST:-$STATE_DIR/manifest}"
DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"
LINK_MODE="${LINK_MODE:-symlink}"
COMPONENTS_FILE="${COMPONENTS_FILE:-$STATE_DIR/components}"
RELOGIN_FILE="${RELOGIN_FILE:-$STATE_DIR/needs-relogin}"
[[ -t 0 && -t 1 ]] || ASSUME_YES=true
mkdir -p "$STATE_DIR"
# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
