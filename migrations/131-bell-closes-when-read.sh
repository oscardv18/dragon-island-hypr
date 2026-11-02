#!/usr/bin/env bash
# 131 — The bell slot closes when nothing is unread (NotificationBell.qml); refresh copied configs without restarting the user's shell.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

cfg="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
[[ -d "$cfg" && ! -L "$cfg" ]] || exit 10
changed=false
# Tokens/component before their caller: a running copy must not reload a missing type.
# shellcheck disable=SC2043  # one file today; the loop keeps the same shape as 130
for file in modules/bar/NotificationBell.qml; do
    src="$REPO_DIR/config/quickshell/$file" dest="$cfg/$file"
    # Linked installs already follow their repository. Never write through a linked directory/file.
    linked=false
    parent="$dest"
    while [[ "$parent" != "$cfg" ]]; do
        [[ ! -L "$parent" ]] || linked=true
        parent="$(dirname "$parent")"
    done
    $linked && continue
    [[ -f "$dest" ]] && cmp -s "$src" "$dest" && continue
    backup_copy "$dest"
    run mkdir -p "$(dirname "$dest")"
    if $DRY_RUN; then
        log_info "[dry-run] Campana de notificaciones: $dest"
    else
        temporary="$(mktemp "$(dirname "$dest")/.bell-XXXXXX")"
        cp -- "$src" "$temporary"
        mv -T -- "$temporary" "$dest"
    fi
    changed=true
done
$changed || exit 10
log_info 'Campana ajustada: el hueco se cierra sin notificaciones pendientes. No se reinició Quickshell.'
