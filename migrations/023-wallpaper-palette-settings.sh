#!/usr/bin/env bash
# 023 — phase 3: the shell takes its accent from the wallpaper (services/WallPalette.qml + bin/dragon-palette).
#   - ~/.config/dragon-island/settings.json gets ONLY the keys it is missing: wallpaperPalette=true (already read since
#     phase 0, but maybe absent) and paletteApplyExternal=true. The user's values are never touched.
#   - Hyprland: the desktop right-click layer ("dragon-desktop") is excluded from hyprglass (config/hypr/glass.lua) and
#     SUPER + W opens the orbital picker; symlinked configs see it, copied ones get it from update.sh's config step.
#     A live Hyprland reloads its config so both take effect now.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/settings.json"
DEFAULTS='{"wallpaperPalette":true,"paletteApplyExternal":true}'
changed=0

if ! command -v jq >/dev/null 2>&1; then
    log_warn "Falta jq: «Paleta desde el fondo» y «Aplicar a las apps» usan su valor por defecto (activados) hasta que se instale."
    exit 10
fi

if [[ ! -e "$SETTINGS" ]]; then
    run mkdir -p "$(dirname "$SETTINGS")"
    if $DRY_RUN; then log_info "[dry-run] crearía $SETTINGS"; else jq . <<<"$DEFAULTS" > "$SETTINGS"; fi
    log_info "Creado $SETTINGS con la paleta desde el fondo activada."
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
    log_info "La paleta desde el fondo ya está configurada: nada que hacer."
    exit 10
fi
log_info "Paleta desde el fondo lista: Ajustes › Apariencia. SUPER + W o clic derecho en el escritorio abren el selector orbital."
exit 0
