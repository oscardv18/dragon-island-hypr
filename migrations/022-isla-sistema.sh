#!/usr/bin/env bash
# 022 — phase 2: the island as the system's status centre (captures, recording mode, focus, drop-down terminal, idle
# sequence, long commands, lock screen).
#   - ~/.config/dragon-island/settings.json gets ONLY the keys it is missing (the user's values are never touched)
#   - ~/.local/bin: dragon-dropdown (SUPER + grave), dragon-idle (idle sequence → hypridle), dragon-clip-store (the
#     clipboard writer the recording mode pauses); ~/.config/ghostty/dropdown for copied Ghostty configs
#   - copied zsh configs get commands.zsh (long-command hooks) + the new dragon.zsh; open shells only see it after a
#     restart: this warns, it never runs `exec zsh`
#   - live session: hypridle restarted with the generated config (it only reads it at start); the wl-paste watchers
#     restarted with dragon-clip-store
#   - optional, only with an explicit interactive yes: satty (Anotar), tesseract + Spanish / English data (Texto)
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
NO_SUDO="${NO_SUDO:-false}"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SETTINGS="$CFG/dragon-island/settings.json"
BIN="$HOME/.local/bin"
DEFAULTS='{"longCommandSeconds":30,"recordingMode":"auto","recordHold":true,"recordHideTitles":true,"recordPauseClipboard":true,"recordFrame":true,"focusMuteApps":["Telegram"],"idleDimSeconds":240,"idleLockSeconds":300,"idleScreenOffSeconds":330,"idleSuspendSeconds":1200,"idleInhibitAgents":true}'

changed=0
same() { [[ -e $2 && "$(readlink -f "$2")" == "$(readlink -f "$1")" ]] || { [[ "$LINK_MODE" == copy && -f $2 ]] && cmp -s "$1" "$2"; }; }

# ---- settings.json: the missing keys only ----
if command -v jq >/dev/null 2>&1; then
    if [[ ! -e "$SETTINGS" ]]; then
        run mkdir -p "$(dirname "$SETTINGS")"
        if $DRY_RUN; then log_info "[dry-run] crearía $SETTINGS"; else jq . <<<"$DEFAULTS" > "$SETTINGS"; fi
        log_info "Creado $SETTINGS con los ajustes de la fase 2."
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
else
    log_warn "Falta jq: los ajustes nuevos usarán sus valores por defecto hasta que se instale."
fi

# ---- scripts in ~/.local/bin ----
for s in dragon-dropdown dragon-idle dragon-clip-store; do
    same "$REPO_DIR/bin/$s" "$BIN/$s" && continue
    deploy_item "$REPO_DIR/bin/$s" "$BIN/$s"
    changed=1
done

# ---- Ghostty config of the drop-down terminal (only for a copied ~/.config/ghostty) ----
if [[ -d "$CFG/ghostty" && "$(readlink -f "$CFG/ghostty")" != "$(readlink -f "$REPO_DIR/config/ghostty")" ]] \
   && ! same "$REPO_DIR/config/ghostty/dropdown" "$CFG/ghostty/dropdown"; then
    deploy_item "$REPO_DIR/config/ghostty/dropdown" "$CFG/ghostty/dropdown"
    changed=1
fi

# ---- zsh hooks for long commands (only for a copied ~/.config/dragon-island/zsh) ----
ZDIR="$CFG/dragon-island/zsh"
if [[ -d "$ZDIR" && "$(readlink -f "$ZDIR")" != "$(readlink -f "$REPO_DIR/config/zsh")" ]]; then
    for f in commands.zsh dragon.zsh; do
        same "$REPO_DIR/config/zsh/$f" "$ZDIR/$f" && continue
        deploy_item "$REPO_DIR/config/zsh/$f" "$ZDIR/$f"
        changed=1
    done
fi
[[ -d "$ZDIR" ]] && log_info "Los avisos de comandos largos llegan a las terminales que abras desde ahora (o tras «exec zsh» en las abiertas)."

# ---- live session: hypridle with the generated config, clipboard watchers with dragon-clip-store ----
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    if pgrep -x hypridle >/dev/null 2>&1 && ! pgrep -af hypridle | grep -q "dragon-island/hypridle.conf"; then
        run "$BIN/dragon-idle" restart
        log_info "hypridle reiniciado con la secuencia de inactividad nueva."
        changed=1
    fi
    if pgrep -f 'wl-paste --type (text|image) --watch cliphist store' >/dev/null 2>&1; then
        run pkill -f 'wl-paste --type (text|image) --watch cliphist store' || true
        for t in text image; do
            if $DRY_RUN; then echo "[dry-run] setsid -f wl-paste --type $t --watch $BIN/dragon-clip-store"
            else setsid -f wl-paste --type "$t" --watch "$BIN/dragon-clip-store" >/dev/null 2>&1 </dev/null || true; fi
        done
        log_info "Historial del portapapeles: ahora pasa por dragon-clip-store (el modo grabación puede pausarlo)."
        changed=1
    fi
fi

# ---- optional tools for the capture bar: only with an explicit interactive yes ----
opt=()
command -v satty >/dev/null 2>&1 || command -v swappy >/dev/null 2>&1 || opt+=(satty)
if ! command -v tesseract >/dev/null 2>&1; then opt+=(tesseract tesseract-data-spa tesseract-data-eng)
else
    tesseract --list-langs 2>/dev/null | grep -qx spa || opt+=(tesseract-data-spa)
    tesseract --list-langs 2>/dev/null | grep -qx eng || opt+=(tesseract-data-eng)
fi
if [[ ${#opt[@]} -gt 0 ]]; then
    if $ASSUME_YES || $DRY_RUN; then
        log_info "Opcional para la barra de capturas (Anotar / Texto): sudo pacman -S --needed ${opt[*]}"
    elif confirm "¿Instalar ${opt[*]} para Anotar y Texto en las capturas? (opcional, pide sudo)"; then
        ensure_pacman "${opt[@]}" || true
    fi
fi

if [[ $changed -eq 0 ]]; then
    log_info "La fase 2 ya está aplicada: nada que hacer."
    exit 10
fi
log_info "Fase 2 lista: SUPER + SHIFT + S capturas · SUPER + \` terminal desplegable · SUPER + ALT + A agentes · SUPER + ALT + F enfoque."
exit 0
