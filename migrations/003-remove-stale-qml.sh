#!/usr/bin/env bash
# 003 — one blur system per layer: the bar is now one window per island and every notification card its own
# window. Removes the QML files that no longer exist from a *copied* ~/.config/quickshell (symlinked
# installs see the repo directly). update.sh itself never deletes files; this does, with a backup.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

QS_DIR="$HOME/.config/quickshell"
STALE=(
    modules/notifications/NotificationPopups.qml
    modules/island/Island.qml
    modules/island/Dashboard.qml
    modules/island/DashHeader.qml
    modules/island/MediaCard.qml
    modules/island/QuickToggles.qml
    modules/island/RecentNotifications.qml
    modules/island/SystemCard.qml
    modules/island/PillContent.qml
)

if [[ ! -d "$QS_DIR" ]]; then
    log_info "No hay $QS_DIR: nada que limpiar."
    exit 0
fi
if [[ "$(readlink -f "$QS_DIR")" == "$(readlink -f "$REPO_DIR/config/quickshell")" ]]; then
    log_info "config/quickshell es un symlink al repo: no hay archivos obsoletos."
    exit 0
fi

removed=0
for f in "${STALE[@]}"; do
    [[ -e "$QS_DIR/$f" && ! -e "$REPO_DIR/config/quickshell/$f" ]] || continue
    backup_copy "$QS_DIR/$f"
    run rm -f -- "$QS_DIR/$f"
    removed=$((removed + 1))
done
log_info "Archivos obsoletos eliminados: $removed"
exit 0
