#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables shared with the scripts that source this file
# =============================================================================
# dragon-island — shared helpers for install.sh, update.sh and migrations/*.sh
# Sourced, never executed. The caller defines: DRY_RUN, ASSUME_YES, LINK_MODE, LOG, STATE_DIR,
# BACKUP_DIR, MANIFEST (lines: <action>\t<target>\t<backup-or-source>).
# =============================================================================

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
run() {
    if $DRY_RUN; then
        printf '[dry-run]'; printf ' %q' "$@"
        echo
    else
        "$@"
    fi
}

has_gum() { command -v gum >/dev/null 2>&1; }

log_info() { if has_gum; then gum log --level info "$1"; else echo ":: $1"; fi; }
log_warn() { if has_gum; then gum log --level warn "$1"; else echo ":: AVISO: $1"; fi; }

# box <border-color> <line>...   (plain text fallback when gum is missing, e.g. in --dry-run)
box() {
    local color="$1"; shift
    if has_gum; then
        gum style --border rounded --border-foreground "$color" --padding "1 2" --foreground "#e6e8ef" "$@"
    else
        printf '%s\n' "------------------------------------------------------------" "$@" \
            "------------------------------------------------------------"
    fi
}

# confirm <question>  → 0 = yes. In --yes mode (or without gum) always yes.
confirm() {
    if $ASSUME_YES || ! has_gum; then return 0; fi
    gum confirm --affirmative "Sí" --negative "No" "$1"
}

# read_packages <file> <component>...  → prints the packages of the selected sections
read_packages() {
    local file="$1"; shift
    [[ -f "$file" ]] || return 0
    awk -v sel=" $* " '
        /^[[:space:]]*(#|$)/ { next }
        /^@/ { section = substr($1, 2); next }
        index(sel, " " section " ") { print $1 }
    ' "$file"
}

deploy_item() {
    local src="$1" dest="$2" rel_path

    # Already a symlink to our repo → nothing to do
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Ya enlazado: $dest"
        return 0
    fi
    # Copy mode and identical content → nothing to do
    if [[ "$LINK_MODE" == "copy" && -e "$dest" && ! -L "$dest" ]] && diff -rq -- "$src" "$dest" >/dev/null 2>&1; then
        log_info "Ya copiado y sin cambios: $dest"
        return 0
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        rel_path="${dest#"$HOME"/}"
        run mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
        run mv -- "$dest" "$BACKUP_DIR/$rel_path"
        $DRY_RUN || printf 'backup\t%s\t%s\n' "$dest" "$BACKUP_DIR/$rel_path" >> "$MANIFEST"
        log_info "Respaldo: $dest -> $BACKUP_DIR/$rel_path"
    fi

    run mkdir -p "$(dirname "$dest")"
    if [[ "$LINK_MODE" == "symlink" ]]; then
        run ln -sfn -- "$src" "$dest"
    else
        run cp -a -- "$src" "$dest"
    fi
    $DRY_RUN || printf 'deploy\t%s\t%s\n' "$dest" "$src" >> "$MANIFEST"
    log_info "Desplegado ($LINK_MODE): $dest"
}


# read_plain_list <file>  → one package per line (comments / blank lines skipped): "Mis apps" lists of the Tienda
read_plain_list() {
    [[ -f "$1" ]] || return 0
    awk '/^[[:space:]]*(#|$)/ { next } { print $1 }' "$1"
}

# ensure_herdr: herdr (agents multiplexer). Not in the repos or the AUR, so the official installer is used
# (no root, installs to ~/.local/bin/herdr). It updates itself afterwards with `herdr update`.
ensure_herdr() {
    if [[ -x "$HOME/.local/bin/herdr" ]] || command -v herdr >/dev/null 2>&1; then
        log_info "herdr ya está instalado ($("$HOME/.local/bin/herdr" --version 2>/dev/null || herdr --version 2>/dev/null)); se actualiza con: herdr update"
        return 0
    fi
    confirm "herdr (multiplexor de agentes) no está instalado. ¿Instalarlo con el script oficial (sin root)?" || return 1
    if [[ "${DRY_RUN:-false}" == "true" ]]; then log_info "[dry-run] curl -fsSL https://herdr.dev/install.sh | sh"; return 0; fi
    curl -fsSL https://herdr.dev/install.sh | sh || { log_warn "No se pudo instalar herdr (¿sin red?)"; return 1; }
}

# deploy_herdr: config + launcher + zsh completion
deploy_herdr() {
    deploy_item "$REPO_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    deploy_item "$REPO_DIR/bin/dragon-herdr" "$HOME/.local/bin/dragon-herdr"
    if [[ -x "$HOME/.local/bin/herdr" ]]; then
        run mkdir -p "$HOME/.zfunc"
        [[ "${DRY_RUN:-false}" == "true" ]] || "$HOME/.local/bin/herdr" completion zsh >| "$HOME/.zfunc/_herdr" 2>/dev/null || true
    fi
}

# ensure_omz: oh-my-zsh and the external plugins (zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab) used by config/zsh/.zshrc (git clones, as in the
# original setup: they are not pacman packages). Existing clones are left alone.
ensure_omz() {
    local zsh_dir="${ZSH:-$HOME/.oh-my-zsh}" custom
    custom="${ZSH_CUSTOM:-$zsh_dir/custom}"
    if [[ ! -d "$zsh_dir" ]]; then
        log_info "Clonando oh-my-zsh en $zsh_dir"
        run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
    fi
    local name
    local repo
    for name in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
        repo="zsh-users/$name"
        [[ "$name" == fzf-tab ]] && repo="Aloxaf/fzf-tab"
        if [[ ! -d "$custom/plugins/$name" ]]; then
            log_info "Clonando el plugin $name"
            run git clone --depth 1 "https://github.com/$repo.git" "$custom/plugins/$name"
        fi
    done
}

# backup_copy <path>: copy (not move) a file or directory into BACKUP_DIR, keeping its path under $HOME.
backup_copy() {
    local target="$1" rel
    [[ -e "$target" || -L "$target" ]] || return 0
    rel="${target#"$HOME"/}"
    run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    run cp -a -- "$target" "$BACKUP_DIR/$rel"
    log_info "Respaldo: $target -> $BACKUP_DIR/$rel"
}

# need_relogin <reason>: update.sh lists these at the end ("log out and back in")
need_relogin() {
    if ! $DRY_RUN; then printf '%s\n' "$1" >> "${RELOGIN_FILE:-$STATE_DIR/needs-relogin}"; fi
}

# add_component <name>: remember a component in the state file (read by update.sh)
add_component() {
    local file="${COMPONENTS_FILE:-$STATE_DIR/components}"
    # no file yet = update.sh infers the components from the manifest, which deploy_item keeps up to date
    [[ -f "$file" ]] || return 0
    $DRY_RUN && return 0
    grep -qxF "$1" "$file" || printf '%s\n' "$1" >> "$file"
}

# apply_icon_theme: GTK apps in every session read this dconf key (settings.ini covers the rest)
ICON_THEME="Sweet-Purple"
apply_icon_theme() {
    if ! command -v gsettings >/dev/null 2>&1; then
        log_warn "gsettings no está instalado: solo se usa settings.ini para el tema de iconos GTK."
        return 0
    fi
    run gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" || log_warn "gsettings no pudo fijar el tema de iconos."
}

# =============================================================================
# Added with the modular installer (modules/*.sh). Everything honours DRY_RUN / ASSUME_YES / NO_SUDO.
# =============================================================================
NO_SUDO="${NO_SUDO:-false}"
AUR_HELPER="${AUR_HELPER:-}"
PRE_DOC="pre-instalation.md"

die() { echo "ERROR: $*" >&2; exit 1; }

# pkg_list <file>...  → package names (comments, blank lines and @sections skipped)
pkg_list() {
    local f
    for f in "$@"; do
        [[ -f "$f" ]] || continue
        awk '/^[[:space:]]*(#|$|@)/ { next } { print $1 }' "$f"
    done
}

# extras_pkgs <section> <pacman|aur>  → packages of one section of packages/extras.txt
extras_pkgs() {
    awk -v sec="$1" -v src="$2" '
        /^[[:space:]]*(#|$)/ { next }
        /^@/ { cur = substr($1, 2); next }
        cur == sec { split($1, a, ":"); if (a[1] == src) print a[2] }
    ' "$REPO_DIR/packages/extras.txt"
}

pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# confirm_sudo <why> <command>...  explains the step, asks (unless --yes), then runs it with sudo.
# Returns 1 when sudo is disabled (--no-sudo) or the user said no: callers print the manual command.
confirm_sudo() {
    local why="$1"; shift
    if $NO_SUDO; then
        log_warn "Sin sudo (--no-sudo): omitido. Hazlo a mano: sudo $*"
        return 1
    fi
    log_info "[sudo] $why"
    confirm "¿Ejecutar con sudo?  sudo $*" || { log_warn "Omitido por ti. Para hacerlo luego: sudo $*"; return 1; }
    run sudo "$@"
}

# ensure_pacman <pkg>...  installs the ones that are missing (one sudo step, never -y)
ensure_pacman() {
    local missing=() p
    for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
    if [[ ${#missing[@]} -eq 0 ]]; then log_info "Paquetes oficiales: todo instalado ($#)."; return 0; fi
    confirm_sudo "Instalar ${#missing[@]} paquetes oficiales: ${missing[*]}" pacman -S --needed --noconfirm "${missing[@]}"
}

# ensure_aur <pkg>...  AUR helper in the foreground (it asks its own questions); needs AUR_HELPER
ensure_aur() {
    local missing=() p
    for p in "$@"; do pkg_installed "$p" || missing+=("$p"); done
    if [[ ${#missing[@]} -eq 0 ]]; then log_info "Paquetes AUR: todo instalado ($#)."; return 0; fi
    if [[ -z "$AUR_HELPER" ]]; then
        log_warn "Sin yay/paru: instala a mano ${missing[*]} (ver $PRE_DOC, Paso 3)."
        return 1
    fi
    log_info "AUR ($AUR_HELPER): ${missing[*]}"
    confirm "¿Instalar con $AUR_HELPER? (compila en esta terminal y puede pedir sudo)" || return 1
    run "$AUR_HELPER" -S --needed --noconfirm "${missing[@]}"
}

# marker_set <file> <name> <comment-prefix> <content>
#   Idempotent block between "<prefix> >>> dragon-island:<name>" and "<prefix> <<< dragon-island:<name>".
#   Replaces the block if it exists, appends it otherwise; the file is backed up first. Never touches other lines.
marker_set() {
    local file="$1" name="$2" pre="$3" content="$4" begin end tmp
    begin="$pre >>> dragon-island:$name"; end="$pre <<< dragon-island:$name"
    if [[ -f "$file" ]] && grep -qxF "$begin" "$file" && [[ "$(marker_get "$file" "$name" "$pre")" == "$content" ]]; then
        log_info "Ya está al día: $name en $file"
        return 0
    fi
    if $DRY_RUN; then echo "[dry-run] $file: bloque «$name»: $content"; return 0; fi
    backup_copy "$file"
    mkdir -p "$(dirname "$file")"
    tmp="$(mktemp)"
    [[ -f "$file" ]] && awk -v b="$begin" -v e="$end" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$file" > "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >> "$tmp"
    cat "$tmp" > "$file"; rm -f "$tmp"
    printf 'marker\t%s\t%s\n' "$file" "$name" >> "$MANIFEST"
    log_info "Bloque «$name» escrito en $file"
}

marker_get() {  # marker_get <file> <name> <prefix> → block content
    awk -v b="$3 >>> dragon-island:$2" -v e="$3 <<< dragon-island:$2" '$0 == b { on = 1; next } $0 == e { on = 0 } on' "$1" 2>/dev/null
}

marker_unset() {  # marker_unset <file> <name> <prefix>
    local file="$1" name="$2" pre="$3"
    [[ -f "$file" ]] && grep -qxF "$pre >>> dragon-island:$name" "$file" || return 0
    if $DRY_RUN; then echo "[dry-run] $file: quitar el bloque «$name»"; return 0; fi
    local tmp; tmp="$(mktemp)"
    awk -v b="$pre >>> dragon-island:$name" -v e="$pre <<< dragon-island:$name" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$file" > "$tmp"
    cat "$tmp" > "$file"; rm -f "$tmp"
    log_info "Bloque «$name» quitado de $file"
}

# undeploy <dest>: remove what deploy_item put there and put the newest backup (from the manifest) back
undeploy() {
    local dest="$1" bk=""
    if [[ -L "$dest" ]]; then run rm -f -- "$dest"
    elif [[ -e "$dest" && "${LINK_MODE:-symlink}" == "copy" ]]; then run rm -rf -- "$dest"
    elif [[ -e "$dest" ]]; then log_warn "$dest no es un enlace nuestro: se deja como está."; return 0
    fi
    [[ -f "$MANIFEST" ]] && bk="$(awk -F'\t' -v t="$dest" '$1 == "backup" && $2 == t { b = $3 } END { print b }' "$MANIFEST")"
    if [[ -n "$bk" && ( -e "$bk" || -L "$bk" ) ]]; then
        run mkdir -p "$(dirname "$dest")"
        run mv -- "$bk" "$dest"
        log_info "Restaurado: $dest"
    fi
}

# fail_step <step-id> <message>: prints the problem and the step of pre-instalation.md that fixes it
fail_step() {
    local id="$1"; shift
    local entry="${CHECK_STEP[$id]:-}"
    echo "✘ $*" >&2
    [[ -n "$entry" ]] && echo "   → ver $PRE_DOC, Paso ${entry%%|*} (${entry#*|})" >&2
    return 0
}

# local override files (never versioned): ~/.config/dragon-island/local.conf (KEY=value) and hypr/local.lua
LOCAL_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/local.conf"
HYPR_LOCAL="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/local.lua"
local_conf_get() { [[ -f "$LOCAL_CONF" ]] && awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$LOCAL_CONF"; return 0; }

# ensure_via <pacman|aur> <command>...  installs what <command> prints (one package per line)
ensure_via() {
    local kind="$1" pk=(); shift
    mapfile -t pk < <("$@")
    [[ ${#pk[@]} -gt 0 ]] || return 0
    "ensure_$kind" "${pk[@]}"
}
