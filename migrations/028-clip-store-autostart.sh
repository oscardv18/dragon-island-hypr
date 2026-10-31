#!/usr/bin/env bash
# 028 — the clipboard watchers go through dragon-clip-store instead of plain `cliphist store` (it keeps the recording
# mode's pause, rejects password hints and records the metadata of the Gravity launcher's clipboard ring).
#   - ~/.config/hypr/autostart.lua when it is a COPY that still has `wl-paste [--type text|image] --watch cliphist store`:
#     only those commands change (→ --watch $HOME/.local/bin/dragon-clip-store), backed up first. A symlink to the repo
#     already has it.
#   - ~/.local/bin/dragon-clip-store is deployed if it is missing (the watchers need it from the next login on).
#   - live session: watchers still running `cliphist store` are restarted with dragon-clip-store (as 022 did).
#   - ~/.config/hypr/local.lua is the user's: never edited, only a warning when it starts its own `cliphist store` watcher.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
AUTOSTART="$CFG/hypr/autostart.lua"
BIN="$HOME/.local/bin"
OLD_RE='wl-paste( --type [a-z]+)? --watch cliphist store'
changed=0

# ---- the watcher itself ----
if [[ ! -x "$BIN/dragon-clip-store" ]]; then
    deploy_item "$REPO_DIR/bin/dragon-clip-store" "$BIN/dragon-clip-store"
    changed=1
fi

# ---- a copied autostart.lua ----
if [[ -f "$AUTOSTART" && ! -L "$AUTOSTART" ]] && grep -qE "$OLD_RE" "$AUTOSTART"; then
    backup_copy "$AUTOSTART"
    if $DRY_RUN; then
        log_info "[dry-run] $AUTOSTART: cambiaría «--watch cliphist store» por «--watch \$HOME/.local/bin/dragon-clip-store» en:"
        grep -nE "$OLD_RE" "$AUTOSTART" | sed 's/^/    /'
    else
        tmp=$(mktemp "$AUTOSTART.XXXXXX")
        # shellcheck disable=SC2016  # $HOME is written literally: autostart.lua runs it through the shell
        sed -E 's#(wl-paste( --type [a-z]+)? --watch) cliphist store#\1 $HOME/.local/bin/dragon-clip-store#g' "$AUTOSTART" > "$tmp"
        cat "$tmp" > "$AUTOSTART"; rm -f "$tmp"
    fi
    log_info "autostart.lua: el historial del portapapeles pasa por dragon-clip-store desde el próximo inicio de sesión."
    changed=1
fi

if [[ -f "$CFG/hypr/local.lua" ]] && grep -qE "$OLD_RE" "$CFG/hypr/local.lua"; then
    log_warn "$CFG/hypr/local.lua arranca su propio «wl-paste --watch cliphist store»: cámbialo por $BIN/dragon-clip-store o el modo grabación no podrá pausar el historial."
fi

# ---- live session: the running watchers ----
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && pgrep -f 'wl-paste --type (text|image) --watch cliphist store' >/dev/null 2>&1; then
    run pkill -f 'wl-paste --type (text|image) --watch cliphist store' || true
    for t in text image; do
        if $DRY_RUN; then echo "[dry-run] setsid -f wl-paste --type $t --watch $BIN/dragon-clip-store"
        else setsid -f wl-paste --type "$t" --watch "$BIN/dragon-clip-store" >/dev/null 2>&1 </dev/null || true; fi
    done
    log_info "Historial del portapapeles: los vigilantes de esta sesión ya pasan por dragon-clip-store."
    changed=1
fi

if [[ $changed -eq 0 ]]; then
    log_info "El portapapeles ya pasa por dragon-clip-store (configuración enlazada o al día): nada que hacer."
    exit 10
fi
exit 0
