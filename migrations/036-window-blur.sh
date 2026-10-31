#!/usr/bin/env bash
# 036 — ajuste de ventanas: the native blur is back on translucent windows (Ghostty, kitty, herdr…).
#   Cause: with the «ahumado» / «clasico» glass styles hyprglass stays loaded but off (glass.lua), and its
#   `manage_window_blur` / `layers.manage_blur` options (true by default) kept taking the native blur away from the
#   windows it would have glassed — so the wallpaper showed sharp through the terminal. glass.lua now turns both off
#   outside «liquido» (and on again with it), and rules.lua says no_blur for video players, games and video/game content.
#   * A COPIED ~/.config/hypr gets the new glass.lua and rules.lua (backup first); a link to the repo already has them.
#   * A live Hyprland with hyprglass still managing the window blur reloads its config.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
changed=0

# ---- copied config: refresh the two files this change touches ----
if [[ -d "$HYPR" && ! -L "$HYPR" ]]; then
    for f in glass.lua rules.lua; do
        src="$REPO_DIR/config/hypr/$f" dest="$HYPR/$f"
        [[ -L "$dest" ]] && continue                       # per-file link: already the repo's
        if [[ ! -e "$dest" ]] || ! cmp -s "$src" "$dest"; then
            backup_copy "$dest"
            run cp -- "$src" "$dest"
            log_info "Actualizado $dest (desenfoque nativo de las ventanas)."
            changed=1
        fi
    done
fi

# ---- live session: reload when hyprglass still takes the native blur away from the windows ----
style=$( { tr -d '[:space:]' < "${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/glass-style"; } 2>/dev/null || true)
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1 && [[ "$style" != "liquido" ]]; then
    if hyprctl getoption plugin:hyprglass:manage_window_blur 2>/dev/null | grep -q "true"; then
        run hyprctl reload >/dev/null || true
        log_info "Hyprland recargado: las ventanas translúcidas vuelven a desenfocar el fondo."
        changed=1
    fi
fi

if [[ $changed -eq 0 ]]; then
    log_info "El desenfoque de las ventanas ya está bien: nada que hacer."
    exit 10
fi
exit 0
