#!/usr/bin/env bash
# 016 — session hooks for configured agents and pane history across host restarts.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

herdr_bin="$HOME/.local/bin/herdr"
[[ -x "$herdr_bin" ]] || herdr_bin="$(command -v herdr || true)"
[[ -n "$herdr_bin" ]] || { log_info "herdr no está instalado; se reintentará más adelante."; exit 10; }

deploy_item "$REPO_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
ensure_herdr_integrations || exit 10
if [[ -S "$HOME/.config/herdr/herdr.sock" ]]; then
    run "$herdr_bin" server reload-config
fi
log_info "herdr: reabre o reanuda los agentes existentes para que registren su sesión; no se ha detenido ningún panel."
