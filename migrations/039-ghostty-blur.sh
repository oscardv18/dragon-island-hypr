#!/usr/bin/env bash
# 039 — Ghostty blurs its background again. Since Ghostty 1.4 + Hyprland 0.57, Ghostty asks the compositor for its
# background blur, so `background-blur = false` (our old config) made Hyprland leave the wallpaper sharp behind the
# terminal — even with the native blur on (kitty, which never asks, was blurred). The repo config says `true` now.
#   * A COPIED ~/.config/ghostty/config gets `background-blur = true` (backup first; only that line, the user's
#     opacity, font and the rest stay). A link to the repo already has it.
#   * Open terminals pick it up when Ghostty reloads its config (Ctrl+Shift+, or a new window). Nothing is signalled
#     or closed from here.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"

if [[ ! -f "$CFG" || -L "$CFG" ]] || grep -qE '^[[:space:]]*background-blur[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$CFG"; then
    log_info "Ghostty ya pide el desenfoque del fondo (o su configuración es un enlace al repo): nada que hacer."
    exit 10
fi

backup_copy "$CFG"
if $DRY_RUN; then
    log_info "[dry-run] pondría background-blur = true en $CFG"
elif grep -qE '^[[:space:]]*background-blur[[:space:]]*=' "$CFG"; then
    sed -i -E 's/^[[:space:]]*background-blur[[:space:]]*=.*/background-blur = true/' "$CFG"
else
    printf '\n# the compositor blurs what is behind the terminal (migration 039)\nbackground-blur = true\n' >> "$CFG"
fi
log_info "Ghostty: background-blur = true en $CFG. Recarga Ghostty (Ctrl+Shift+,) o abre una ventana nueva."
exit 0
