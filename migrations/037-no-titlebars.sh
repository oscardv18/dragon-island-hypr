#!/usr/bin/env bash
# 037 — ajuste de ventanas: no title bars. hyprbars is retired; the focused window gets the frame of the popovers
# (a top line and four cyan corner brackets, drawn by Quickshell) and a 1 px native border.
#   * hyprpm: hyprbars is disabled if it is enabled (the repo hyprland-plugins stays: hyprfocus comes from it). Its
#     state file is root's, so hyprpm asks for the password: confirmed first, and if it is skipped or fails, plugins.lua
#     still gives every window `hyprbars:no_bar` while the plugin is loaded. A live Hyprland unloads it right away
#     (`hyprctl plugin unload`, no sudo). hyprpm itself and its cache are left alone.
#   * A COPIED ~/.config/hypr gets plugins.lua, rules.lua and autostart.lua without hyprbars (backup first).
#   * A COPIED plugins-foreground.sh in the state dir (what install.sh / autostart run) is refreshed: it no longer
#     enables hyprbars and disables it on old installs. A link to the repo already has all of this.
#   * Close / maximize / float / minimize stay on SUPER + Q / F / SHIFT + Space / M (docs/KEYBINDS.md).
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
live=false
[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1 && live=true
changed=0

# refresh <repo file> <installed file>: a copy that differs is replaced (backup first); links are left alone
refresh() {
    local src="$1" dest="$2"
    [[ -L "$dest" || ! -e "$dest" ]] && return 0
    cmp -s "$src" "$dest" && return 0
    backup_copy "$dest"
    run cp -- "$src" "$dest"
    log_info "Actualizado $dest (sin hyprbars)."
    changed=1
}

# ---- copied config ----
if [[ -d "$HYPR" && ! -L "$HYPR" ]]; then
    for f in plugins.lua rules.lua autostart.lua; do refresh "$REPO_DIR/config/hypr/$f" "$HYPR/$f"; done
fi
refresh "$REPO_DIR/scripts/plugins-foreground.sh" "$STATE_DIR/plugins-foreground.sh"

# ---- hyprpm: disable hyprbars (its state file belongs to root: hyprpm asks for the password itself) ----
if command -v hyprpm >/dev/null 2>&1; then
    # `hyprpm list` prints «│ Plugin hyprbars» and then «└─ enabled: true» (with colour codes)
    if hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -A1 -E 'Plugin hyprbars$' | grep -q 'enabled: true'; then
        if confirm "[sudo] hyprpm va a desactivar hyprbars (pide tu contraseña). ¿Hacerlo ahora?"; then
            if run hyprpm disable hyprbars; then
                log_info "hyprbars desactivado en hyprpm: no se volverá a cargar."
            else
                log_warn "hyprpm disable hyprbars falló. Mientras siga activo, plugins.lua le quita la barra a todas las ventanas. Hazlo luego: hyprpm disable hyprbars"
            fi
        else
            log_warn "Omitido. plugins.lua le quita la barra a todas las ventanas mientras siga cargado. Hazlo luego: hyprpm disable hyprbars"
        fi
        changed=1
    fi
fi

# ---- live session: unload it now (no sudo needed) ----
if $live && hyprctl plugin list 2>/dev/null | grep -qi 'hyprbars'; then
    so=$(find "/var/cache/hyprpm/${USER:-$(id -un)}" -name hyprbars.so 2>/dev/null | head -1 || true)
    if [[ -n "$so" ]]; then run hyprctl plugin unload "$so" >/dev/null || log_warn "No se pudo descargar $so en vivo."; fi
    run hyprctl reload >/dev/null || true
    log_info "hyprbars descargado de la sesión actual."
    changed=1
fi

if [[ $changed -eq 0 ]]; then
    log_info "Sin barras de título ya: nada que hacer."
    exit 10
fi
log_info "Cerrar, maximizar, flotar y minimizar: SUPER + Q / F / SHIFT + Space / M."
exit 0
