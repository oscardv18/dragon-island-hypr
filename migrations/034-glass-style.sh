#!/usr/bin/env bash
# 034 — pulido: the «ahumado» glass becomes the default look (docs/design/28-emergentes.png).
#   * ~/.config/dragon-island/settings.json gets glassStyle = "ahumado". The user asked for the new look on the installed
#     system too, so this one key IS set even when present (any other key is never touched); a backup is kept.
#   * ~/.config/dragon-island/glass-style (read by config/hypr/glassstyle.lua when the Hyprland config loads) says
#     "ahumado": hyprglass stays installed but inactive (glass.lua turns its windows and layers off) and the native
#     blur of look.lua / rules.lua draws the layers. Ajustes › Apariencia › Cristal switches it back live.
#   * A live Hyprland reloads its config when something changed.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island"
SETTINGS="$DIR/settings.json"
STYLE_FILE="$DIR/glass-style"
STYLE="ahumado"
changed=0

# ---- settings.json ----
if ! command -v jq >/dev/null 2>&1; then
    log_warn "Falta jq: settings.json no se toca (Quickshell usa «ahumado» por defecto si no hay clave)."
elif [[ ! -e "$SETTINGS" ]]; then
    run mkdir -p "$DIR"
    if $DRY_RUN; then log_info "[dry-run] crearía $SETTINGS con glassStyle=$STYLE"; else jq -n --arg s "$STYLE" '{glassStyle: $s}' > "$SETTINGS"; fi
    log_info "Creado $SETTINGS con el cristal ahumado."
    changed=1
elif jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
    if [[ "$(jq -r '.glassStyle // ""' "$SETTINGS")" != "$STYLE" ]]; then
        backup_copy "$SETTINGS"
        if $DRY_RUN; then
            log_info "[dry-run] pondría glassStyle=$STYLE en $SETTINGS"
        else
            tmp=$(mktemp "${SETTINGS}.XXXXXX")
            jq --arg s "$STYLE" '.glassStyle = $s' "$SETTINGS" > "$tmp"
            mv -f -- "$tmp" "$SETTINGS"
        fi
        log_info "Cristal ahumado activado en $SETTINGS."
        changed=1
    fi
else
    log_warn "$SETTINGS no es un objeto JSON válido: no se toca."
fi

# ---- glass-style (Hyprland) ----
current_style=$( { tr -d '[:space:]' < "$STYLE_FILE"; } 2>/dev/null || true)
if [[ "$current_style" != "$STYLE" ]]; then
    [[ -e "$STYLE_FILE" ]] && backup_copy "$STYLE_FILE"
    run mkdir -p "$DIR"
    if $DRY_RUN; then log_info "[dry-run] escribiría «$STYLE» en $STYLE_FILE"; else printf '%s\n' "$STYLE" > "$STYLE_FILE"; fi
    log_info "Hyprland: cristal «$STYLE» ($STYLE_FILE). hyprglass queda instalado pero inactivo."
    changed=1
fi

if [[ $changed -eq 1 && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    run hyprctl reload >/dev/null || true
fi

if [[ $changed -eq 0 ]]; then
    log_info "El cristal ahumado ya está activo: nada que hacer."
    exit 10
fi
log_info "Cristal listo: Ajustes › Apariencia › Cristal cambia entre ahumado, clásico y líquido (si hyprglass está instalado)."
exit 0
