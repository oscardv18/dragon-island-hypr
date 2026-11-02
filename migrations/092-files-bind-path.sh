#!/usr/bin/env bash
# 092 — SUPER+E called `qs ipc call files open` with no path; Quickshell refuses a call with missing arguments, so the
# explorer never opened. The bind now passes '' (= HOME). Copied binds.lua only; a repo link already sees it.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
config="${XDG_CONFIG_HOME:-$HOME/.config}"
dest="$config/hypr/binds.lua"
# Never write through a linked directory or file.
[[ -d "$config/hypr" && ! -L "$config/hypr" && ! -L "$dest" ]] || exit 10
[[ -f "$dest" ]] || exit 10
grep -q "qs ipc call files open\"" "$dest" || exit 10      # only the broken bind; a customised file is left alone
backup_copy "$dest"
run sed -i "s|qs ipc call files open\"|qs ipc call files open ''\"|" "$dest"
log_info "SUPER+E vuelve a abrir Archivos. Recarga Hyprland: hyprctl reload."
