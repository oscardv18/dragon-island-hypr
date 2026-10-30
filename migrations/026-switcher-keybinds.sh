#!/usr/bin/env bash
# 026 — phase 4 keybinds (config/hypr/binds.lua):
#   ALT + Tab / ALT + SHIFT + Tab / releasing Alt → the orbital switcher (qs ipc call switcher next | prev | confirm)
#   SUPER + Tab → the workspaces overview      SUPER + V (and SUPER + SHIFT + V) → the launcher's clipboard ring
#   «Alternar flotante» moves from SUPER + V to SUPER + SHIFT + Space.
# Symlinked configs already see the new binds.lua; a COPIED ~/.config/hypr (and ~/.config/quickshell, which has the new
# windows) is replaced with the repo's, the old one backed up. ~/.config/hypr/local.lua is the user's: never edited, only
# a warning when it binds one of these keys itself (it loads last, so it would win).
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
changed=0

for item in hypr quickshell; do
    dest="$CFG/$item"
    [[ -d "$dest" && ! -L "$dest" ]] || continue
    if diff -rq -- "$REPO_DIR/config/$item" "$dest" >/dev/null 2>&1; then continue; fi
    if confirm "¿Sustituir la copia de $dest por la del repositorio (atajos Alt+Tab, SUPER+Tab y SUPER+V)? Se guarda una copia"; then
        deploy_item "$REPO_DIR/config/$item" "$dest"     # backs the old copy up first
        changed=1
    else
        log_warn "No se tocó $dest: los atajos nuevos no estarán hasta que lo actualices (./update.sh)."
    fi
done

local_lua="$CFG/hypr/local.lua"
if [[ -f "$local_lua" ]] && grep -Eiq '"(ALT ?\+ ?(SHIFT ?\+ ?)?Tab|SUPER ?\+ ?(SHIFT ?\+ ?)?(Tab|V))"|mainMod ?\.\. ?" ?\+ ?(SHIFT ?\+ ?)?(Tab|V)"' "$local_lua"; then
    log_warn "$local_lua define Alt+Tab, SUPER+Tab o SUPER+V por su cuenta y se carga el último: revisa esas líneas."
fi

if [[ $changed -eq 1 && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    run hyprctl reload >/dev/null || true
fi

if [[ $changed -eq 0 ]]; then
    log_info "binds.lua ya trae los atajos de la fase 4 (configuración enlazada o al día): nada que copiar."
    exit 10
fi
log_info "Atajos nuevos: Alt+Tab orbital, SUPER+Tab escritorios, SUPER+V portapapeles; flotante pasa a SUPER+SHIFT+Space."
exit 0
