# Tab = fzf-tab (advanced search). Sourced after compinit (oh-my-zsh.sh) and fzf, before zsh-autosuggestions and
# zsh-syntax-highlighting. If the plugin is missing the normal zsh completion keeps working.
_fzf_tab="${ZSH_CUSTOM:-$ZSH/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh"
[[ -f $_fzf_tab ]] || return 0

(( $+LS_COLORS )) || eval "$(dircolors -b 2>/dev/null)"

# recommended by fzf-tab's README
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group '<' '>'

# fzf-tab uses FZF_DEFAULT_OPTS (palette, rounded border, 60 % height); `/` accepts and keeps completing (deep paths)
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' continuous-trigger '/'

# ---- previews ----
_dragon_dir='eza -1 --color=always --icons=always $realpath'
_dragon_file='bat --color=always --style=numbers --line-range=:200 $realpath'
zstyle ':fzf-tab:complete:(cd|z|zi|pushd|ls|ll|la|lt|eza):*' fzf-preview $_dragon_dir
# any other path: a folder shows its list, a file its first 200 lines
zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -d $realpath ]]; then eza -1 --color=always --icons=always $realpath; elif [[ -f $realpath ]]; then bat --color=always --style=numbers --line-range=:200 $realpath; fi'
# processes
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview '[[ $group == "[process ID]" ]] && ps --pid=$word -o pid,user,%cpu,%mem,etime,cmd'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags '--preview-window=down:4:wrap'
# git
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff --color=always -- $word | head -200'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always --oneline --graph -n 30 $word'
zstyle ':fzf-tab:complete:git-(checkout|switch|branch|merge|rebase):*' fzf-preview 'case "$group" in
    "[modified file]") git diff --color=always $word ;;
    "[recent commit object name]") git show --color=always $word ;;
    *) git log --color=always --oneline -n 20 $word ;;
esac'
# environment variables: their value
zstyle ':fzf-tab:complete:(-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview 'echo ${(P)word}'
# packages: the repository record (official first, the AUR helper otherwise)
zstyle ':fzf-tab:complete:(pacman|yay|paru):*' fzf-preview '(pacman -Si $word 2>/dev/null || (yay -Si $word 2>/dev/null)) | head -40'

source $_fzf_tab
unset _fzf_tab
