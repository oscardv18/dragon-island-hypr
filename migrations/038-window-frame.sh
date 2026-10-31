#!/usr/bin/env bash
# 038 — ajuste de ventanas: the frame of the focused window. Quickshell draws the popovers' top line and corner
# brackets around it (modules/frame/FrameWindow.qml); Hyprland feeds it the real geometry (config/hypr/framewatch.lua,
# required by hyprland.lua) and draws a 1 px discreet native border (look.lua: cyan 30 % / black 30 %, no light edge).
#   * A COPIED ~/.config/hypr gets framewatch.lua, hyprland.lua and look.lua (backup first); a link to the repo already
#     has them. Ajustes › Apariencia › Contorno de ventanas defaults to «escuadras»: settings.json is not touched.
#   * A live Hyprland reloads its config when its border is still the old 2 px one.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
changed=0

if [[ -d "$HYPR" && ! -L "$HYPR" ]]; then
    for f in framewatch.lua hyprland.lua look.lua; do
        src="$REPO_DIR/config/hypr/$f" dest="$HYPR/$f"
        [[ -L "$dest" ]] && continue
        if [[ ! -e "$dest" ]] || ! cmp -s "$src" "$dest"; then
            backup_copy "$dest"
            run cp -- "$src" "$dest"
            log_info "Actualizado $dest (contorno de la ventana enfocada)."
            changed=1
        fi
    done
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1 \
    && [[ "$(hyprctl getoption general:border_size 2>/dev/null | awk '/int:/ {print $2}')" != "1" ]]; then
    run hyprctl reload >/dev/null || true
    log_info "Hyprland recargado: borde nativo de 1 px y contorno de la ventana enfocada."
    changed=1
fi

if [[ $changed -eq 0 ]]; then
    log_info "El contorno de las ventanas ya está al día: nada que hacer."
    exit 10
fi
log_info "Contorno de ventanas: Ajustes › Apariencia (escuadras · solo hilo · nada)."
exit 0
