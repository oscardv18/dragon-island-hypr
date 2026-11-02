#!/usr/bin/env bash
# 065 — deploy 5c services/views after their branch is merged, preserving copied configs.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
mapfile -t files < "$REPO_DIR/migrations/065-taller-ui-files.txt"
source_dir="$REPO_DIR/config/quickshell"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
# Tools and screens are delivered separately: never apply a partial/older shell.
for file in "${files[@]}"; do
    if [[ ! -f "$source_dir/$file" ]]; then
        log_warn "5c pendiente: falta $file. Fusiona la rama de pantallas antes de aplicar 065."
        exit 10
    fi
done
for file in "${files[@]}"; do
    src="$source_dir/$file" dest="$target_dir/$file"
    if [[ "$(readlink -f -- "$dest" || true)" == "$(readlink -f -- "$src")" ]]; then
        continue
    fi
    if [[ "$LINK_MODE" == copy && -f "$dest" && ! -L "$dest" ]] && cmp -s -- "$src" "$dest"; then
        continue
    fi
    backup_copy "$dest"
    deploy_item "$src" "$dest"
done
log_info "Interfaz 5c desplegada. Reinicia Quickshell para registrar los tipos nuevos."
