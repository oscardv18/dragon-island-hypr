#!/usr/bin/env bash
# shellcheck disable=SC2034  # REPORT_PATH_SHOWN is read by install.sh
# =============================================================================
# dragon-island — final report (sourced by install.sh). ~/dragon-informe.txt is written when the run ends OR fails, so nobody has
# to collect logs by hand. It never contains passwords, tokens or environment variables; the home folder is shown as «~».
# Nothing is written in --dry-run (a simulation leaves no trace).
# =============================================================================
declare -a REPORT_CHECKS=()      # "<ok|aviso|fallo> <text>"
declare -a REPORT_ISSUES=()      # plan issues: "[action] subject — why → what the installer does"
declare -a REPORT_PROBLEMS=()    # packages with a problem and its cause
REPORT_WRITTEN=false

# report_sanitize: stdin → stdout without secrets and without the home path
report_sanitize() {
    local home_re; home_re="$(printf '%s' "$HOME" | sed 's/[][\.*^$|/]/\\&/g')"
    sed -E \
        -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
        -e "s|$home_re|~|g" \
        -e 's/((pass(word|wd)?|token|secret|api[_-]?key|authorization|bearer|cookie|credential)[A-Za-z_]*[ ]*[=:][ ]*)[^[:space:]"'"'"']+/\1«oculto»/Ig' \
        -e 's/(Bearer|Basic) [A-Za-z0-9._~+\/=-]{8,}/\1 «oculto»/g' \
        -e 's/(ghp_|gho_|github_pat_|sk-|xox[bp]-)[A-Za-z0-9_-]{8,}/«oculto»/g' \
        -e 's#(https?://)[^/@[:space:]]+:[^@[:space:]]+@#\1«oculto»@#g' \
        | tr -d '\000-\010\013\014\016-\037'
}

report_version_of() { local v; v="$(pacman -Q "$1" 2>/dev/null | awk '{print $2}')"; printf '%s' "${v:-no instalado}"; }

report_path() { printf '%s/dragon-informe.txt\n' "$HOME"; }

# report_write <status> <message>
report_write() {
    $DRY_RUN && return 0
    $REPORT_WRITTEN && return 0
    local status="$1" message="$2" file tmp commit
    file="$(report_path)"; tmp="$(mktemp "${TMPDIR:-/tmp}/dragon-informe.XXXXXX")" || return 0
    commit="$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || true)"
    detect_distro 2>/dev/null || true; detect_virt 2>/dev/null || true; detect_gpu 2>/dev/null || true
    {
        trap - ERR      # probes of absent tools may fail: the report must never raise the installer's error trap
        echo "Dragon Island — informe del instalador"
        echo "Fecha:        $(date '+%Y-%m-%d %H:%M:%S %z')"
        echo "Resultado:    $status"
        echo "Fase / paso:  ${EV_LAST_PHASE:-—} / ${EV_LAST_STEP:-—}"
        echo
        echo "== Versiones =="
        echo "Instalador:   ${TUI_VERSION:-?}${commit:+ ($commit)}"
        echo "Distro:       ${DISTRO_NAME:-?}"
        echo "Kernel:       $(uname -r) · instalado: $(prereq_q kernel 2>/dev/null || echo ?)"
        echo "Entorno:      ${VIRT_KIND:-none}"
        echo "GPU:          ${GPU_VENDOR:-?} ${GPU_NAME:-}"
        echo "Pacman:       $(pacman --version 2>/dev/null | sed -n 's/.*\(Pacman v[0-9.]*\).*/\1/p' | head -n1)"
        echo "Ayudante AUR: ${AUR_HELPER:-ninguno}${AUR_HELPER:+ $("$AUR_HELPER" --version 2>/dev/null | head -n1)}"
        local p; for p in hyprland quickshell neovim docker sddm gnome-keyring; do echo "$p: $(report_version_of "$p")"; done
        echo
        echo "== Comprobaciones =="
        if (( ${#REPORT_CHECKS[@]} )); then printf '  %s\n' "${REPORT_CHECKS[@]}"; else echo "  (no llegaron a ejecutarse)"; fi
        echo
        echo "== Incidencias del plan =="
        if (( ${#REPORT_ISSUES[@]} )); then printf '  %s\n' "${REPORT_ISSUES[@]}"; else echo "  ninguna"; fi
        echo
        echo "== Paquetes con problema y su causa =="
        if (( ${#REPORT_PROBLEMS[@]} )); then printf '  %s\n' "${REPORT_PROBLEMS[@]}"; else echo "  ninguno"; fi
        echo
        echo "== Resumen =="
        printf '%s\n' "$message"
        echo
        echo "== Cola del registro (últimas 80 líneas) =="
        local log="${LOG:-}"
        [[ "$log" == /dev/null ]] && log=""
        [[ -n "$log" && -f "$log" ]] || log="${STATE_DIR:-}/install.log"
        if [[ -f "$log" ]]; then tail -n 80 "$log"; else echo "(sin registro)"; fi
    } 2>/dev/null | report_sanitize > "$tmp"
    chmod 600 "$tmp"
    if mv -f "$tmp" "$file" 2>/dev/null || cp -f "$tmp" "$file" 2>/dev/null; then
        REPORT_WRITTEN=true; rm -f "$tmp"
        local tilde='~'
        REPORT_PATH_SHOWN="${file/#"$HOME"/$tilde}"
        ev_log "Informe escrito en: $REPORT_PATH_SHOWN"
    else rm -f "$tmp"; fi
    return 0
}
