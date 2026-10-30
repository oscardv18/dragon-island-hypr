#!/usr/bin/env bash
# 020 — new identity (phase 0 + 1): the settings of the four bar styles and the Ajustes panel.
#   - ~/.config/dragon-island/settings.json gets ONLY the keys it is missing (barStyle, barSize, islandContent, barMetrics,
#     barAutohide, accentIntensity, wallpaperPalette), with their defaults; the user's values are never touched.
#     Quickshell already falls back to the same defaults without them: this only makes them visible and editable.
#   - A *copied* ~/.config/quickshell loses modules/bar/WorkspacePill.qml (replaced by Constellation.qml);
#     symlinked installs see the repo directly. update.sh never deletes files; this does, with a backup.
# Everything else (QML, binds, glass / blur rules) lives in the repo and arrives with update.sh.
# Exit 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/settings.json"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
STALE=(modules/bar/WorkspacePill.qml)
DEFAULTS='{"barStyle":"B","barSize":"normal","islandContent":"media","barMetrics":true,"barAutohide":false,"accentIntensity":0.3,"wallpaperPalette":true}'

changed=0

# ---- settings.json: add the missing keys only ----
if ! command -v jq >/dev/null 2>&1; then
    log_warn "Falta jq (paquete del módulo core): no se puede completar $SETTINGS. Se reintentará."
    exit 10
fi

if [[ ! -e "$SETTINGS" ]]; then
    run mkdir -p "$(dirname "$SETTINGS")"
    if $DRY_RUN; then
        log_info "[dry-run] crearía $SETTINGS con: $DEFAULTS"
    else
        jq . <<<"$DEFAULTS" > "$SETTINGS"
    fi
    log_info "Creado $SETTINGS con los ajustes de la barra por defecto."
    changed=1
elif ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
    log_warn "$SETTINGS no es un objeto JSON válido: no se toca (Quickshell usa los valores por defecto). Arréglalo y vuelve a ejecutar update.sh."
    exit 10
else
    absent_keys=$(jq -r --argjson d "$DEFAULTS" '[$d | keys[]] - keys | join(" ")' "$SETTINGS")
    if [[ -n "$absent_keys" ]]; then
        backup_copy "$SETTINGS"
        if $DRY_RUN; then
            log_info "[dry-run] añadiría a $SETTINGS: $absent_keys"
        else
            tmp=$(mktemp "${SETTINGS}.XXXXXX")
            # defaults first, the user's object on top: existing keys always win
            jq --argjson d "$DEFAULTS" '$d + .' "$SETTINGS" > "$tmp"
            mv -f -- "$tmp" "$SETTINGS"
        fi
        log_info "Ajustes añadidos a $SETTINGS: $absent_keys"
        changed=1
    fi
fi

# ---- copied Quickshell config: remove the replaced QML ----
if [[ -d "$QS_DIR" && "$(readlink -f "$QS_DIR")" != "$(readlink -f "$REPO_DIR/config/quickshell")" ]]; then
    for f in "${STALE[@]}"; do
        [[ -e "$QS_DIR/$f" && ! -e "$REPO_DIR/config/quickshell/$f" ]] || continue
        backup_copy "$QS_DIR/$f"
        run rm -f -- "$QS_DIR/$f"
        log_info "Eliminado $QS_DIR/$f (sustituido por la constelación de escritorios)."
        changed=1
    done
fi

if [[ $changed -eq 0 ]]; then
    log_info "settings.json ya tiene todos los ajustes de la nueva identidad: nada que hacer."
    exit 10
fi
log_info "Nueva identidad lista: SUPER + F2 abre Ajustes, SUPER + ALT + B cambia el estilo de la barra."
exit 0
