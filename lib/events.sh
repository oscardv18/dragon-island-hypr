#!/usr/bin/env bash
# shellcheck disable=SC2034  # EV_* are read by install.sh and lib/tui.sh
# =============================================================================
# dragon-island — installer events (sourced). The ENGINE emits events; a SINK draws them.
#   ev_phase <name>                  a phase begins (Preflight Plan Paquetes Despliegue Servicios Verificación)
#   ev_pkg   <name> <state> [extra]  state: installed | install | aur | conflict | running | ok | failed
#   ev_step  <message>               something is being done
#   ev_warn  <message>               something the user should read
#   ev_log   <message>               one line of command output (log panel only)
#   ev_done  <status> <message>      end of the run (status: ok | warn | error | dry-run)
# Sinks: plain (linear text) · json (one JSON object per line) · tui (lib/tui.sh, draws only).
# A sink never runs commands. If the TUI sink fails once, the run continues with the plain sink.
# =============================================================================
EV_SINK="${EV_SINK:-plain}"
EV_OUT_FD="${EV_OUT_FD:-1}"        # where plain/json lines go (the original stdout, even when the run is logged)
EV_PHASES=(Preflight Plan Paquetes Despliegue Servicios Verificación)

# ev_json_escape <text> → JSON string body (no surrounding quotes)
ev_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
    # any other control character → space (keeps the line valid JSON)
    s="$(printf '%s' "$s" | tr '\000-\010\013\014\016-\037' ' ')"
    printf '%s' "$s"
}

# ev_emit <type> [key value]...   — single entry point, used by the wrappers below
ev_emit() {
    local type="$1"; shift
    case "$EV_SINK" in
        json)  ev_sink_json "$type" "$@" ;;
        tui)   tui_handle "$type" "$@" || ev_tui_failed ;;
        *)     ev_sink_plain "$type" "$@" ;;
    esac
    return 0
}

ev_sink_json() {
    local type="$1"; shift
    local out="{\"event\":\"$type\""
    while (( $# >= 2 )); do
        out+=",\"$1\":\"$(ev_json_escape "$2")\""; shift 2
    done
    printf '%s}\n' "$out" >&"$EV_OUT_FD"
}

ev_sink_plain() {
    local type="$1"; shift
    local -A kv=()
    while (( $# >= 2 )); do kv[$1]="$2"; shift 2; done
    case "$type" in
        phase) printf '\n== %s ==\n' "${kv[name]:-}" ;;
        pkg)   printf '  %-9s %s%s\n' "[${kv[state]:-}]" "${kv[name]:-}" "${kv[detail]:+ (${kv[detail]})}" ;;
        step)  printf ':: %s\n' "${kv[msg]:-}" ;;
        warn)  printf ':: AVISO: %s\n' "${kv[msg]:-}" ;;
        log)   printf '   %s\n' "${kv[msg]:-}" ;;
        done)  printf '\n== %s ==\n%s\n' "${kv[status]:-}" "${kv[msg]:-}" ;;
        *)     printf ':: %s %s\n' "$type" "${kv[msg]:-}" ;;
    esac >&"$EV_OUT_FD"
}

# A TUI failure must never break the installation: close it and keep going in plain text.
ev_tui_failed() {
    declare -F tui_close >/dev/null && tui_close || true
    EV_SINK=plain
    printf ':: AVISO: la interfaz de terminal falló; se sigue en modo texto (--plain).\n' >&"$EV_OUT_FD"
}

ev_phase() { ev_emit phase name "$1"; }
ev_pkg()   { ev_emit pkg name "$1" state "$2" detail "${3:-}"; }
ev_step()  { ev_emit step msg "$1"; }
ev_warn()  { ev_emit warn msg "$1"; }
ev_log()   { ev_emit log msg "$1"; }
ev_done()  { ev_emit "done" status "$1" msg "$2"; }

# ev_stream <level>: reads command output from stdin and turns each line into an ev_log event
# (needs `shopt -s lastpipe` in the caller so state set by the reader survives the pipe)
ev_stream() {
    local line
    while IFS= read -r line; do ev_log "$line"; done
}
