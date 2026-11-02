#!/usr/bin/env bash
# Read-only entry point. No common.sh, TUI, logs, sudo or deployment is sourced.
preflight() {
    PYTHONDONTWRITEBYTECODE=1 python3 "${REPO_DIR:?}/lib/installer_preflight.py" "$@"
}
