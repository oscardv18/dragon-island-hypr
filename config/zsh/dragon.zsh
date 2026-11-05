# =============================================================================
# dragon-island — terminal setup. Standalone: `source ~/.config/dragon-island/zsh/dragon.zsh` from any ~/.zshrc
# (the shell module adds that one line between markers). Works with or without oh-my-zsh, and after CachyOS's own config.
# Load order (it matters):
#   0. CachyOS / Powerlevel10k: when an earlier line of ~/.zshrc loaded p10k (cachyos-config.zsh does), it is unloaded
#      here (instant prompt flushed, hooks removed) so Starship owns the prompt. CachyOS's aliases and completion stay.
#   1. fpath (herdr completion) and compinit, unless oh-my-zsh already ran it
#   2. fzf key bindings (Ctrl+R / Ctrl+T / Alt+C); `fzf --zsh` also binds Tab to fzf-completion ...
#   3. fzf-tab ... which comes next and is the LAST to bind ^I (Tab = the advanced search)
#   4. zsh-autosuggestions, then zsh-syntax-highlighting (it must be the last widget wrapper)
#   5. aliases, long-command hooks (commands.zsh), history, zoxide, starship (the prompt), ~/.zshrc.local
# Plugins: the distro packages first (/usr/share/zsh/plugins: zsh-autosuggestions, zsh-syntax-highlighting), then the
# git clones of the shell module (fzf-tab always; the other two only without the packages). A missing one is reported
# once per session.
# =============================================================================
_dragon_zsh="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh"

# --- 0. Powerlevel10k loaded before us (CachyOS) -------------------------------------------------------------------
# The instant prompt redirected the output to a file and printed a p10k prompt: give the terminal back first
# (this also deletes p10k's prompt cache, so the next shell does not flash it again), then remove p10k's hooks.
if (( ${+__p9k_instant_prompt_active} )) && (( $+functions[_p9k_instant_prompt_cleanup] )); then
    _p9k_instant_prompt_cleanup 0
    setopt prompt_cr prompt_sp
fi
(( $+functions[powerlevel10k_plugin_unload] )) && powerlevel10k_plugin_unload
precmd_functions=(${precmd_functions:#_p9k_*})

# --- where the zsh plugins live ------------------------------------------------------------------------------------
# DRAGON_ZSH_PLUGINS wins; oh-my-zsh's custom dir only when the user can write it (CachyOS's /usr/share/oh-my-zsh
# belongs to root and stays empty); our own dir otherwise.
_dragon_omz_plugins="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
if [[ -n ${DRAGON_ZSH_PLUGINS:-} ]]; then _dragon_plugins="$DRAGON_ZSH_PLUGINS"
elif [[ -d $_dragon_omz_plugins && -w $_dragon_omz_plugins ]]; then _dragon_plugins="$_dragon_omz_plugins"
else _dragon_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/zsh-plugins"; fi
unset _dragon_omz_plugins

# _dragon_plugin_file <name>: the file to source (package first), empty when the plugin is nowhere
_dragon_plugin_file() {
    local f
    for f in "${DRAGON_ZSH_SYSTEM_PLUGINS:-/usr/share/zsh/plugins}/$1/$1.zsh" "$_dragon_plugins/$1/$1.plugin.zsh"; do
        [[ -f $f ]] && { print -r -- "$f"; return 0; }
    done
    return 1
}
_dragon_fzf_tab="$_dragon_plugins/fzf-tab/fzf-tab.plugin.zsh"
_dragon_missing=()
[[ -f $_dragon_fzf_tab ]] || _dragon_missing+=(fzf-tab)

# herdr (agents multiplexer, ~/.local/bin): its completion lives in ~/.zfunc; regenerated when the binary is newer
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"
fpath=("$HOME/.zfunc" $fpath)
if command -v herdr >/dev/null && [[ $HOME/.local/bin/herdr -nt $HOME/.zfunc/_herdr ]]; then
    mkdir -p "$HOME/.zfunc" && herdr completion zsh >| "$HOME/.zfunc/_herdr" 2>/dev/null
fi
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit -u; }

[[ -f $_dragon_zsh/history.zsh ]] && source $_dragon_zsh/history.zsh
[[ -f $_dragon_zsh/fzf.zsh ]] && source $_dragon_zsh/fzf.zsh               # fzf first ...
[[ -f $_dragon_zsh/completion.zsh ]] && source $_dragon_zsh/completion.zsh # ... fzf-tab after it, before the two below

# autosuggestions: CachyOS may have loaded it already (it rebinds its widgets on every prompt, fzf-tab's included)
if ! (( $+functions[_zsh_autosuggest_start] )); then
    if _dragon_f="$(_dragon_plugin_file zsh-autosuggestions)"; then source "$_dragon_f"; else _dragon_missing+=(zsh-autosuggestions); fi
fi
# syntax-highlighting ≥ 0.8 draws from the zle-line-pre-redraw hook (no widget wrapping), so a copy CachyOS loaded
# before fzf-tab is fine as it is; never load a second copy on top of it
if ! (( $+functions[_zsh_highlight] )); then
    if _dragon_f="$(_dragon_plugin_file zsh-syntax-highlighting)"; then source "$_dragon_f"; else _dragon_missing+=(zsh-syntax-highlighting); fi
fi
unset _dragon_f

[[ -f $_dragon_zsh/aliases.zsh ]] && source $_dragon_zsh/aliases.zsh
[[ -f $_dragon_zsh/commands.zsh ]] && source $_dragon_zsh/commands.zsh   # long commands → the island

# a missing plugin: one line, once per session (the variable is inherited by the shells opened from this one)
if (( ${#_dragon_missing} )) && [[ -z ${DRAGON_ZSH_WARNED:-} ]]; then
    _dragon_repo="${_dragon_zsh:A:h:h}"     # symlink install: config/zsh of the repo
    [[ -x $_dragon_repo/install.sh ]] || _dragon_repo="<carpeta del repo dragon-island>"
    print -r -- "dragon-island: faltan plugins de zsh (${(j:, :)_dragon_missing}). Arréglalo con: $_dragon_repo/install.sh --modules shell" >&2
    export DRAGON_ZSH_WARNED=1
    unset _dragon_repo
fi
unset _dragon_missing

[[ -f $_dragon_zsh/fastfetch.zsh ]] && source $_dragon_zsh/fastfetch.zsh

# zoxide: `z dir` / `zi` (interactive); `cd` stays the normal cd
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

command -v starship >/dev/null && eval "$(starship init zsh)"

# A blank line between one command's output and the next prompt, but none above the first prompt of a new
# terminal or after `clear` (starship's add_newline is off: it printed one there too). fastfetch.zsh sets the
# flag when it prints at start, so its output still gets the gap.
_dragon_prompt_spacer() { (( ${+_dragon_prompt_seen} )) && print; typeset -g _dragon_prompt_seen=1 }
precmd_functions+=(_dragon_prompt_spacer)
clear() { unset _dragon_prompt_seen; command clear "$@" }

# Private bits (tokens, personal aliases, machine paths) live outside the repo
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
