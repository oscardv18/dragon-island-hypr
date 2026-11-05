#!/usr/bin/env bash
# =============================================================================
# dragon-island — zsh pieces shared by modules/shell.sh, migration 191 and doctor.sh (caller has lib/common.sh).
# The rules here are the same ones config/zsh/dragon.zsh follows when it loads:
#   · plugins: the distro packages first (/usr/share/zsh/plugins: zsh-autosuggestions, zsh-syntax-highlighting);
#     fzf-tab has no package and is a git clone in zsh_plugin_dir.
#   · zsh_plugin_dir: $DRAGON_ZSH_PLUGINS, else oh-my-zsh's custom/plugins ONLY when it exists and is writable
#     (CachyOS ships oh-my-zsh in /usr/share, owned by root), else ~/.local/share/dragon-island/zsh-plugins.
#   · the prompt is Dragon's Starship: ~/.config/starship.toml is Dragon's file (a detached copy: dragon-palette
#     rewrites its colours), recognised by its first comment line.
# =============================================================================
# shellcheck disable=SC2034,SC2016  # ZSH_LINE is used by the callers and is written literally into ~/.zshrc
ZSH_LINE='source "${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh/dragon.zsh"'
ZSH_SYSTEM_PLUGINS="${DRAGON_ZSH_SYSTEM_PLUGINS:-/usr/share/zsh/plugins}"
ZSH_PACKAGED_PLUGINS=(zsh-autosuggestions zsh-syntax-highlighting)
STARSHIP_SIGNATURE='# dragon-island — starship prompt'

zsh_plugin_dir() {
    local omz="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
    if [[ -n "${DRAGON_ZSH_PLUGINS:-}" ]]; then echo "$DRAGON_ZSH_PLUGINS"
    elif [[ -d "$omz" && -w "$omz" ]]; then echo "$omz"
    else echo "${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/zsh-plugins"; fi
}

# zsh_plugin_file <name>: the file dragon.zsh sources for that plugin (package first); 1 when there is none
zsh_plugin_file() {
    local name="$1" dir f
    dir="$(zsh_plugin_dir)"
    if [[ "$name" == fzf-tab ]]; then f="$dir/fzf-tab/fzf-tab.plugin.zsh"; [[ -f "$f" ]] && { echo "$f"; return 0; }; return 1; fi
    for f in "$ZSH_SYSTEM_PLUGINS/$name/$name.zsh" "$dir/$name/$name.plugin.zsh"; do
        [[ -f "$f" ]] && { echo "$f"; return 0; }
    done
    return 1
}

# zsh_ensure_plugins: clones fzf-tab when missing and checks the two packaged plugins. Every problem is a log_warn with
# the exact command and makes it return 1 (the module counts it as failed: a silent «✔» left the terminal without plugins).
zsh_ensure_plugins() {
    local name rc=0
    for name in "${ZSH_PACKAGED_PLUGINS[@]}"; do
        if zsh_plugin_file "$name" >/dev/null; then log_info "Plugin $name: $(zsh_plugin_file "$name")"
        elif $DRY_RUN; then log_info "Plugin $name: lo instala el paquete $name"
        else log_warn "Falta el plugin $name: sudo pacman -S --needed $name"; rc=1; fi
    done
    zsh_ensure_fzf_tab || rc=1
    return "$rc"
}

# zsh_ensure_fzf_tab: the only plugin without a package (git clone, as the user, in zsh_plugin_dir)
zsh_ensure_fzf_tab() {
    local dir rc=0
    dir="$(zsh_plugin_dir)"
    if [[ -f "$dir/fzf-tab/fzf-tab.plugin.zsh" ]]; then log_info "Plugin fzf-tab ya está en $dir"
    elif [[ -e "$dir/fzf-tab" ]]; then
        log_warn "$dir/fzf-tab existe pero está incompleto. Arréglalo con: rm -rf '$dir/fzf-tab' && git clone --depth 1 https://github.com/Aloxaf/fzf-tab.git '$dir/fzf-tab'"
        rc=1
    elif run mkdir -p "$dir" && run git clone --quiet --depth 1 https://github.com/Aloxaf/fzf-tab.git "$dir/fzf-tab"; then
        log_info "Plugin fzf-tab clonado en $dir"
    else
        log_warn "No se pudo clonar fzf-tab en $dir. Hazlo a mano: git clone --depth 1 https://github.com/Aloxaf/fzf-tab.git '$dir/fzf-tab'"
        rc=1
    fi
    return "$rc"
}

starship_config_path() { echo "${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"; }

# starship_is_dragon <file>: a link to the repo's file, or Dragon's file already detached by dragon-palette
starship_is_dragon() {
    [[ "$(readlink -f "$1")" == "$(readlink -f "$REPO_DIR/config/starship/starship.toml")" ]] || grep -qsF "$STARSHIP_SIGNATURE" "$1"
}

# zsh_starship_deploy: Dragon's starship.toml in place; somebody else's (CachyOS, yours) is moved to the backups first.
# Its own backup path: palette_setup runs next and backs the same file up again under BACKUP_DIR/<path under $HOME>,
# which would overwrite the user's copy if both used that path. The manifest entry lets uninstall.sh put it back.
zsh_starship_deploy() {
    local dest bk
    dest="$(starship_config_path)"
    if [[ -e "$dest" ]] && starship_is_dragon "$dest"; then log_info "starship.toml ya es el de Dragon: $dest"; return 0; fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        bk="$BACKUP_DIR/starship-antes-de-dragon/$(basename "$dest")"
        run mkdir -p "$(dirname "$bk")"
        run mv -- "$dest" "$bk"
        $DRY_RUN || printf 'backup\t%s\t%s\n' "$dest" "$bk" >> "$MANIFEST"
        log_info "$dest no era el de Dragon: guardado en $bk"
    fi
    deploy_item "$REPO_DIR/config/starship/starship.toml" "$dest"
}

zsh_block_ok() { [[ -f "$HOME/.zshrc" ]] && grep -qxF "# >>> dragon-island:zsh" "$HOME/.zshrc" && [[ "$(marker_get "$HOME/.zshrc" zsh "#")" == "$ZSH_LINE" ]]; }

# zsh_probe: opens an interactive zsh the way a new terminal does — on a pseudo-terminal (script(1)), so the fzf key
# bindings and p10k's instant prompt behave as they do in Ghostty; stderr goes to a file — and prints key=value lines:
# prompt=starship|p10k|other, autosuggestions|syntax|fzftab|zoxide=0|1, stderr=<n>, error=<first stderr line>.
# Side effects are those of opening a terminal. Without script(1) it falls back to a plain zsh -i (no tty).
zsh_probe() {
    local err code out cmd
    command -v zsh >/dev/null 2>&1 || { echo "prompt=nozsh"; return 1; }
    err="$(mktemp)"; code="$(mktemp)"
    # shellcheck disable=SC2016  # expanded by zsh
    printf '%s\n' \
        'p=other' \
        '[[ $PROMPT == *"starship prompt"* ]] && p=starship' \
        '(( ${#precmd_functions[(R)_p9k_*]} )) && p=p10k' \
        'print -r -- "@prompt=$p"' \
        'print -r -- "@autosuggestions=$(( $+functions[_zsh_autosuggest_start] ))"' \
        'print -r -- "@syntax=$(( $+functions[_zsh_highlight] ))"' \
        'print -r -- "@fzftab=$(( $+functions[fzf-tab-complete] ))"' \
        'print -r -- "@zoxide=$(( $+functions[__zoxide_z] ))"' > "$code"
    if command -v script >/dev/null 2>&1; then
        printf -v cmd 'zsh -i -c %q 2>%q' "source $code" "$err"
        out="$(cd "$HOME" && TERM="${TERM:-xterm-256color}" timeout 20 script -qec "$cmd" /dev/null </dev/null 2>/dev/null)" || true
    else
        out="$(cd "$HOME" && TERM="${TERM:-xterm-256color}" timeout 20 zsh -i -c "source $code" </dev/null 2>"$err")" || true
    fi
    printf '%s\n' "$out" | tr -d '\r' | sed -n 's/.*@\(prompt\|autosuggestions\|syntax\|fzftab\|zoxide\)=\([a-z0-9]*\).*/\1=\2/p'
    echo "stderr=$(grep -c . "$err")"
    echo "error=$(grep -m1 . "$err")"
    rm -f "$err" "$code"
}
