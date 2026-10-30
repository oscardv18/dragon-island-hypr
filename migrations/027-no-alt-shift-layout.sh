#!/usr/bin/env bash
# 027 — Alt+Shift no longer switches the keyboard layout: grp:alt_shift_toggle leaves kb_options, because it fired inside
# Alt+Shift+Tab (the orbital switcher's «previous», phase 4). SUPER + ALT + Space stays, now a locked bind (lock screen).
#   - ~/.config/hypr/input.lua when it is a COPY (a symlink to the repo already has the change): the token is removed
#     from its kb_options line, other options are kept.
#   - ~/.config/hypr/local.lua: only inside the installer's own «keyboard» block (modules/keyboard.sh writes it for
#     layouts other than us,latam); the rest of the file is the user's and is never touched.
# Both backed up first. A live Hyprland reloads its config. Idempotent; honours DRY_RUN; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
INPUT="$CFG/hypr/input.lua"
LOCAL="$CFG/hypr/local.lua"
TOKEN="grp:alt_shift_toggle"
changed=0

# kb_options = "a,grp:alt_shift_toggle,b" → "a,b" (only on lines that set kb_options)
strip_token() {
    sed -E "/kb_options/{ s/,$TOKEN//g; s/$TOKEN,?//g; }"
}

if [[ -f "$INPUT" && ! -L "$INPUT" ]] && grep -q "kb_options.*$TOKEN" "$INPUT"; then
    backup_copy "$INPUT"
    if $DRY_RUN; then log_info "[dry-run] quitaría $TOKEN de $INPUT"
    else tmp=$(mktemp "$INPUT.XXXXXX"); strip_token < "$INPUT" > "$tmp"; cat "$tmp" > "$INPUT"; rm -f "$tmp"; fi
    log_info "input.lua: Alt+Shift ya no cambia de distribución (queda SUPER + ALT + Space)."
    changed=1
fi

begin="-- >>> dragon-island:keyboard"; end="-- <<< dragon-island:keyboard"
if [[ -f "$LOCAL" ]] && awk -v b="$begin" -v e="$end" -v t="$TOKEN" '$0 == b { in_ = 1; next } $0 == e { in_ = 0 } in_ && index($0, t) { found = 1 } END { exit !found }' "$LOCAL"; then
    backup_copy "$LOCAL"
    if $DRY_RUN; then log_info "[dry-run] quitaría $TOKEN del bloque «keyboard» de $LOCAL"
    else
        tmp=$(mktemp "$LOCAL.XXXXXX")
        awk -v b="$begin" -v e="$end" -v t="$TOKEN" '
            $0 == b { in_ = 1; print; next }
            $0 == e { in_ = 0 }
            in_ { gsub("," t, ""); gsub(t ",?", "") }
            { print }' "$LOCAL" > "$tmp"
        cat "$tmp" > "$LOCAL"; rm -f "$tmp"
    fi
    log_info "local.lua: quitado $TOKEN del bloque de teclado del instalador."
    changed=1
fi

if [[ $changed -eq 0 ]]; then
    log_info "Alt+Shift ya no cambia de distribución aquí: nada que hacer."
    exit 10
fi
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    run hyprctl reload >/dev/null || true
fi
log_info "Cambiar de distribución: SUPER + ALT + Space (también en la pantalla de bloqueo) o la cápsula US / LA de la barra."
exit 0
