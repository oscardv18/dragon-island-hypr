# =============================================================================
# dragon-island — ~/.zshrc (imported from the user's own, plus the terminal setup of config/zsh/*.zsh)
# Load order (it matters):
#   1. oh-my-zsh (+ the `git` plugin); oh-my-zsh.sh runs compinit AFTER loading the `plugins` array, so
#      zsh-autosuggestions and zsh-syntax-highlighting are NOT in that array: they have to come after fzf-tab.
#   2. fzf         key bindings (Ctrl+R / Ctrl+T / Alt+C); `fzf --zsh` also binds Tab to fzf-completion ...
#   3. fzf-tab     ... so fzf-tab comes next and is the LAST to bind ^I (Tab = the advanced search)
#   4. zsh-autosuggestions, then zsh-syntax-highlighting (it must be the last widget wrapper)
#   5. aliases, history, zoxide, starship (the prompt is untouched)
# =============================================================================

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"   # (overridden by starship below)

# autosuggestions / syntax-highlighting are sourced further down, after fzf-tab
plugins=(git)

# herdr (agents multiplexer, installed in ~/.local/bin): its zsh completion lives in ~/.zfunc and must be in fpath
# BEFORE compinit (oh-my-zsh.sh) so fzf-tab sees it; it is regenerated when the binary is newer (after `herdr update`)
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"
fpath=("$HOME/.zfunc" $fpath)
if command -v herdr >/dev/null && [[ $HOME/.local/bin/herdr -nt $HOME/.zfunc/_herdr ]]; then
    mkdir -p "$HOME/.zfunc" && herdr completion zsh >| "$HOME/.zfunc/_herdr" 2>/dev/null
fi

source $ZSH/oh-my-zsh.sh   # runs compinit

# --- dragon-island terminal: files of config/zsh (deployed to ~/.config/dragon-island/zsh) ---
_dragon_zsh="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/zsh"
_dragon_plugins="${ZSH_CUSTOM:-$ZSH/custom}/plugins"

[[ -f $_dragon_zsh/history.zsh ]] && source $_dragon_zsh/history.zsh
[[ -f $_dragon_zsh/fzf.zsh ]] && source $_dragon_zsh/fzf.zsh               # fzf first ...
[[ -f $_dragon_zsh/completion.zsh ]] && source $_dragon_zsh/completion.zsh # ... fzf-tab after it, before the two below
[[ -f $_dragon_plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] && source $_dragon_plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
[[ -f $_dragon_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh ]] && source $_dragon_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
[[ -f $_dragon_zsh/aliases.zsh ]] && source $_dragon_zsh/aliases.zsh

# zoxide: `z dir` / `zi` (interactive); `cd` stays the normal cd
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

eval "$(starship init zsh)"

# Private bits (tokens, personal aliases, machine paths) live outside the repo
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
