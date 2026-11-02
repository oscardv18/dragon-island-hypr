#!/usr/bin/env bash
# 122 — Telegram can bypass GTK entirely and show Qt's unthemed QFileDialog.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/telegram-portal.sh
. "$REPO_DIR/lib/telegram-portal.sh"
telegram_portal_setup
