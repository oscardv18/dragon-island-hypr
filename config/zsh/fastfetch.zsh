# dragon-island · fastfetch wrapper
# - Ghostty (kitty graphics): usa el núcleo neural como imagen.
# - Cualquier otra terminal / TTY / ssh / tmux: usa el logo ASCII de config.jsonc.
# Forzar ASCII:   DRAGON_FF_ASCII=1 fastfetch
# Al abrir cada terminal (opcional):  export DRAGON_FF_ON_START=1   (antes de cargar este archivo)

fastfetch() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
  if [[ -z $DRAGON_FF_ASCII && -z $TMUX && -z $STY && -f $cfg/dragon-core.png \
        && ( $TERM_PROGRAM == ghostty || -n $GHOSTTY_RESOURCES_DIR ) ]]; then
    command fastfetch --logo-type kitty-direct --logo "$cfg/dragon-core.png" \
      --logo-width 28 --logo-height 14 \
      --logo-padding-top 1 --logo-padding-left 2 --logo-padding-right 3 "$@"
  else
    command fastfetch "$@"
  fi
}

if [[ -o interactive && -n $DRAGON_FF_ON_START && -z $DRAGON_FF_SHOWN ]]; then
  export DRAGON_FF_SHOWN=1
  fastfetch
fi
