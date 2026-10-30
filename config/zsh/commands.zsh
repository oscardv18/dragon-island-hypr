# =============================================================================
# dragon-island — long commands → the island (services/Commands.qml). Nothing here waits for Quickshell:
#   preexec  remembers the command and starts a background sleeper that, if the command is still running after the
#            threshold, reports it as "en curso" (qs ipc call commands started …)
#   precmd   kills the sleeper; if the command took ≥ the threshold, reports it (qs ipc call commands finished …)
# Threshold: settings.json "longCommandSeconds" (default 30), read once when the shell starts (no jq: a plain match);
# DRAGON_LONG_COMMAND overrides it.
# Only inside a Hyprland session with qs available; costs one fork per command (the sleeper).
# =============================================================================
[[ -n $HYPRLAND_INSTANCE_SIGNATURE ]] && (( $+commands[qs] )) || return 0
zmodload zsh/datetime zsh/zselect 2>/dev/null || return 0

_dragon_long=30
() {
    local f="${XDG_CONFIG_HOME:-$HOME/.config}/dragon-island/settings.json" line
    [[ -r $f ]] || return
    line=${(M)${(f)"$(<$f)"}:#*\"longCommandSeconds\"*}
    [[ $line =~ '([0-9]+)' ]] && _dragon_long=$match[1]
}
[[ -n ${DRAGON_LONG_COMMAND:-} ]] && _dragon_long=$DRAGON_LONG_COMMAND   # override (tests)

typeset -g _dragon_cmd="" _dragon_cmd_t0=0 _dragon_cmd_id="" _dragon_sleeper=0

_dragon_cmd_preexec() {
    _dragon_cmd=$1
    _dragon_cmd_t0=$EPOCHSECONDS
    _dragon_cmd_id="$$-$EPOCHSECONDS-$RANDOM"
    local id=$_dragon_cmd_id cmd=$1 dir=$PWD long=$_dragon_long
    # the sleeper waits with the zselect BUILTIN (no child process): killing it in precmd leaves nothing behind
    ( zselect -t $(( long * 100 )); qs ipc call commands started "$id" "$cmd" "$dir" ) >/dev/null 2>&1 &!
    _dragon_sleeper=$!
}

_dragon_cmd_precmd() {
    local code=$?
    (( _dragon_sleeper )) && kill $_dragon_sleeper 2>/dev/null
    _dragon_sleeper=0
    [[ -n $_dragon_cmd ]] || return 0
    local secs=$(( EPOCHSECONDS - _dragon_cmd_t0 ))
    if (( secs >= _dragon_long )); then
        qs ipc call commands finished "$_dragon_cmd" $code $secs "$PWD" "$_dragon_cmd_id" >/dev/null 2>&1 &!
    fi
    _dragon_cmd=""
    return 0
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _dragon_cmd_preexec
# first in the list: it must see the command's exit status before any other precmd hook runs
precmd_functions=(_dragon_cmd_precmd ${precmd_functions:#_dragon_cmd_precmd})
