#!/usr/bin/env bash
# 017 — deploy the compact directory prompt for existing zsh installations.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

if [[ ! -f "$COMPONENTS_FILE" ]] || ! grep -qxF zsh "$COMPONENTS_FILE"; then
    if [[ "$(readlink -f "$HOME/.zshrc")" != "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; then
        log_info "Starship de dragon-island no está instalado: se omite."
        exit 10
    fi
fi

deploy_item "$REPO_DIR/config/starship/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
log_info "Starship muestra solo el nombre del directorio actual."
