# =============================================================================
# dragon-island — terminal setup. Standalone: `source ~/.config/dragon-island/zsh/dragon.zsh` from any ~/.zshrc
# (the shell module adds that one line between markers). Works with or without oh-my-zsh.
# Load order (it matters):
#   1. fpath (herdr completion) and compinit, unless oh-my-zsh already ran it
#   2. fzf key bindings (Ctrl+R / Ctrl+T / Alt+C); `fzf --zsh` also binds Tab to fzf-completion ...
#   3. fzf-tab ... which comes next and is the LAST to bind ^I (Tab = the advanced search)
#   4. zsh-autosuggestions, then zsh-syntax-highlighting (it must be the last widget wrapper)
#   5. aliases, history, zoxide, starship (the prompt), ~/.zshrc.local
# =============================================================================
_dragon_zsh="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh"

# where the zsh plugins (git clones) live: oh-my-zsh's custom dir when there is one, else our own
if [[ -n ${DRAGON_ZSH_PLUGINS:-} ]]; then _dragon_plugins="$DRAGON_ZSH_PLUGINS"
elif [[ -d ${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins ]]; then _dragon_plugins="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"
else _dragon_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/zsh-plugins"; fi

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
[[ -f $_dragon_plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] && source $_dragon_plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
[[ -f $_dragon_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh ]] && source $_dragon_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
[[ -f $_dragon_zsh/aliases.zsh ]] && source $_dragon_zsh/aliases.zsh

# zoxide: `z dir` / `zi` (interactive); `cd` stays the normal cd
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

command -v starship >/dev/null && eval "$(starship init zsh)"

# Private bits (tokens, personal aliases, machine paths) live outside the repo
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
