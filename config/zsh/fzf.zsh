# fzf: Ctrl+R history · Ctrl+T files · Alt+C folders, with the Dragonized palette, rounded border, 60 % height.
# Must be sourced BEFORE fzf-tab: `fzf --zsh` binds Tab to fzf-completion and fzf-tab has to bind ^I last.
command -v fzf >/dev/null || return 0
[[ -t 0 ]] || return 0      # no terminal (zsh -c, scripts): no key bindings to set up

export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# bg -1 = the terminal's own (translucent) background
export FZF_DEFAULT_OPTS="--layout=reverse --border=rounded --height=60% \
--color=bg:-1,bg+:#22243a,fg:#e6e8ef,fg+:#ffffff,hl:#c50ed2,hl+:#00c1e4,info:#8a8fa3,prompt:#c50ed2,pointer:#00c1e4,marker:#06c993,spinner:#f9ae58,header:#8a8fa3,border:#7c3aed,gutter:-1,label:#8a8fa3"

export FZF_CTRL_T_OPTS="--preview 'if [[ -d {} ]]; then eza --tree --level=2 --color=always --icons=always {}; else bat --color=always --style=numbers --line-range=:200 {}; fi'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=always {}'"
export FZF_CTRL_R_OPTS="--preview 'echo {2..}' --preview-window=down:3:wrap"

# `fzf --zsh` exists since fzf 0.48; older versions ship the scripts in /usr/share/fzf
if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
elif [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
    source /usr/share/fzf/key-bindings.zsh
    [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
fi
