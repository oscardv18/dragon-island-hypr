#!/usr/bin/env bash
# 191 — zsh de Dragon en CachyOS (y en cualquier sistema con oh-my-zsh de root):
#   · fzf-tab se clona en una carpeta escribible (lib/zsh-setup.sh: nunca en /usr/share/oh-my-zsh, donde el clon fallaba
#     con «Permiso denegado» y no se cargaba ningún plugin). zsh-autosuggestions y zsh-syntax-highlighting pasan a ser
#     paquetes de extra (packages/pacman-shell.txt): los instala el paso de paquetes de update.sh, justo después.
#   · ~/.config/starship.toml: si no es el de Dragon, se guarda en las copias de seguridad y se pone el de Dragon
#     (luego dragon-palette le aplica el acento).
#   · El prompt (desactivar Powerlevel10k) y el aviso de plugins viven en config/zsh/dragon.zsh: con enlaces llegan solos;
#     en modo copia los sincroniza el paso de configuración de update.sh.
# Idempotente: lo que ya está bien solo se registra. deploy_item hace la copia de seguridad. Respeta DRY_RUN.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/zsh-setup.sh
. "$REPO_DIR/lib/zsh-setup.sh"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
# el módulo shell nunca se aplicó aquí
[[ -e "$CFG/dragon-island/zsh" || -L "$CFG/dragon-island/zsh" ]] || exit 10

rc=0
zsh_ensure_fzf_tab || rc=1

dest="$(starship_config_path)"
if [[ -e "$dest" ]] && starship_is_dragon "$dest"; then
    log_info "starship.toml ya es el de Dragon: $dest"
else
    zsh_starship_deploy
    # shellcheck source=lib/palette.sh
    . "$REPO_DIR/lib/palette.sh"
    palette_setup || log_warn "dragon-palette no pudo aplicar el acento a $dest (se queda con los colores de Dragon)."
fi
exit "$rc"
