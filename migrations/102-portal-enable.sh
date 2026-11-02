#!/usr/bin/env bash
# 102 — Dragon Portal: register the backend for this user (no sudo): ~/.local/share/xdg-desktop-portal/portals/dragon.portal +
# the D-Bus activation file + «FileChooser=dragon;gtk» in a copied hyprland-portals.conf. Only when python-gobject and the GTK
# fall back exist AND `dragon-portal serve` starts in a private bus (a registered backend that fails removes the whole file dialog,
# docs/PORTAL-API.md §2). Exit 10 = a precondition fails, retried on the next update.
# It does NOT restart xdg-desktop-portal (it would cut a screen share): the end of update.sh lists the manual step.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/portal-tools.sh
. "$REPO_DIR/lib/portal-tools.sh"
# the UI must be there too: a registered portal whose explorer cannot open would only ever fall back to GTK after 10 s
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/services/FilePicker.qml" ]] || {
    log_info "Dragon Portal: integra antes la interfaz (migración 101)."
    exit 10
}
portal_enable
