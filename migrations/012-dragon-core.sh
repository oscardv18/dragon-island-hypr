#!/usr/bin/env bash
# 012 — dragon-core: Quickshell lock screen (replaces hyprlock, which stays as fallback) + optional SDDM login theme.
# The Quickshell files, the binds (SUPER + L), hypridle's lock_cmd and the retheme of hyprlock arrive with the repo
# (config/quickshell and config/hypr are linked). This migration: syncs the shared neural core, makes the running
# session pick the changes up, and OFFERS the login theme (sudo, interactive: never run without an explicit yes).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

# 1. one source for NeuralCore/CoreIcon → Quickshell components + SDDM theme
if $DRY_RUN; then
    "$REPO_DIR/scripts/sync-shared.sh" --check || log_warn "NeuralCore/CoreIcon desincronizados (se copiarían)."
else
    "$REPO_DIR/scripts/sync-shared.sh"
fi

# 2. the Quickshell files must be where the shell reads them (symlinked dirs already are; copy mode: update.sh syncs them)
for t in quickshell hypr; do
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/$t"
    [[ -e "$dest" ]] || deploy_item "$REPO_DIR/config/$t" "$dest"
done

# 3. live session: Quickshell hot-reloads on its own; hypridle only reads lock_cmd at start
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && pgrep -x hypridle >/dev/null 2>&1; then
    run pkill -x hypridle || true
    if $DRY_RUN; then echo "[dry-run] setsid -f hypridle"; else setsid -f hypridle >/dev/null 2>&1 </dev/null || true; fi
fi
if command -v qs >/dev/null 2>&1 && qs list >/dev/null 2>&1; then
    log_info "Quickshell recarga solo los módulos nuevos; si algo no aparece: qs kill; qs -d"
fi

# 4. optional login theme (sudo). Only with a real terminal AND an explicit "yes": --yes / no-gum never installs it.
if $DRY_RUN; then
    echo "[dry-run] (opcional, pide sudo) $REPO_DIR/sddm/install-theme.sh"
    exit 0
fi
if $ASSUME_YES || ! has_gum || [[ ! -t 0 ]]; then
    log_info "Tema de login dragon-core: no se instala sin confirmación interactiva. Cuando quieras: $REPO_DIR/sddm/install-theme.sh"
    exit 0
fi
if gum confirm --affirmative "Sí" --negative "No" "¿Instalar el tema de login dragon-core? (pide sudo)"; then
    "$REPO_DIR/sddm/install-theme.sh" || { log_warn "install-theme.sh no terminó; reintenta a mano: $REPO_DIR/sddm/install-theme.sh"; exit 0; }
else
    log_info "Omitido. Cuando quieras: $REPO_DIR/sddm/install-theme.sh   (probar sin sudo: --test)"
fi
exit 0
