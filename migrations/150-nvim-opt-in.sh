#!/usr/bin/env bash
# 150 — Adopt the user's Neovim only with explicit opt-in, never merely because update.sh uses --yes.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/editor.sh
. "$REPO_DIR/lib/editor.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

src="$REPO_DIR/config/nvim"
dest="$(nvim_config_dir)"
[[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && exit 10
opt_in="$(bool_flag "${DRAGON_NVIM:-false}")"
if ! $opt_in && { $ASSUME_YES || [[ ! -t 0 || ! -t 1 ]] || ! has_gum; }; then
    log_info 'Neovim conservado. Para comparar y adoptar con respaldo: DRAGON_NVIM=1 bash migrations/150-nvim-opt-in.sh'
    exit 10
fi

python3 "$REPO_DIR/scripts/check-nvim-public.py" "$src"
if [[ -d "$dest" ]]; then
    log_info 'Comparación de Neovim (solo nombres de archivos; no se muestra su contenido):'
    if differences="$(diff -rq -- "$dest" "$src")"; then
        log_info 'Las carpetas son idénticas: se puede guardar respaldo y sustituir por el enlace.'
    else
        code=$?
        [[ $code -eq 1 ]] || { log_warn 'No se pudo completar la comparación; no se cambia Neovim.'; exit 1; }
        printf '%s\n' "$differences"
    fi
elif [[ -e "$dest" || -L "$dest" ]]; then
    log_info 'El destino Neovim existe pero no es una carpeta; se respaldará antes del enlace.'
else
    log_info 'No hay configuración Neovim previa: se creará el enlace.'
fi
if ! $opt_in; then
    confirm '¿Adoptar la configuración del repo en Neovim, respaldando lo anterior y creando un enlace?' || exit 10
fi
# This migration explicitly offers a link. The installer's --copy remains available for fresh installs.
LINK_MODE=symlink
nvim_deploy
modules_file="$STATE_DIR/modules"
if [[ -f "$modules_file" ]] && ! grep -qxF editor "$modules_file"; then
    if $DRY_RUN; then log_info '[dry-run] Añadir editor a los módulos instalados.'
    else printf 'editor\n' >> "$modules_file"; fi
fi
log_info 'Neovim adoptado con consentimiento. Los plugins se restauran al primer uso, con otra confirmación.'
