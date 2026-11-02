#!/usr/bin/env bash
# Shared editor deployment; caller supplies common.sh and installer/migration environment.
nvim_config_dir() { printf '%s/nvim\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

nvim_version_ok() {
    local version
    command -v nvim >/dev/null 2>&1 || return 1
    version="$(NVIM_LOG_FILE=/dev/null nvim --version)" || return 1
    [[ "$version" =~ ^NVIM\ v([0-9]+)\.([0-9]+) ]] || return 1
    [[ "$version" == *LuaJIT* ]] || return 1
    (( BASH_REMATCH[1] > 0 || BASH_REMATCH[2] >= 12 ))
}

nvim_deploy() {
    local src="$REPO_DIR/config/nvim" dest rel recorded=""
    dest="$(nvim_config_dir)"
    python3 "$REPO_DIR/scripts/check-nvim-public.py" "$src" || return 1
    [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] && return 0
    if [[ "$LINK_MODE" == copy && -d "$dest" && ! -L "$dest" ]] && diff -rq -- "$src" "$dest" >/dev/null; then
        if [[ -f "$MANIFEST" ]]; then
            recorded="$(awk -F'\t' -v t="$dest" '$1 == "deploy" && $2 == t { s = $3 } END { print s }' "$MANIFEST")"
        fi
        # Identical pre-existing user config still needs a backup on first adoption;
        # only a copy already owned by this deployment is an idempotent no-op.
        [[ "$recorded" == "$src" ]] && return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        # backup_copy is required here; remove only after it succeeds, so deploy_item
        # does not move the same directory over an already-populated backup path.
        backup_copy "$dest" || return 1
        rel="${dest#"$HOME"/}"
        if ! $DRY_RUN; then
            # Common helpers are also called from conditional module runners,
            # where Bash's errexit does not protect an intermediate failed cp.
            if ! diff -rq --no-dereference -- "$dest" "$BACKUP_DIR/$rel" >/dev/null 2>&1; then
                log_warn 'No se pudo verificar el respaldo de Neovim; se conserva la configuración anterior.'
                return 1
            fi
            printf 'backup\t%s\t%s\n' "$dest" "$BACKUP_DIR/$rel" >> "$MANIFEST"
        fi
        run rm -rf -- "$dest" || return 1
        if $DRY_RUN; then
            run mkdir -p "$(dirname "$dest")"
            if [[ "$LINK_MODE" == symlink ]]; then run ln -sfn -- "$src" "$dest"
            else run cp -a -- "$src" "$dest"; fi
            return 0
        fi
    fi
    deploy_item "$src" "$dest" || return 1
    if ! $DRY_RUN; then
        if [[ "$LINK_MODE" == symlink ]]; then
            [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]] || return 1
        else
            diff -rq --no-dereference -- "$src" "$dest" >/dev/null || return 1
        fi
    fi
}

nvim_revert() {
    local dest src temporary
    dest="$(nvim_config_dir)"
    [[ -f "$MANIFEST" ]] || return 0
    src="$(awk -F'\t' -v t="$dest" '$1 == "deploy" && $2 == t { s = $3 } END { print s }' "$MANIFEST")"
    [[ -n "$src" ]] || { log_info 'Neovim no fue desplegado por este instalador: se conserva.'; return 0; }
    if [[ -L "$dest" && "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]]; then
        log_warn 'El enlace de Neovim cambió después de instalarlo: se conserva.'; return 0
    fi
    if [[ -e "$dest" && ! -L "$dest" && "$LINK_MODE" != copy ]]; then
        log_warn 'Neovim ya no es el enlace instalado: se conserva la carpeta actual.'; return 0
    fi
    undeploy "$dest"
    if ! $DRY_RUN; then
        temporary="$(mktemp "$STATE_DIR/.nvim-manifest-XXXXXX")"
        awk -F'\t' -v t="$dest" '$2 != t' "$MANIFEST" > "$temporary"
        mv -T -- "$temporary" "$MANIFEST"
    fi
    log_info 'Configuración de Neovim retirada; plugins y datos de usuario se conservan.'
}
