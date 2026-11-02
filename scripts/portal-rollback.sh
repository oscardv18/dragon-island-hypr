#!/usr/bin/env bash
# dragon-island — turn Dragon Portal off: the file dialogs go back to xdg-desktop-portal-gtk. No sudo, nothing else is touched.
#   scripts/portal-rollback.sh [--dry-run] [--restart]
# It removes the user's dragon.portal and the D-Bus activation file (the «FileChooser=dragon;gtk» line may stay: without the .portal
# xdg-desktop-portal skips «dragon»). --restart also runs `systemctl --user restart xdg-desktop-portal` (it cuts a running screen share).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
DRY_RUN=false
RESTART=false
for a in "$@"; do
    case "$a" in
        --dry-run) DRY_RUN=true ;;
        --restart) RESTART=true ;;
        -h | --help) sed -n 2,6p "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "Opción desconocida: $a" >&2; exit 2 ;;
    esac
done
export DRY_RUN
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/portal-tools.sh
. "$REPO_DIR/lib/portal-tools.sh"
portal_disable
if $RESTART; then run systemctl --user restart xdg-desktop-portal
else log_info "Listo. Reinicia xdg-desktop-portal (systemctl --user restart xdg-desktop-portal) o cierra sesión para que lo note."; fi
