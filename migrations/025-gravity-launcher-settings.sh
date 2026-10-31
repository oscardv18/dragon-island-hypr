#!/usr/bin/env bash
# 025 — phase 4: the Gravity launcher, the orbital Alt+Tab and «Reducir movimiento» (services/Settings.qml).
#   ~/.config/dragon-island/settings.json gets ONLY the keys it is missing: launcherGravity=true, switcherOrbital=true,
#   reduceMotion=false. The user's values are never touched. config/hypr/binds.lua reads switcherOrbital when it loads,
#   so a live Hyprland reloads its config when something was added.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/settings.json"
DEFAULTS='{"launcherGravity":true,"switcherOrbital":true,"reduceMotion":false}'
changed=0

if ! command -v jq >/dev/null 2>&1; then
    log_warn "Falta jq: «Launcher Gravedad», «Alt+Tab orbital» y «Reducir movimiento» usan su valor por defecto hasta que se instale."
    exit 10
fi

if [[ ! -e "$SETTINGS" ]]; then
    run mkdir -p "$(dirname "$SETTINGS")"
    if $DRY_RUN; then log_info "[dry-run] crearía $SETTINGS"; else jq . <<<"$DEFAULTS" > "$SETTINGS"; fi
    log_info "Creado $SETTINGS con el launcher Gravedad y el Alt+Tab orbital activados."
    changed=1
elif jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
    absent_keys=$(jq -r --argjson d "$DEFAULTS" '[$d | keys[]] - keys | join(" ")' "$SETTINGS")
    if [[ -n "$absent_keys" ]]; then
        backup_copy "$SETTINGS"
        if $DRY_RUN; then
            log_info "[dry-run] añadiría a $SETTINGS: $absent_keys"
        else
            tmp=$(mktemp "${SETTINGS}.XXXXXX")
            jq --argjson d "$DEFAULTS" '$d + .' "$SETTINGS" > "$tmp"   # defaults under, the user's keys win
            mv -f -- "$tmp" "$SETTINGS"
        fi
        log_info "Ajustes añadidos a $SETTINGS: $absent_keys"
        changed=1
    fi
else
    log_warn "$SETTINGS no es un objeto JSON válido: no se toca (Quickshell usa los valores por defecto)."
fi

if [[ $changed -eq 1 && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    run hyprctl reload >/dev/null || true
fi

if [[ $changed -eq 0 ]]; then
    log_info "Los ajustes del launcher Gravedad ya están: nada que hacer."
    exit 10
fi
log_info "Launcher Gravedad listo: Ajustes › Launcher. SUPER + Espacio, Alt + Tab, SUPER + Tab y SUPER + V."
exit 0
