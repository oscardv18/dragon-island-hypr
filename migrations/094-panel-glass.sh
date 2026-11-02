#!/usr/bin/env bash
# 094 — Restore themed glass on Taller and Files main surfaces.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
mapfile -t files < "$REPO_DIR/migrations/094-panel-glass-files.txt"
source_dir="$REPO_DIR/config/quickshell"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
# Never apply a partial shell: every listed file must exist.
for file in "${files[@]}"; do
    if [[ ! -f "$source_dir/$file" ]]; then
        log_warn "Taller pendiente: falta $file. Actualiza el repositorio antes de aplicar 094."
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
log_info "Cristal del Taller y del explorador actualizado."
