#!/usr/bin/env bash
# shellcheck disable=SC2034  # TUI_* state is read by the render functions
# =============================================================================
# dragon-island — installer TUI (sourced). PRESENTATION ONLY: it receives events from lib/events.sh
# (tui_handle <type> k v...) and draws them. It never runs an installer command; the only external
# programs it calls are read-only terminal queries (stty, tput) and gum style for the final frame.
#
# Layout (everything centred in the terminal, at most 78 columns wide, works from 60):
#   header box (name + version) · phase bar · current step · package table · progress bar · log panel
# One frame is built in a variable and written in a single write (cursor home + clear-to-end-of-line),
# so there is no flicker; it is redrawn on SIGWINCH and throttled to ~20 frames per second.
# Test hooks: TUI_COLS / TUI_ROWS override the terminal size; tui_frame prints the frame without a terminal.
# Palette: Sweet / Garuda Dragonized (same colours as install.sh).
# =============================================================================
TUI_NAME="${TUI_NAME:-dragon-island}"
TUI_VERSION="${TUI_VERSION:-}"
TUI_OPEN=false
TUI_PHASE=""             # current phase name
declare -a TUI_PHASES_DONE=()
declare -a TUI_PKGS=()
declare -A TUI_PKG_STATE=()
declare -A TUI_PKG_DETAIL=()
declare -a TUI_LOG=()
TUI_STEP=""
TUI_PROG_DONE=0          # progress of a long check (preflight): shown instead of «Paquetes (0/0)»
TUI_PROG_TOTAL=0
TUI_WARNS=0
TUI_LAST_DRAW=0
TUI_DIRTY=false
TUI_MAXW=78
TUI_MINW=40

# --- colours -----------------------------------------------------------------
tui_use_color() { [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; }
# tui_c <name> → escape sequence ("" when colours are off)
tui_c() {
    tui_use_color || return 0
    case "$1" in
        cyan)    printf '\e[38;2;0;193;228m' ;;
        magenta) printf '\e[38;2;197;14;210m' ;;
        violet)  printf '\e[38;2;124;58;237m' ;;
        text)    printf '\e[38;2;230;232;239m' ;;
        green)   printf '\e[38;2;6;201;147m' ;;
        amber)   printf '\e[38;2;245;165;36m' ;;
        red)     printf '\e[38;2;255;92;108m' ;;
        dim)     printf '\e[38;2;130;134;150m' ;;
        bold)    printf '\e[1m' ;;
        reset)   printf '\e[0m' ;;
    esac
}

C_cyan="$(tui_c cyan)"; C_magenta="$(tui_c magenta)"; C_violet="$(tui_c violet)"; C_text="$(tui_c text)"
C_green="$(tui_c green)"; C_amber="$(tui_c amber)"; C_red="$(tui_c red)"; C_dim="$(tui_c dim)"
C_bold="$(tui_c bold)"; C_reset="$(tui_c reset)"

# --- geometry ----------------------------------------------------------------
tui_size() {   # sets TUI_W_TERM, TUI_H_TERM
    local r="" c=""
    if [[ -n "${TUI_COLS:-}" ]]; then c="$TUI_COLS"; r="${TUI_ROWS:-24}"
    else
        read -r r c < <(stty size </dev/tty 2>/dev/null) || true
        [[ "$c" =~ ^[0-9]+$ ]] || c="$(tput cols 2>/dev/null || true)"
        [[ "$r" =~ ^[0-9]+$ ]] || r="$(tput lines 2>/dev/null || true)"
    fi
    [[ "$c" =~ ^[0-9]+$ && "$c" -gt 0 ]] || c=80
    [[ "$r" =~ ^[0-9]+$ && "$r" -gt 0 ]] || r=24
    TUI_W_TERM="$c"; TUI_H_TERM="$r"
}

# tui_clean <text> → printable text without ANSI/control characters
tui_clean() {
    local s="$1"
    s="$(printf '%s' "$s" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b[()][A-Za-z0-9]//g' | tr -d '\000-\010\013-\037\177')"
    printf '%s' "${s//$'\t'/ }"
}

# tui_fit <text> <width> → text cut to width (with …) or padded with spaces to width
tui_fit() {
    local s="$1" w="$2"
    (( w < 1 )) && { printf ''; return; }
    if (( ${#s} > w )); then s="${s:0:w-1}…"; fi
    # pad by CHARACTERS: printf '%-*s' pads by bytes, so every accent shortened the row and the right border drifted
    printf '%s%*s' "$s" $((w - ${#s})) ''

}

tui_rep() {   # tui_rep <char> <n>
    local n="$2" out=""
    (( n > 0 )) || return 0
    printf -v out '%*s' "$n" ''
    printf '%s' "${out// /$1}"
}

# tui_rule <title> <width> → "── title ─────" exactly width columns wide
tui_rule() {
    local t="── $1 " w="$2"
    printf '%s%s%s%s' "${C_dim}" "$t" "$(tui_rep ─ $((w - ${#t})))" "${C_reset}"
}

# --- state handling (events) -------------------------------------------------
tui_open() {
    $TUI_OPEN && return 0
    [[ -n "${TUI_COLS:-}" ]] || { [[ -r /dev/tty ]] || return 1; }
    TUI_OPEN=true
    printf '\e[?1049h\e[?25l' >&"$EV_OUT_FD"      # alternate screen, cursor hidden
    trap 'tui_draw force || true' WINCH
    tui_draw force
}

tui_close() {
    $TUI_OPEN || return 0
    TUI_OPEN=false
    trap - WINCH
    printf '\e[?25h\e[?1049l' >&"$EV_OUT_FD"      # cursor back, leave the alternate screen
}

# tui_suspend / tui_resume: give the terminal back for a prompt (diff, gum confirm, sudo password)
tui_suspend() { $TUI_OPEN && printf '\e[?25h\e[?1049l' >&"$EV_OUT_FD"; return 0; }
tui_resume()  { $TUI_OPEN && { printf '\e[?1049h\e[?25l' >&"$EV_OUT_FD"; tui_draw force; }; return 0; }

tui_handle() {
    local type="$1"; shift
    local -A kv=()
    while (( $# >= 2 )); do kv[$1]="$2"; shift 2; done
    case "$type" in
        phase)
            [[ -n "$TUI_PHASE" ]] && TUI_PHASES_DONE+=("$TUI_PHASE")
            TUI_PHASE="${kv[name]:-}"; TUI_STEP=""; TUI_PROG_DONE=0; TUI_PROG_TOTAL=0 ;;
        pkg)
            local n="${kv[name]:-}"
            [[ -n "$n" ]] || return 0
            [[ -n "${TUI_PKG_STATE[$n]:-}" ]] || TUI_PKGS+=("$n")
            TUI_PKG_STATE[$n]="${kv[state]:-}"
            [[ -n "${kv[detail]:-}" ]] && TUI_PKG_DETAIL[$n]="${kv[detail]}" ;;
        step)  TUI_STEP="$(tui_clean "${kv[msg]:-}")"; tui_push_log "» ${kv[msg]:-}" ;;
        warn)  TUI_WARNS=$((TUI_WARNS + 1)); tui_push_log "! ${kv[msg]:-}" ;;
        log)   tui_push_log "${kv[msg]:-}" ;;
        progress)
            TUI_PROG_DONE="${kv[done]:-0}"; TUI_PROG_TOTAL="${kv[total]:-0}"
            TUI_STEP="$(tui_clean "${kv[msg]:-}")"
            # the log keeps a trace of the milestones, not of every package
            if (( TUI_PROG_TOTAL == 0 || TUI_PROG_DONE == 0 || TUI_PROG_DONE % 20 == 0 || TUI_PROG_DONE == TUI_PROG_TOTAL )); then
                tui_push_log "» $( (( TUI_PROG_TOTAL > 0 )) && printf "(%s/%s) " "$TUI_PROG_DONE" "$TUI_PROG_TOTAL")${kv[msg]:-}"
            fi ;;
        done)
            [[ -n "$TUI_PHASE" ]] && TUI_PHASES_DONE+=("$TUI_PHASE")
            tui_finish "${kv[status]:-ok}" "${kv[msg]:-}"
            return 0 ;;
    esac
    tui_open || return 1
    tui_draw
}

tui_push_log() {
    local line; line="$(tui_clean "$1")"
    [[ -n "${line// /}" ]] || return 0
    TUI_LOG+=("$line")
    (( ${#TUI_LOG[@]} > 60 )) && TUI_LOG=("${TUI_LOG[@]: -40}")
    return 0
}

# --- drawing -----------------------------------------------------------------
tui_draw() {   # tui_draw [force]
    $TUI_OPEN || return 0
    local now="${EPOCHREALTIME:-0}"
    now="${now/./}"; now=$((10#${now:-0} / 1000))     # milliseconds
    if [[ "${1:-}" != force ]] && (( now - TUI_LAST_DRAW < 50 )); then TUI_DIRTY=true; return 0; fi
    TUI_LAST_DRAW=$now; TUI_DIRTY=false
    local buf="" line
    local -a lines=()
    mapfile -t lines < <(tui_frame)
    buf=$'\e[H'
    for line in "${lines[@]}"; do buf+="$line"$'\e[K\n'; done
    buf+=$'\e[J'
    printf '%s' "$buf" >&"$EV_OUT_FD"
}

tui_phase_bar() {   # tui_phase_bar <width> → one line; sets TUI_BAR_LEN (visible length)
    local w="$1" p out="" plain="" sep=" · " mark done_mark=true i=0 idx=0 n=${#EV_PHASES[@]}
    local total=$(( (n - 1) * 3 + 2 ))
    for p in "${EV_PHASES[@]}"; do
        total=$((total + ${#p}))
        [[ " ${TUI_PHASES_DONE[*]} " == *" $p "* ]] && total=$((total + 2))
    done
    if (( total > w )); then
        # too narrow for the whole bar: only the current phase and its position
        for p in "${EV_PHASES[@]}"; do i=$((i + 1)); [[ "$p" == "$TUI_PHASE" ]] && idx=$i; done
        plain="[${TUI_PHASE:-…}] $idx/$n"
        TUI_BAR_LEN=${#plain}
        printf '%s%s%s%s' "${C_bold}" "${C_magenta}" "$plain" "${C_reset}"
        return 0
    fi
    i=0
    for p in "${EV_PHASES[@]}"; do
        (( i > 0 )) && { out+="${C_dim}${sep}${C_reset}"; plain+="$sep"; }
        mark=""
        if [[ "$p" == "$TUI_PHASE" ]]; then
            out+="${C_bold}${C_magenta}[$p]${C_reset}"; plain+="[$p]"
        elif [[ " ${TUI_PHASES_DONE[*]} " == *" $p "* ]]; then
            mark="✔ "
            out+="${C_green}$mark$p${C_reset}"; plain+="$mark$p"
        else
            out+="${C_dim}$p${C_reset}"; plain+="$p"
        fi
        i=$((i + 1))
    done
    TUI_BAR_LEN=${#plain}
    printf '%s' "$out"
}

tui_icon() {   # tui_icon <state> → coloured icon (1 column)
    case "$1" in
        installed) printf '%s✔%s' "${C_dim}" "${C_reset}" ;;
        install)   printf '%s↓%s' "${C_cyan}" "${C_reset}" ;;
        aur)       printf '%s◆%s' "${C_violet}" "${C_reset}" ;;
        conflict|failed) printf '%s✖%s' "${C_red}" "${C_reset}" ;;
        running)   printf '%s…%s' "${C_amber}" "${C_reset}" ;;
        ok)        printf '%s✔%s' "${C_green}" "${C_reset}" ;;
        *)         printf '·' ;;
    esac
}

tui_state_label() {
    case "$1" in
        installed) echo "instalado" ;; install) echo "a instalar" ;; aur) echo "AUR" ;;
        conflict) echo "conflicto" ;; running) echo "instalando" ;; ok) echo "listo" ;; failed) echo "falló" ;;
        *) echo "$1" ;;
    esac
}

# tui_counts → sets TUI_N_TOTAL TUI_N_DONE (installed + ok count as done)
tui_counts() {
    local n s
    TUI_N_TOTAL=${#TUI_PKGS[@]}; TUI_N_DONE=0
    for n in "${TUI_PKGS[@]}"; do
        s="${TUI_PKG_STATE[$n]}"
        if [[ "$s" == installed || "$s" == ok ]]; then TUI_N_DONE=$((TUI_N_DONE + 1)); fi
    done
    return 0
}

# tui_frame → prints the whole frame (one line per output line), centred, never taller than the terminal
tui_frame() {
    tui_size
    local cols="$TUI_W_TERM" rows="$TUI_H_TERM"
    local W=$((cols - 2))
    (( W > TUI_MAXW )) && W=$TUI_MAXW
    (( W < TUI_MINW )) && W=$TUI_MINW
    local M=$(( (cols - W) / 2 )); (( M < 0 )) && M=0
    local pad; pad="$(tui_rep ' ' "$M")"
    local -a out=()
    local inner=$((W - 4))
    local title="$TUI_NAME · Instalador" ver="${TUI_VERSION:+v${TUI_VERSION#v}}"
    local gap=$((inner - ${#title} - ${#ver})); (( gap < 1 )) && gap=1
    out+=("${C_magenta}╭$(tui_rep ─ $((W - 2)))╮${C_reset}")
    out+=("${C_magenta}│${C_reset} ${C_bold}${C_text}$(tui_fit "$title$(tui_rep ' ' "$gap")$ver" "$inner")${C_reset} ${C_magenta}│${C_reset}")
    out+=("${C_magenta}╰$(tui_rep ─ $((W - 2)))╯${C_reset}")
    # phase bar, centred inside the content width
    local bar; bar="$(tui_phase_bar "$W")"
    tui_phase_bar "$W" >/dev/null
    local bl=${TUI_BAR_LEN:-0}
    out+=("")
    out+=("$(tui_rep ' ' $(( (W - bl) / 2 > 0 ? (W - bl) / 2 : 0 )))$bar")
    out+=("")
    out+=("${C_cyan}›${C_reset} ${C_text}$(tui_fit "${TUI_STEP:-${TUI_PHASE:-Preparando…}}" $((W - 2)))${C_reset}")
    # budget for the two variable panels
    local fixed=${#out[@]}
    fixed=$((fixed + 1 + 1 + 1 + 1 + 1))   # table title, progress, blank, log title, bottom margin
    local avail=$((rows - 1 - fixed - 2))   # keep 2 rows free for prompts
    (( avail < 4 )) && avail=4
    local T=$(( avail * 6 / 10 )); (( T < 2 )) && T=2
    local L=$(( avail - T )); (( L < 2 )) && L=2
    tui_counts
    if (( TUI_N_TOTAL == 0 )); then out+=("$(tui_rule "Paquetes · comprobando…" "$W")")
    else out+=("$(tui_rule "Paquetes ($TUI_N_DONE/$TUI_N_TOTAL)" "$W")"); fi
    # table window: keep the running package (or the last changed) visible
    local start=0 total=${#TUI_PKGS[@]} i n
    local focus=$((total - 1))
    for i in "${!TUI_PKGS[@]}"; do [[ "${TUI_PKG_STATE[${TUI_PKGS[$i]}]}" == running ]] && { focus=$i; break; }; done
    if (( total > T )); then start=$((focus - T / 2)); (( start < 0 )) && start=0; (( start > total - T )) && start=$((total - T)); fi
    local namew=$((W - 4 - 14 - 12)); (( namew < 14 )) && namew=14
    local shown=0 st detail
    for (( i = start; i < total && shown < T; i++ )); do
        n="${TUI_PKGS[$i]}"; st="${TUI_PKG_STATE[$n]}"; detail="${TUI_PKG_DETAIL[$n]:-}"
        out+=("  $(tui_icon "$st") $(tui_fit "$n" "$namew") ${C_dim}$(tui_fit "$detail" 14) $(tui_fit "$(tui_state_label "$st")" 10)${C_reset}")
        shown=$((shown + 1))
    done
    (( total == 0 )) && { out+=("  ${C_dim}Comprobando el sistema; los paquetes aparecen al terminar…${C_reset}"); shown=1; }
    while (( shown < T )); do out+=(""); shown=$((shown + 1)); done
    # progress bar
    local bw=$((W - 22)); (( bw < 8 )) && bw=8
    local pct=0 fill=0 label="$TUI_N_DONE/$TUI_N_TOTAL"
    if (( TUI_N_TOTAL > 0 )); then pct=$((TUI_N_DONE * 100 / TUI_N_TOTAL)); fill=$((bw * TUI_N_DONE / TUI_N_TOTAL))
    elif (( TUI_PROG_TOTAL > 0 )); then pct=$((TUI_PROG_DONE * 100 / TUI_PROG_TOTAL)); fill=$((bw * TUI_PROG_DONE / TUI_PROG_TOTAL)); label="$TUI_PROG_DONE/$TUI_PROG_TOTAL"
    else label="…"; fi
    out+=("  ${C_cyan}$(tui_rep █ "$fill")${C_dim}$(tui_rep ░ $((bw - fill)))${C_reset} $(printf '%3d%%' "$pct")  $label")
    out+=("$(tui_rule Registro "$W")")
    local ln=${#TUI_LOG[@]} from=$(( ${#TUI_LOG[@]} - L )); (( from < 0 )) && from=0
    shown=0
    for (( i = from; i < ln; i++ )); do
        out+=("  ${C_dim}$(tui_fit "${TUI_LOG[$i]}" $((W - 2)))${C_reset}"); shown=$((shown + 1))
    done
    while (( shown < L )); do out+=(""); shown=$((shown + 1)); done
    # never taller than the terminal minus one row, every line indented by the margin
    local count=0 line
    for line in "${out[@]}"; do
        (( count >= rows - 1 )) && break
        printf '%s%s\n' "$pad" "$line"
        count=$((count + 1))
    done
}

# --- final summary -----------------------------------------------------------
# tui_wrap <width> <text> → the text broken at spaces into lines of at most <width> columns. Continuation lines keep the indentation
# of the first one plus two spaces (a hanging indent), so a long path or command never breaks the frame and never loses characters.
tui_wrap() {
    local w="$1" line="$2" indent lead rest chunk first=true
    lead="${line%%[! ]*}"; indent="$lead"
    (( ${#indent} > w / 2 )) && indent=""
    while (( ${#line} > w )); do
        chunk="${line:0:w}"
        if [[ "${line:w:1}" == " " ]]; then :           # the cut falls right on a space
        elif [[ "${chunk#"${chunk%%[! ]*}"}" == *" "* ]]; then chunk="${chunk% *}"
        fi                                              # no space to break at: break inside the word
        printf '%s\n' "$chunk"
        rest="${line:${#chunk}}"; rest="${rest# }"
        first=false
        line="${indent}  ${rest}"
        (( ${#indent} + 2 >= w )) && line="$rest"
    done
    printf '%s\n' "$line"
}

# tui_box <colour> <line>... → rounded frame centred in the terminal. Every row is exactly the same width (right border aligned).
tui_box() {
    local colour="$1"; shift
    tui_size
    local W=$((TUI_W_TERM - 2)); (( W > TUI_MAXW )) && W=$TUI_MAXW; (( W < TUI_MINW )) && W=$TUI_MINW
    local M=$(( (TUI_W_TERM - W) / 2 )); (( M < 0 )) && M=0
    local pad; pad="$(tui_rep ' ' "$M")"
    local inner=$((W - 4)) line chunk
    printf '%s%s╭%s╮%s\n' "$pad" "$(tui_c "$colour")" "$(tui_rep ─ $((W - 2)))" "${C_reset}"
    for line in "$@"; do
        line="$(tui_clean "$line")"
        while IFS= read -r chunk; do
            printf '%s%s│%s %s%s%s %s│%s\n' "$pad" "$(tui_c "$colour")" "${C_reset}" "${C_text}" \
                "$(tui_fit "$chunk" "$inner")" "${C_reset}" "$(tui_c "$colour")" "${C_reset}"
        done < <(tui_wrap "$inner" "$line")
    done
    printf '%s%s╰%s╯%s\n' "$pad" "$(tui_c "$colour")" "$(tui_rep ─ $((W - 2)))" "${C_reset}"
}

# tui_finish <status> <message>: leave the live frame and print the framed summary on the normal screen
tui_finish() {
    local status="$1" msg="$2" colour=green title n s
    case "$status" in warn|pause) colour=amber ;; error) colour=red ;; esac
    tui_close
    local -a lines=()
    case "$status" in
        dry-run) title="Simulación terminada (dry-run): no se cambió nada" ;;
        error)   title="La instalación se detuvo" ;;
        pause)   title="Instalación en pausa: hace falta reiniciar" ;;
        warn)    title="Instalación terminada con avisos" ;;
        *)       title="Instalación terminada" ;;
    esac
    lines+=("$title" "")
    tui_counts
    # one honest line: what was already there, what is new (or would be), what was left out, what really failed
    local c_inst=0 c_new=0 c_fail=0 c_skip=0 problems=()
    for n in "${TUI_PKGS[@]}"; do
        s="${TUI_PKG_STATE[$n]}"
        case "$s" in
            installed) c_inst=$((c_inst + 1)) ;;
            ok|install|aur|running) c_new=$((c_new + 1)) ;;
            failed|conflict) c_fail=$((c_fail + 1)); problems+=("$n: ${TUI_PKG_DETAIL[$n]:-sin detalle (ver el informe)}") ;;
        esac
    done
    local verb="instalados"; [[ "$status" == dry-run ]] && verb="por instalar"
    if (( TUI_N_TOTAL > 0 )); then
        lines+=("Paquetes: $c_inst ya estaban · $c_new $verb · $c_fail con problema")
        for n in "${problems[@]}"; do lines+=("  ✖ $n"); done
        lines+=("")
    fi
    lines+=("Avisos: $TUI_WARNS" "")
    local l
    while IFS= read -r l; do lines+=("$l"); done <<<"$msg"
    tui_box "$colour" "${lines[@]}" >&"$EV_OUT_FD"
}
