#!/usr/bin/env bash
# 101 — Dragon Portal: the explorer's selector mode and the FilePicker service, for copied installs (a repo link already sees them).
# No session commands: restart Quickshell afterwards to load the new types.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
mapfile -t files < "$REPO_DIR/migrations/101-portal-ui-files.txt"
source_dir="$REPO_DIR/config/quickshell"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
[[ -d "$target_dir" ]] || exit 10
# Never apply a partial shell: every listed file must exist.
for file in "${files[@]}"; do
    if [[ ! -f "$source_dir/$file" ]]; then
        log_warn "Falta $file en el repositorio. Actualiza antes de aplicar 101."
        exit 10
    fi
done
changed=0
for file in "${files[@]}"; do
    src="$source_dir/$file" dest="$target_dir/$file" parent="$target_dir/$file"
    # Never write through a linked config or subdirectory (repo links are already current).
    skip=false
    while [[ "$parent" != "$target_dir" && "$parent" != / ]]; do
        [[ -L "$parent" ]] && skip=true
        parent="$(dirname "$parent")"
    done
    [[ -L "$target_dir" ]] && skip=true
    $skip && continue
    [[ -f "$dest" ]] && cmp -s -- "$src" "$dest" && continue
    backup_copy "$dest"
    run mkdir -p "$(dirname "$dest")"
    run cp -a -- "$src" "$dest"
    changed=1
done
if ((changed == 0)); then exit 10; fi
log_info "Modo selector del explorador desplegado. Reinicia Quickshell para cargarlo."
