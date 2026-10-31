#!/usr/bin/env bash
# 035 — pulido: what a symlink does not carry to an installed system.
#   * ~/.local/bin/dragon-dropdown gains `--type TEXT` (the isla de mando's IA mode types `claude "<query>"` into the
#     drop-down terminal). A COPIED script is redeployed (backup first); a link to the repo already has it.
#   * The HUD panels use two optional tools when present: qrencode (share the Wi‑Fi as a QR code) and cava (the real
#     audio wave of the isla de mando). They are in the optional extras section «paneles» (packages/extras.txt); this
#     migration only says which are missing and how to add them — it never installs packages on its own.
#   * config/hypr (glassstyle.lua, look / rules / glass) reaches copied configs through update.sh's normal sync.
# Idempotent; honours DRY_RUN and ASSUME_YES; exits 10 when there is nothing to do.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

BIN="$HOME/.local/bin"
changed=0

same() { [[ -e "$2" ]] && { [[ "$(readlink -f "$1")" == "$(readlink -f "$2")" ]] || cmp -s "$1" "$2"; }; }

# ---- dragon-dropdown --type ----
if [[ -e "$BIN/dragon-dropdown" ]] && ! same "$REPO_DIR/bin/dragon-dropdown" "$BIN/dragon-dropdown"; then
    deploy_item "$REPO_DIR/bin/dragon-dropdown" "$BIN/dragon-dropdown"
    log_info "dragon-dropdown actualizado: la línea de mando de la isla puede preguntar a Claude en la terminal desplegable."
    changed=1
fi

# ---- optional tools of the panels ----
missing=()
for t in qrencode cava; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Opcional para los paneles: falta ${missing[*]} (QR del Wi‑Fi / onda real de la música)."
    log_info "  Añádelos con el módulo extras («paneles») o: sudo pacman -S ${missing[*]}"
fi

if [[ $changed -eq 0 ]]; then
    log_info "Nada que actualizar para el pulido fuera del repo."
    exit 10
fi
exit 0
