#!/usr/bin/env bash
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
        printf '[dry-run] %q ' "$@"
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

# ensure_omz: oh-my-zsh and the two external plugins used by config/zsh/.zshrc (git clones, as in the
# original setup: they are not pacman packages). Existing clones are left alone.
ensure_omz() {
    local zsh_dir="${ZSH:-$HOME/.oh-my-zsh}" custom
    custom="${ZSH_CUSTOM:-$zsh_dir/custom}"
    if [[ ! -d "$zsh_dir" ]]; then
        log_info "Clonando oh-my-zsh en $zsh_dir"
        run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
    fi
    local name
    for name in zsh-autosuggestions zsh-syntax-highlighting; do
        if [[ ! -d "$custom/plugins/$name" ]]; then
            log_info "Clonando el plugin $name"
            run git clone --depth 1 "https://github.com/zsh-users/$name.git" "$custom/plugins/$name"
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
