#!/usr/bin/env bash
# 043 — shared credential filter for copied and linked engine installations.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/engines.sh
. "$REPO_DIR/lib/engines.sh"
# shellcheck source=lib/activity.sh
. "$REPO_DIR/lib/activity.sh"
engines_setup
activity_setup
