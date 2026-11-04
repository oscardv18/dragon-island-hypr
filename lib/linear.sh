#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2024  # variables read by install.sh; sudo reads the terminal on purpose (its ticket is per tty)
# =============================================================================
# dragon-island — helpers of the LINEAR installer (sourced by install.sh). No events, no TUI, no JSON, no hidden state machine:
# each function does one thing, prints through lib/ui.sh and returns; install.sh calls them in order.
# Needs: common.sh, detect.sh, ui.sh. Nothing here aborts the run: a failed step is recorded and the next one still runs.
# =============================================================================
declare -A RESULT=()          # module → ok | con avisos | fallido (...) | omitido (...)
declare -A PKG_CAUSE=()       # package → why it did not end up installed
declare -a OFF_ALL=() AUR_ALL=() OFF_MISSING=() AUR_MISSING=() PKG_FAILED=() PKG_SKIPPED=()
declare -a MODULE_PROBLEMS=() MISSING_ITEMS=()
WARN_COUNT=0
EV_LAST_PHASE=""; EV_LAST_STEP=""
SUDO_PID=""
NO_UPDATE="${NO_UPDATE:-false}"

# modules count their warnings (a module that warns is «con avisos»)
log_warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    if has_gum; then gum log --level warn "$1" 2>&1 || echo ":: AVISO: $1"; else echo ":: AVISO: $1"; fi
}
# gum prompts draw on the real terminal even though stdout/stderr go through the log (a pipe): its answer still comes on stdout
gum() {
    case "${1:-}" in
        choose|input|confirm|filter|write) have_tty && { command gum "$@" </dev/tty 2>/dev/tty; return; } ;;
    esac
    command gum "$@"
}
ev_log() { printf '%s\n' "$1"; }
ev_step() { EV_LAST_STEP="$1"; }

lin_phase() { EV_LAST_PHASE="$2"; EV_LAST_STEP="$2"; ui_phase "$1" "$PHASES_TOTAL" "$2"; }
lin_step() { EV_LAST_STEP="$1"; }

# --- log: everything printed goes to the screen AND to ~/dragon-install.log (a fifo + tee, no subshell for the script itself) ---
lin_log_start() {
    exec 3>&1 4>&2
    if $DRY_RUN; then LOG=/dev/null; return 0; fi
    LOG="$HOME/dragon-install.log"
    { printf '\n===== %s · dragon-island %s =====\n' "$(date '+%F %T')" "${VERSION_TEXT:-?}"; } >> "$LOG" 2>/dev/null || { LOG=/dev/null; return 0; }
    local fifo; fifo="$(mktemp -u "${TMPDIR:-/tmp}/dragon-log.XXXXXX")"
    mkfifo "$fifo" 2>/dev/null || return 0
    tee -a "$LOG" <"$fifo" >&3 &
    TEE_PID=$!
    exec >"$fifo" 2>&1
    rm -f "$fifo"
}
TEE_PID=""
lin_log_stop() {
    [[ -n "$TEE_PID" ]] || return 0
    exec >&3 2>&4
    local i
    for i in $(seq 1 30); do kill -0 "$TEE_PID" 2>/dev/null || break; sleep 0.1; done
    TEE_PID=""
}

# --- sudo: ONE password for the whole run, kept alive in the background, closed on exit ---------------------------------------
# The keep-alive sees the real terminal: sudo keeps one ticket per tty and a loop with another stdin renews a different one.
sudo_begin() {
    $DRY_RUN && return 0
    $NO_SUDO && return 1
    if ! sudo -n -v 2>/dev/null; then
        have_tty || { ui_fail "sudo necesita tu clave y no hay terminal donde escribirla. Ejecuta ./install.sh desde una terminal."; return 1; }
        ui_note "Escribe tu clave de administrador (se pide una sola vez en toda la instalación)."
        sudo -v </dev/tty || return 1
    fi
    local parent=$$
    if have_tty; then
        ( while sleep 50; do kill -0 "$parent" 2>/dev/null || exit; sudo -n -v </dev/tty >/dev/null 2>&1 || true; done ) >/dev/null 2>&1 &
    else
        ( while sleep 50; do kill -0 "$parent" 2>/dev/null || exit; sudo -n -v >/dev/null 2>&1 || true; done ) >/dev/null 2>&1 </dev/null &
    fi
    SUDO_PID=$!
    return 0
}
# sudo_ensure: before a long step. Silent while the ticket is valid; asks again (on the terminal) only if it was lost.
sudo_ensure() {
    $DRY_RUN && return 0
    $NO_SUDO && return 1
    if have_tty; then sudo -n -v </dev/tty 2>/dev/null && return 0; else sudo -n -v 2>/dev/null && return 0; fi
    have_tty || return 1
    sudo -v </dev/tty
}
sudo_end() {
    if [[ -n "$SUDO_PID" ]]; then pkill -P "$SUDO_PID" 2>/dev/null || true; kill "$SUDO_PID" 2>/dev/null || true; SUDO_PID=""; sudo -n -k 2>/dev/null || true; fi
}

# run_capture <outfile> <command>...: the command's real output is shown AND kept in <outfile>; returns its exit code
run_capture() {
    local out="$1" rc=0; shift
    "$@" 2>&1 | tee "$out"
    rc=${PIPESTATUS[0]}
    return "$rc"
}
first_error() {   # first_error <file>: the most telling line of a failed command
    local l
    l="$(grep -E -i -m1 '(error|failed|fall[óo]|could not|no se pudo|unable|==> ERROR|not found)' "$1" 2>/dev/null | cut -c1-140 || true)"
    printf '%s' "${l:-terminó con error (ver ~/dragon-install.log)}"
}

# --- scan -------------------------------------------------------------------------------------------------------------------------------
manifest() { PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/manifest.py" "$@"; }

# scan_packages: what the profiles need against what is installed (pacman -T respects providers: nodejs-lts-*, rustup…)
scan_packages() {
    local mods; mods="$(IFS=,; echo "${SELECTED[*]}")"
    mapfile -t OFF_ALL < <(manifest --source pacman --modules "$mods") || return 1
    mapfile -t AUR_ALL < <(manifest --source aur --modules "$mods") || return 1
    PROFILES_TEXT="$(manifest --source profiles --modules "$mods" | sed 's/,/, /g')"
    (( ${#OFF_ALL[@]} > 0 )) || { ui_fail "No se pudo leer packages/profiles.json (manifiesto vacío)."; return 1; }
    local t
    OFF_MISSING=(); AUR_MISSING=()
    t="$(package_targets "${OFF_ALL[@]}")" || return 1
    [[ -z "$t" ]] || mapfile -t OFF_MISSING <<<"$t"
    if (( ${#AUR_ALL[@]} > 0 )); then
        t="$(package_targets "${AUR_ALL[@]}")" || return 1
        [[ -z "$t" ]] || mapfile -t AUR_MISSING <<<"$t"
    fi
    return 0
}

# pkg_known <name>: the name exists in the synced repositories (pacman -Si, or a provider/group through -Sp)
pkg_known() { pacman -Si -- "$1" >/dev/null 2>&1 || pacman -Sp -- "$1" >/dev/null 2>&1; }

# --- official packages: ONE sudo pacman call; when it fails, find the culprit(s) and go on with the rest ---------------------------------
install_official() {
    local want=("${OFF_MISSING[@]}") out rc=0 p flags=(-Syu)
    $NO_UPDATE && flags=(-S)
    if (( ${#want[@]} == 0 )); then ui_ok "Paquetes oficiales: ya estaba todo instalado (${#OFF_ALL[@]})."; return 0; fi
    ui_note "Se instalan ${#want[@]} paquetes oficiales de una vez (sudo pacman ${flags[*]} --needed --noconfirm …)."
    if $DRY_RUN; then
        echo "[dry-run] sudo pacman ${flags[*]} --needed --noconfirm ${want[*]}"
        return 0
    fi
    if $NO_SUDO; then
        ui_warn "Sin sudo (--no-sudo): hazlo a mano:  sudo pacman -S --needed ${want[*]}"
        MANUAL_ITEMS+=("Paquetes oficiales: sudo pacman -S --needed ${want[*]}")
        for p in "${want[@]}"; do PKG_CAUSE[$p]="omitido: --no-sudo"; done
        return 0
    fi
    if ! sudo_ensure; then ui_fail "sudo no está autorizado: no se instalan los paquetes oficiales."; for p in "${want[@]}"; do PKG_CAUSE[$p]="sudo no autorizado"; done; return 1; fi
    out="$(mktemp)"
    run_capture "$out" sudo pacman "${flags[@]}" --needed --noconfirm "${want[@]}" || rc=$?
    if (( rc != 0 )); then
        ui_warn "pacman terminó con error ($rc); se busca el paquete culpable y se sigue con el resto."
        # 1) names that do not exist in the repositories (validated with pacman -Si, never dumped)
        local rest=() unknown=()
        for p in "${want[@]}"; do
            if pkg_known "$p"; then rest+=("$p"); else unknown+=("$p"); PKG_CAUSE[$p]="no existe en los repositorios (pacman -Si no lo encuentra)"; fi
        done
        (( ${#unknown[@]} == 0 )) || ui_fail "No existen en los repositorios: ${unknown[*]}"
        rc=0
        if (( ${#unknown[@]} > 0 && ${#rest[@]} > 0 )); then
            # the unknown name was the only problem: the same transaction without it (it also does the system upgrade)
            ui_note "Se repite la instalación sin los que no existen."
            run_capture "$out" sudo pacman "${flags[@]}" --needed --noconfirm "${rest[@]}" || rc=$?
        else rc=1; fi
        # 2) still failing: one by one, to isolate the culprit
        if (( rc != 0 && ${#rest[@]} > 0 )); then
            ui_note "Se instala uno a uno para aislar el que falla."
            for p in "${rest[@]}"; do
                sudo_ensure || true
                pacman -T -- "$p" >/dev/null 2>&1 && continue
                run_capture "$out" sudo pacman -S --needed --noconfirm "$p" || PKG_CAUSE[$p]="$(first_error "$out")"
            done
        fi
    fi
    rm -f "$out"
    return 0
}

# --- AUR: the detected helper (paru on CachyOS, yay otherwise). A failing package is noted and the rest go on ------------------------
install_aur() {
    local want=() t p out rc=0
    if (( ${#AUR_ALL[@]} > 0 )); then
        t="$(package_targets "${AUR_ALL[@]}")" || return 1
        [[ -z "$t" ]] || mapfile -t want <<<"$t"
    fi
    if (( ${#want[@]} == 0 )); then ui_ok "Paquetes AUR: ya estaba todo instalado (${#AUR_ALL[@]})."; return 0; fi
    if [[ -z "$AUR_HELPER" ]]; then
        ui_fail "No hay ayudante AUR (ni paru ni yay): no se pueden instalar ${#want[@]} paquetes."
        ui_note "Instala paru y repite ./install.sh:"
        ui_note "  sudo pacman -S --needed base-devel git && git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && (cd /tmp/paru-bin && makepkg -si)"
        ui_note "o instálalos a mano con:  paru -S --needed ${want[*]}"
        MANUAL_ITEMS+=("AUR pendientes (sin ayudante): instala paru y ejecuta  paru -S --needed ${want[*]}")
        for p in "${want[@]}"; do PKG_CAUSE[$p]="no hay ayudante AUR (paru/yay)"; done
        $DRY_RUN && echo "[dry-run] se necesitaría un ayudante AUR"
        return 0
    fi
    ui_note "Con $AUR_HELPER (compila en esta máquina y puede tardar): ${#want[@]} paquetes."
    if $DRY_RUN; then echo "[dry-run] $AUR_HELPER -S --needed --noconfirm ${want[*]}"; return 0; fi
    if $NO_SUDO; then
        ui_warn "Sin sudo (--no-sudo): hazlo a mano:  $AUR_HELPER -S --needed ${want[*]}"
        MANUAL_ITEMS+=("Paquetes AUR: $AUR_HELPER -S --needed ${want[*]}")
        for p in "${want[@]}"; do PKG_CAUSE[$p]="omitido: --no-sudo"; done
        return 0
    fi
    sudo_ensure || { ui_fail "sudo no está autorizado: no se instalan los AUR."; for p in "${want[@]}"; do PKG_CAUSE[$p]="sudo no autorizado"; done; return 1; }
    out="$(mktemp)"
    run_capture "$out" "$AUR_HELPER" -S --needed --noconfirm "${want[@]}" || rc=$?
    t="$(package_targets "${want[@]}")" || t="${want[*]}"
    local left=(); [[ -z "$t" ]] || mapfile -t left <<<"$t"
    if (( ${#left[@]} > 0 )); then
        if (( rc == 0 )); then
            for p in "${left[@]}"; do PKG_CAUSE[$p]="$AUR_HELPER terminó con éxito pero el paquete no quedó instalado"; done
        else
            ui_warn "$AUR_HELPER terminó con error ($rc); se prueba cada paquete que falta por separado."
            for p in "${left[@]}"; do
                sudo_ensure || true
                run_capture "$out" "$AUR_HELPER" -S --needed --noconfirm "$p" || true
                pkg_installed "$p" || PKG_CAUSE[$p]="$(first_error "$out")"
            done
        fi
    fi
    rm -f "$out"
    return 0
}

# verify_packages: the counts come from pacman, never from supposing success. Fills PKG_FAILED / PKG_SKIPPED and the counters.
N_OFF_NEW=0; N_AUR_NEW=0; N_OFF_BAD=0; N_AUR_BAD=0
verify_packages() {
    $DRY_RUN && return 0
    local t p cause still_off=() still_aur=()
    PKG_FAILED=(); PKG_SKIPPED=()
    t="$(package_targets "${OFF_ALL[@]}")" || t=""; [[ -z "$t" ]] || mapfile -t still_off <<<"$t"
    if (( ${#AUR_ALL[@]} > 0 )); then t="$(package_targets "${AUR_ALL[@]}")" || t=""; [[ -z "$t" ]] || mapfile -t still_aur <<<"$t"; fi
    N_OFF_BAD=${#still_off[@]}; N_AUR_BAD=${#still_aur[@]}
    N_OFF_NEW=$(( ${#OFF_MISSING[@]} - N_OFF_BAD )); N_AUR_NEW=$(( ${#AUR_MISSING[@]} - N_AUR_BAD ))
    (( N_OFF_NEW >= 0 )) || N_OFF_NEW=0; (( N_AUR_NEW >= 0 )) || N_AUR_NEW=0
    for p in "${still_off[@]}" "${still_aur[@]}"; do
        cause="${PKG_CAUSE[$p]:-no quedó instalado (ver ~/dragon-install.log)}"
        if [[ "$cause" == omitido:* ]]; then PKG_SKIPPED+=("$p — ${cause#omitido: }"); else PKG_FAILED+=("$p — $cause"); fi
    done
    REPORT_PROBLEMS=("${PKG_FAILED[@]}")
    return 0
}

# show_package_result <kind>: ✔ the ones that now are installed, ✘ the ones that are not (with their cause)
show_package_result() {
    local kind="$1" all=() missing=() ok=() p t
    if [[ "$kind" == off ]]; then all=("${OFF_MISSING[@]}"); else all=("${AUR_MISSING[@]}"); fi
    (( ${#all[@]} > 0 )) || return 0
    $DRY_RUN && { ui_pkgs skip "${all[@]}"; return 0; }
    t="$(package_targets "${all[@]}")" || t=""; [[ -z "$t" ]] || mapfile -t missing <<<"$t"
    for p in "${all[@]}"; do [[ " ${missing[*]} " == *" $p "* ]] || ok+=("$p"); done
    (( ${#ok[@]} == 0 )) || ui_pkgs ok "${ok[@]}"
    for p in "${missing[@]}"; do
        if [[ "${PKG_CAUSE[$p]:-}" == omitido:* ]]; then ui_skip "$p — ${PKG_CAUSE[$p]#omitido: }"
        else ui_fail "$p — ${PKG_CAUSE[$p]:-no quedó instalado (ver ~/dragon-install.log)}"; fi
    done
}

# --- modules ---------------------------------------------------------------------------------------------------------------------------
# res_set <module> <ok|con avisos|fallido (...)>: only ever gets worse (a later phase cannot hide an earlier failure)
res_set() {
    local m="$1" new="$2" cur="${RESULT[$1]:-}"
    case "$cur" in fallido*) return 0 ;; esac
    if [[ "$cur" == "con avisos"* && "$new" == ok ]]; then return 0; fi
    RESULT[$m]="$new"
}

# run_mod <module> <function> [label] [quiet]: a failing function is recorded and never stops the others.
# quiet: the module's own chatter (hundreds of «ln -s» lines) goes to the log; only warnings and [sudo] announcements reach the screen.
# Modules that ask something (PAM, SDDM…) are never quiet: their diff and questions must be seen.
run_mod() {
    local m="$1" fn="$2" label="${3:-$2}" quiet="${4:-}" w0=$WARN_COUNT rc=0 tmp
    declare -F "$fn" >/dev/null || return 0
    lin_step "$m: $label"
    [[ " ${DRAGON_TEST_FAIL:-} " == *" $fn "* ]] && fn=false      # test hook (tests/installer_ux/test_simple.py): force a failing step
    if [[ -n "$quiet" ]] && ! $DRY_RUN; then
        tmp="$(mktemp)"
        "$fn" >"$tmp" 2>&1 || rc=$?
        cat "$tmp" >> "$LOG" 2>/dev/null || true
        grep -E 'AVISO|WARN|ERROR|\[sudo\]' "$tmp" | sed 's/^/    /' || true
        rm -f "$tmp"
    else
        "$fn" || rc=$?
    fi
    if (( rc != 0 )); then
        res_set "$m" "fallido ($label salió con $rc)"
        MODULE_PROBLEMS+=("$m: $label falló (salida $rc)")
        ui_fail "$m — $label falló (salida $rc)"
    elif (( WARN_COUNT > w0 )); then
        res_set "$m" "con avisos"; ui_warn "$m — $label, con $((WARN_COUNT - w0)) aviso(s)"
    else
        res_set "$m" ok; ui_ok "$m — $label"
    fi
    return 0
}

# --- services --------------------------------------------------------------------------------------------------------------------------
SERVICES_OK=0
declare -a SERVICE_PROBLEMS=()
check_services() {
    local s
    SERVICES_OK=0; SERVICE_PROBLEMS=()
    for s in NetworkManager bluetooth power-profiles-daemon docker sddm; do
        [[ "$s" == docker ]] && ! pkg_installed docker && continue
        if [[ "$s" == sddm ]]; then
            case "$(display_manager)" in sddm|none) ;; *) ui_skip "gestor de acceso: $(display_manager) (se respeta; el tema de SDDM no se aplica)"; continue ;; esac
        fi
        if systemctl is-enabled --quiet "$s" 2>/dev/null || [[ "$s" == sddm && "$(display_manager)" == sddm ]]; then ui_ok "servicio $s habilitado"; SERVICES_OK=$((SERVICES_OK + 1))
        else ui_fail "servicio $s sin habilitar → sudo systemctl enable --now $s"; SERVICE_PROBLEMS+=("servicio $s sin habilitar → sudo systemctl enable --now $s"); fi
    done
    for s in pipewire pipewire-pulse wireplumber; do
        if systemctl --user is-enabled --quiet "$s" 2>/dev/null || systemctl --user is-enabled --quiet "$s.socket" 2>/dev/null; then
            ui_ok "servicio de usuario $s habilitado"; SERVICES_OK=$((SERVICES_OK + 1))
        elif in_hyprland; then ui_fail "servicio de usuario $s sin habilitar → systemctl --user enable --now $s"; SERVICE_PROBLEMS+=("servicio de usuario $s sin habilitar → systemctl --user enable --now $s")
        else ui_warn "servicio de usuario $s: se comprueba al entrar en la sesión → systemctl --user enable --now $s"; fi
    done
}

count_links() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    [[ -d "$cfg" ]] || { echo 0; return; }
    find "$cfg" "$HOME/.local/bin" "${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island" -maxdepth 3 -type l -lname "$REPO_DIR/*" 2>/dev/null | wc -l
}

# doctor_verify: doctor.sh decides how the summary reads. Fills DOCTOR_RC and MISSING_ITEMS («what» + its exact command).
DOCTOR_RC=0
doctor_verify() {
    local out; out="$(mktemp)"
    DOCTOR_RC=0; MISSING_ITEMS=()
    "${DRAGON_DOCTOR:-$REPO_DIR/doctor.sh}" --no-ask >"$out" 2>&1 || DOCTOR_RC=$?   # DRAGON_DOCTOR: test hook
    cat "$out"
    local label hint
    while IFS=$'\t' read -r label hint; do
        MISSING_ITEMS+=("$label${hint:+ → $hint}")
    done < <(sed -E 's/\x1b\[[0-9;]*m//g' "$out" | awk '
        /✘/ { if (lab != "") print lab "\t"; lab = $0; sub(/^[^✘]*✘ */, "", lab); next }
        /↳/ { if (lab != "") { h = $0; sub(/^[^↳]*↳ */, "", h); print lab "\t" h; lab = "" } next }
        END { if (lab != "") print lab "\t" }')
    rm -f "$out"
    return 0
}

human_ram() { awk '/^MemTotal:/ { printf "%.1f GiB", $2 / 1048576 }' /proc/meminfo 2>/dev/null || echo "?"; }
