#!/usr/bin/env bash
# 002 — import the user's zsh (oh-my-zsh + autosuggestions + syntax-highlighting) and starship config.
# ~/.zshrc and ~/.config/starship.toml are backed up (deploy_item) and replaced by links to
# config/zsh/.zshrc and config/starship/starship.toml. Private bits belong in ~/.zshrc.local.
# Optional: applied when the "zsh" component is installed, or when you confirm. Exit 10 = skipped.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

SRC_ZSHRC="$REPO_DIR/config/zsh/.zshrc"
SRC_STARSHIP="$REPO_DIR/config/starship/starship.toml"
DEST_ZSHRC="$HOME/.zshrc"
DEST_STARSHIP="$HOME/.config/starship.toml"

linked() { [[ -L "$1" && "$(readlink -f "$1")" == "$(readlink -f "$2")" ]]; }

if linked "$DEST_ZSHRC" "$SRC_ZSHRC" && linked "$DEST_STARSHIP" "$SRC_STARSHIP"; then
    log_info "zsh y starship ya apuntan al repo."
    add_component zsh
    exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
    log_info "zsh no está instalado: se omite (instálalo con ./install.sh --zsh)."
    exit 10
fi

if { [[ -f "$COMPONENTS_FILE" ]] && grep -qxF zsh "$COMPONENTS_FILE"; }; then
    :
elif ! confirm "Se detectó zsh. ¿Importar la configuración de zsh y starship del repo (con copia de seguridad de la tuya)?"; then
    log_info "Omitida."
    exit 10
fi

# Secrets must not travel to a public repo: warn when the current files look like they hold some
if [[ -f "$DEST_ZSHRC" ]] && ! linked "$DEST_ZSHRC" "$SRC_ZSHRC"; then
    if grep -nEi '(token|secret|passw(or)?d|api[_-]?key|BEGIN [A-Z ]*PRIVATE KEY)' "$DEST_ZSHRC" >/dev/null 2>&1; then
        log_warn "$DEST_ZSHRC contiene líneas que parecen secretos. Muévelas a ~/.zshrc.local y vuelve a ejecutar."
        exit 10
    fi
    if ! cmp -s "$DEST_ZSHRC" "$SRC_ZSHRC"; then
        log_warn "Tu ~/.zshrc difiere del del repo (queda en el backup). Cualquier extra tuyo va a ~/.zshrc.local."
    fi
fi

ensure_omz
deploy_item "$SRC_ZSHRC" "$DEST_ZSHRC"
deploy_item "$SRC_STARSHIP" "$DEST_STARSHIP"
add_component zsh

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    if confirm "Tu shell por defecto no es zsh. ¿Cambiarla con chsh -s /usr/bin/zsh? (pide tu contraseña)"; then
        run chsh -s /usr/bin/zsh || log_warn "chsh falló: ejecútalo a mano."
        need_relogin "Nueva shell por defecto (zsh)"
    fi
fi

log_info "zsh + starship importados. Abre una terminal nueva para verlos."
exit 0
