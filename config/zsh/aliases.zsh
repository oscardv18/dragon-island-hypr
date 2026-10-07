# eza instead of ls (icons need the Nerd Font Ghostty already uses)
if command -v eza >/dev/null; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -lh --icons=auto --git --group-directories-first'
    alias la='ll -a'
    alias lt='eza --tree --level=2 --icons=auto'
    # Dragonized palette (references/design.md) in truecolor: directories violetSoft, links cyan, executables ok,
    # sizes ok, owner cyan, dates / group dim, git: new ok · modified warn · deleted error · renamed cyan
    export EZA_COLORS="reset:di=1;38;2;168;85;247:ln=38;2;0;193;228:ex=1;38;2;6;201;147:so=38;2;197;14;210:pi=38;2;249;174;88:bd=38;2;249;174;88:cd=38;2;249;174;88:or=38;2;237;37;78:ur=38;2;249;174;88:uw=38;2;237;37;78:ux=38;2;6;201;147:ue=38;2;6;201;147:gr=38;2;249;174;88:gw=38;2;237;37;78:gx=38;2;6;201;147:tr=38;2;249;174;88:tw=38;2;237;37;78:tx=38;2;6;201;147:sn=38;2;6;201;147:sb=38;2;6;201;147:uu=38;2;0;193;228:un=38;2;138;143;163:gu=38;2;0;193;228:gn=38;2;138;143;163:da=38;2;138;143;163:hd=1;4;38;2;138;143;163:xx=38;2;58;61;85:ga=38;2;6;201;147:gm=38;2;249;174;88:gd=38;2;237;37;78:gv=38;2;0;193;228:gt=38;2;197;14;210:lc=38;2;237;37;78:lm=38;2;249;174;88:cc=38;2;237;37;78"
fi
command -v herdr >/dev/null && alias hd=herdr
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
