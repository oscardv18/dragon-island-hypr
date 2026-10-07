# History: big, shared between terminals, no duplicates, and a leading space keeps a command out (good material for Ctrl+R)
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=200000
SAVEHIST=200000
setopt share_history          # every terminal sees the others' commands (implies incremental append)
setopt hist_ignore_all_dups   # a repeated command replaces the old entry
setopt hist_ignore_space      # " secret-command" is not saved
setopt hist_reduce_blanks
setopt hist_verify
