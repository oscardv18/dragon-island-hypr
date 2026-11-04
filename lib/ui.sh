#!/usr/bin/env bash
# =============================================================================
# dragon-island — presentation of the linear installer (sourced by install.sh). PURE functions: they only print.
# No state, no commands, no alternate screen, no cursor tricks, no key reading: everything is append-only, so that sudo, pacman
# and paru write on the same terminal without interfering.
#
# The caller decides the look ONCE with ui_init (before stdout is redirected to the log):
#   UI_COLOR  true → truecolor + rounded boxes (╭─╮│╰╯) · false → plain text + ASCII boxes (+--+)   (no tty, NO_COLOR, TERM=dumb)
#   UI_COLS   terminal width · UI_W box width = min(UI_COLS, 78)
# The CONTENT is the same in both looks.
# =============================================================================
shopt -s extglob

UI_COLOR=false; UI_COLS=80; UI_W=78

# ui_init <fd>: look at file descriptor <fd> (the real stdout) once
ui_init() {
    local fd="${1:-1}" cols=""
    UI_COLOR=false
    if [[ -t "$fd" && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then UI_COLOR=true; fi
    if [[ -t "$fd" ]]; then cols="$(tput cols 2>/dev/null || true)"; fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"
    [[ "$cols" =~ ^[0-9]+$ ]] && (( cols >= 20 )) || cols=80
    UI_COLS=$cols
    UI_W=$(( cols < 78 ? cols : 78 ))
}

# --- colors (empty strings when UI_COLOR is false) ---------------------------------------------
ui_c() {   # ui_c <name> → escape sequence
    $UI_COLOR || return 0
    case "$1" in
        green)  printf '\e[38;2;93;220;130m' ;;
        red)    printf '\e[38;2;255;95;110m' ;;
        yellow) printf '\e[38;2;249;174;88m' ;;
        cyan)   printf '\e[38;2;0;193;228m' ;;
        magenta) printf '\e[38;2;197;14;210m' ;;
        dim)    printf '\e[2m' ;;
        bold)   printf '\e[1m' ;;
        reset)  printf '\e[0m' ;;
    esac
}

ui_strip() { local s="$1"; printf '%s' "${s//$'\e'\[*([0-9;?])[A-Za-z]/}"; }
ui_len() { local s; s="$(ui_strip "$1")"; printf '%s' "${#s}"; }
ui_rep() { local n="$1" ch="$2" out="" i; for (( i = 0; i < n; i++ )); do out+="$ch"; done; printf '%s' "$out"; }
ui_margin() { local n=$(( (UI_COLS - $1) / 2 )); (( n > 0 )) || n=0; ui_rep "$n" " "; }

# ui_wrap <width> <text>: one line per output line; words longer than the width are cut
ui_wrap() {
    local width="$1" text="$2" line="" word
    while (( ${#text} > 0 )); do
        word="${text%%[[:space:]]*}"
        text="${text#"$word"}"; text="${text#[[:space:]]}"
        while (( ${#word} > width )); do
            [[ -n "$line" ]] && { printf '%s\n' "$line"; line=""; }
            printf '%s\n' "${word:0:width}"; word="${word:width}"
        done
        if [[ -z "$line" ]]; then line="$word"
        elif (( ${#line} + 1 + ${#word} <= width )); then line+=" $word"
        else printf '%s\n' "$line"; line="$word"; fi
    done
    [[ -n "$line" ]] && printf '%s\n' "$line"
    return 0
}

# --- banner ------------------------------------------------------------------------------------
UI_LOGO=(
'██████╗ ██████╗  █████╗  ██████╗  ██████╗ ███╗   ██╗   ██████╗ ███████╗'
'██╔══██╗██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗████╗  ██║  ██╔═══██╗██╔════╝'
'██║  ██║██████╔╝███████║██║  ███╗██║   ██║██╔██╗ ██║  ██║   ██║███████╗'
'██║  ██║██╔══██╗██╔══██║██║   ██║██║   ██║██║╚██╗██║  ██║   ██║╚════██║'
'██████╔╝██║  ██║██║  ██║╚██████╔╝╚██████╔╝██║ ╚████║  ╚██████╔╝███████║'
'╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═════╝ ╚══════╝'
)

# ui_gradient_line <text>: Sweet (magenta) → Garuda (cyan) across the columns, truecolor
ui_gradient_line() {
    local text="$1" n="${#1}" i r g b seg out=""
    for (( i = 0; i < n; i++ )); do
        r=$(( 197 + (0 - 197) * i / (n - 1) )); g=$(( 14 + (193 - 14) * i / (n - 1) )); b=$(( 210 + (228 - 210) * i / (n - 1) ))
        printf -v seg '\e[38;2;%d;%d;%dm%s' "$r" "$g" "$b" "${text:i:1}"; out+="$seg"
    done
    printf '%s\e[0m' "$out"
}

# ui_banner <version>: the big logo when there is room (>= 80 columns), a single line otherwise
ui_banner() {
    local sub="Hyprland · Quickshell · CachyOS   v${1:-?}" line w
    echo
    if (( UI_COLS >= 80 )); then
        w="${#UI_LOGO[0]}"
        for line in "${UI_LOGO[@]}"; do
            printf '%s' "$(ui_margin "$w")"
            if $UI_COLOR; then ui_gradient_line "$line"; else printf '%s' "$line"; fi
            echo
        done
        echo
        printf '%s%s%s%s\n' "$(ui_margin "${#sub}")" "$(ui_c cyan)" "$sub" "$(ui_c reset)"
    else
        printf '%s◆ DRAGON OS ◆%s  %s\n' "$(ui_c magenta)$(ui_c bold)" "$(ui_c reset)" "$sub"
    fi
    echo
}

# --- boxes -------------------------------------------------------------------------------------
# ui_box <color> <title> <line>...: rounded box (ASCII without color), width UI_W, text wrapped to fit
ui_box() {
    local color="$1" title="$2"; shift 2
    local tl="╭" tr="╮" bl="╰" br="╯" h="─" v="│" inner=$(( UI_W - 4 )) line row pad bar
    if ! $UI_COLOR; then tl="+"; tr="+"; bl="+"; br="+"; h="-"; v="|"; fi
    local c r; c="$(ui_c "$color")"; r="$(ui_c reset)"
    local m; m="$(ui_margin "$UI_W")"
    bar="$(ui_rep $(( UI_W - 2 )) "$h")"
    if [[ -n "$title" ]]; then
        local t=" $title " tl_len=$(( ${#title} + 2 ))
        (( tl_len < UI_W - 4 )) || { t=" ${title:0:UI_W-7}… "; tl_len=$(( UI_W - 4 )); }
        bar="${h}${t}$(ui_rep $(( UI_W - 3 - tl_len )) "$h")"
    fi
    printf '%s%s%s%s%s%s\n' "$m" "$c" "$tl" "$bar" "$tr" "$r"
    for line in "$@"; do
        if [[ -z "$line" ]]; then
            printf '%s%s%s%s%s%s%s\n' "$m" "$c" "$v" "$r" "$(ui_rep $(( UI_W - 2 )) " ")" "$c$v" "$r"; continue
        fi
        while IFS= read -r row; do
            pad=$(( inner - ${#row} )); (( pad >= 0 )) || pad=0
            printf '%s%s%s%s %s%s %s%s%s\n' "$m" "$c" "$v" "$r" "$row" "$(ui_rep "$pad" " ")" "$c" "$v" "$r"
        done < <(ui_wrap "$inner" "$line")
    done
    printf '%s%s%s%s%s%s\n' "$m" "$c" "$bl" "$(ui_rep $(( UI_W - 2 )) "$h")" "$br" "$r"
}

# ui_info_box <distro> <kernel> <ram> <profiles> <missing-official> <missing-aur>
ui_info_box() {
    ui_box cyan "Tu sistema" \
        "Distribución: $1" "Kernel: $2 · RAM: $3" "Perfiles: $4" \
        "Faltan $5 paquetes oficiales · $6 AUR"
}

# --- phases and results ------------------------------------------------------------------------
# ui_bar <done> <total> → [█████░░░░░] 5/7
ui_bar() {
    local d="$1" t="$2" width=20 fill
    (( t > 0 )) || t=1
    fill=$(( d * width / t ))
    printf '[%s%s%s%s%s] %s/%s' "$(ui_c cyan)" "$(ui_rep "$fill" "█")" "$(ui_c dim)" "$(ui_rep $(( width - fill )) "░")" "$(ui_c reset)" "$d" "$t"
}

# ui_phase <n> <N> <title>
ui_phase() {
    echo
    printf '%s%s[%s/%s] %s%s\n' "$(ui_c magenta)" "$(ui_c bold)" "$1" "$2" "$3" "$(ui_c reset)"
    printf '%s\n' "$(ui_bar "$(( $1 - 1 ))" "$2")"
}

# ui_line <icon> <color> <text>: "icon text", wrapped at the box width with the continuation lines indented under the text
ui_line() {
    local icon="$1" color="$2" row first=true
    while IFS= read -r row; do
        if $first; then printf '%s%s%s %s\n' "$(ui_c "$color")" "$icon" "$(ui_c reset)" "$row"; first=false
        else printf '  %s\n' "$row"; fi
    done < <(ui_wrap $(( UI_W - 2 )) "$3")
}
ui_ok()   { ui_line "✔" green "$*"; }
ui_warn() { ui_line "⚠" yellow "$*"; }
ui_fail() { ui_line "✘" red "$*"; }
ui_skip() { ui_line "○" dim "$*"; }
ui_note() {
    local row
    while IFS= read -r row; do printf '  %s%s%s\n' "$(ui_c dim)" "$row" "$(ui_c reset)"; done < <(ui_wrap $(( UI_W - 2 )) "$*")
}

# ui_pkgs <ok|fail|skip> <name>...: a compact line "✔ docker ✔ lazygit …", wrapped at the box width
ui_pkgs() {
    local kind="$1" icon color name line="" item; shift
    case "$kind" in ok) icon="✔"; color=green ;; fail) icon="✘"; color=red ;; *) icon="○"; color=dim ;; esac
    for name in "$@"; do
        item="$icon $name"
        if (( ${#line} + 1 + ${#item} > UI_W - 2 )) && [[ -n "$line" ]]; then printf '  %s\n' "$line"; line=""; fi
        line+="${line:+ }$item"
    done
    [[ -n "$line" ]] && printf '  %s%s%s\n' "$(ui_c "$color")" "$line" "$(ui_c reset)"
    return 0
}

# ui_summary <ok|warn|incomplete> <line>...: the final box. Green «Instalación completa» (yellow with warnings) or red «Incompleta».
ui_summary() {
    local kind="$1"; shift
    echo
    case "$kind" in
        ok)         ui_box green  "Instalación completa" "$@" ;;
        warn)       ui_box yellow "Instalación completa, con avisos" "$@" ;;
        dry-run)    ui_box cyan   "Simulación (dry-run): no se cambió nada" "$@" ;;
        *)          ui_box red    "Incompleta" "$@" ;;
    esac
    echo
}

# ui_wrap_list <header> <name>...: "header a b c …" wrapped at the box width, continuation lines indented
ui_wrap_list() {
    local head="$1" row; shift
    printf '%s%s%s\n' "$(ui_c bold)" "$head" "$(ui_c reset)"
    while IFS= read -r row; do printf '  %s\n' "$row"; done < <(ui_wrap $(( UI_W - 2 )) "$*")
}
