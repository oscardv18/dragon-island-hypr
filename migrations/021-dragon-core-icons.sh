#!/usr/bin/env bash
# 021 — the shell's own icon theme, Dragon-Core (shell.qml: //@ pragma IconTheme Dragon-Core).
#   ~/.local/share/icons/Dragon-Core → config/icons/Dragon-Core (Inherits=MacTahoe-purple-dark,WhiteSur-dark,hicolor).
#   Installs nothing: MacTahoe (mactahoe-icon-theme-git) and WhiteSur (whitesur-icon-theme) come from the AUR with the
#   theme module / update.sh. Without MacTahoe-purple-dark the theme would fall back to WhiteSur / hicolor, so this
#   warns and exits 10 (retried on the next update) instead of deploying a half theme.
# Qt / GTK apps keep their own icon theme (Sweet-Purple); only the shell changes.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

SRC="$REPO_DIR/config/icons/Dragon-Core"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/icons/Dragon-Core"
PRIMARY="MacTahoe-purple-dark"

primary_found=false
for root in /usr/share/icons "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$HOME/.icons"; do
    [[ -f "$root/$PRIMARY/index.theme" ]] && primary_found=true
done
if ! $primary_found; then
    log_warn "Falta el tema de iconos $PRIMARY (yay -S mactahoe-icon-theme-git). Dragon-Core no se crea todavía."
    exit 10
fi
[[ -d /usr/share/icons/WhiteSur-dark ]] || log_warn "Falta WhiteSur-dark (yay -S whitesur-icon-theme): Dragon-Core solo tendrá MacTahoe de respaldo."

if [[ -L "$DEST" && "$(readlink -f "$DEST")" == "$(readlink -f "$SRC")" ]] \
   || [[ "$LINK_MODE" == "copy" && -d "$DEST" && ! -L "$DEST" ]] && diff -rq -- "$SRC" "$DEST" >/dev/null 2>&1; then
    log_info "Dragon-Core ya está en $DEST: nada que hacer."
    exit 10
fi

deploy_item "$SRC" "$DEST"
log_info "Tema de iconos del shell Dragon-Core listo (reinicia Quickshell o ejecuta ./update.sh para verlo)."
exit 0
