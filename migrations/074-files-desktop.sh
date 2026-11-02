#!/usr/bin/env bash
# 074 — desktop entry and reversible default association; optional FileManager1 stays opt-in.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/files-tools.sh
. "$REPO_DIR/lib/files-tools.sh"
files_tools_setup
if confirm "¿Usar Archivos Dragon para inode/directory? Se guarda el gestor anterior; afecta también a Plasma."; then
    run "$HOME/.local/bin/dragon-files" --set-default
fi
log_info "Restaurar: dragon-files --restore-default. FileManager1 opcional: dragon-files --filemanager1."
