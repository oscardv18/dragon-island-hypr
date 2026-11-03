#!/usr/bin/env bash
# =============================================================================
# dragon-island — modular installer (gum TUI). Arch / EndeavourOS / CachyOS.
# Requirements BEFORE running it: pre-instalation.md (check them with ./doctor.sh --pre).
# One command: ./install.sh  (diagnóstico → preparación → plan → instalación → verificación → informe).
# Modules: core (mandatory) shell editor taller archivos theme plugins login keyring keyboard boot extras — see docs/INSTALL.md.
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/install.log"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$STATE_DIR/manifest"   # lines: <action>\t<target>\t<backup-or-source>

ALL_MODULES=(core shell editor taller archivos theme plugins login keyring keyboard boot extras)
DEFAULT_MODULES=(core shell editor taller archivos theme plugins keyboard)   # login, keyring, boot and extras touch /etc, /boot or install apps: opt-in

# profiles whose packages the Paquetes phase installs itself (login/boot/mis-apps are installed by their own opt-in modules)
ENGINE_PROFILES="base,keyring,taller,archivos,editor"
CHECK_ONLY=false
CHECK_JSON=false
REQUESTED_PROFILES=""
DRY_RUN=false
ASSUME_YES=false
NO_SUDO=false
PLAIN=false
JSON_EVENTS=false
DOCKER_GROUP_FLAG=false
LINK_MODE="symlink"
REQUESTED_MODULES=""
BOOTLOADER="auto"
BOOT_REVERT=false
CHOOSE=false
RESTART=false
export DRAGON_EXTRAS="${DRAGON_EXTRAS:-}"

# Gum styling (Sweet / Garuda Dragonized palette)
export GUM_CHOOSE_CURSOR_FOREGROUND="#00c1e4"
export GUM_CHOOSE_SELECTED_FOREGROUND="#c50ed2"
export GUM_CONFIRM_SELECTED_BACKGROUND="#7c3aed"
export GUM_CONFIRM_SELECTED_FOREGROUND="#ffffff"
export GUM_SPIN_SPINNER_FOREGROUND="#c50ed2"

usage() {
    cat <<EOF
Uso: $0

Instala dragon-island de principio a fin con UN comando: diagnostica, prepara el sistema, te enseña el plan,
instala, verifica y escribe ~/dragon-informe.txt. No hace falta ninguna opción.

OPCIONES AVANZADAS (docs/INSTALL.md):
  --check              Preflight de solo lectura; salida 1 si hay bloqueos
  --json               JSON de --check (esquema 1)
  --profiles a,b       Perfiles para --check (manifiesto packages/profiles.json)
  --dry-run            Muestra el plan completo sin cambiar nada (no pide sudo, no escribe en tu HOME)
  --yes, -y            Modo desatendido: respuestas por defecto. Los pasos con sudo siguen mostrando qué hacen
  --modules a,b,c      Módulos a instalar: ${ALL_MODULES[*]}  (core siempre se incluye)
  --choose             Elegir módulos y modo de despliegue en un menú
  --extras a,b         Extras sin preguntar: brave,protonvpn,herdr,myapps
  --bootloader B       Módulo boot: grub | limine | auto (por defecto detecta el que esté en uso)
  --revert-boot        Quita el tema de arranque (módulo boot) y vuelve a la configuración anterior
  --plain              Texto lineal, sin interfaz (también se usa solo si no hay terminal)
  --json-events        Una línea JSON por evento (phase, pkg, step, warn, log, done); para pruebas
  --docker-group       Da de antemano la confirmación para añadirte al grupo docker (equivale a root)
  --no-sudo            Omite todo paso que necesite sudo (imprime el comando para hacerlo a mano)
  --copy               Copia los archivos en vez de enlazarlos (por defecto: symlink al repo)
  --restart            Olvida el progreso guardado (p. ej. tras un reinicio pendiente) y empieza de cero
  --update             Equivale a ./update.sh
  --doctor             Equivale a ./doctor.sh
  --uninstall          Equivale a ./uninstall.sh
  -h, --help           Esta ayuda
EOF
}

# dispatch to the sibling scripts before anything else
for arg in "$@"; do
    case "$arg" in
        --update|--doctor|--uninstall)
            target="${arg#--}.sh"; args=()
            for a in "$@"; do [[ "$a" == "$arg" ]] || args+=("$a"); done
            exec "$REPO_DIR/$target" "${args[@]}" ;;
    esac
done

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)     CHECK_ONLY=true ;;
        --json)      CHECK_JSON=true ;;
        --profiles)  REQUESTED_PROFILES="${2:?--profiles necesita una lista}"; shift ;;
        --profiles=*) REQUESTED_PROFILES="${1#*=}" ;;
        --dry-run)   DRY_RUN=true ;;
        --yes|-y)    ASSUME_YES=true ;;
        --no-sudo)   NO_SUDO=true ;;
        --plain)     PLAIN=true ;;
        --json-events) JSON_EVENTS=true ;;
        --docker-group) DOCKER_GROUP_FLAG=true ;;
        --bootloader)   BOOTLOADER="${2:?--bootloader necesita grub, limine o auto}"; shift ;;
        --bootloader=*) BOOTLOADER="${1#*=}" ;;
        --revert-boot)  BOOT_REVERT=true ;;
        --copy)      LINK_MODE="copy" ;;
        --choose)    CHOOSE=true ;;
        --restart)   RESTART=true ;;
        --modules)   REQUESTED_MODULES="${2:?--modules necesita una lista (a,b,c)}"; shift ;;
        --modules=*) REQUESTED_MODULES="${1#*=}" ;;
        --extras)    DRAGON_EXTRAS="${2:?--extras necesita una lista}"; shift ;;
        --extras=*)  DRAGON_EXTRAS="${1#*=}" ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
export DRAGON_EXTRAS BOOTLOADER DOCKER_GROUP_FLAG

# Dispatch before state/logs, module sourcing or TUI: --check is strictly read-only.
if $CHECK_ONLY; then
    # shellcheck source=lib/preflight.sh
    . "$REPO_DIR/lib/preflight.sh"
    check_args=()
    $CHECK_JSON && check_args+=(--json)
    [[ -n "$REQUESTED_PROFILES" ]] && check_args+=(--profiles "$REQUESTED_PROFILES")
    [[ -n "$REQUESTED_MODULES" ]] && check_args+=(--modules "$REQUESTED_MODULES")
    preflight "${check_args[@]}"
    exit $?
fi
if $CHECK_JSON || [[ -n "$REQUESTED_PROFILES" ]]; then
    echo "--json y --profiles requieren --check." >&2
    exit 2
fi


# =============================================================================
# Output mode. The engine only emits events (lib/events.sh); the sink draws them.
#   tui   → lib/tui.sh (needs a real terminal) · plain → linear text · json → one JSON object per line
# =============================================================================
if [[ -t 0 && -t 1 ]]; then HAVE_TTY=true; else HAVE_TTY=false; ASSUME_YES=true; fi
if $JSON_EVENTS; then EV_SINK=json
elif $PLAIN || ! $HAVE_TTY || [[ "${TERM:-dumb}" == dumb ]] || [[ ! -r /dev/tty ]]; then EV_SINK=plain
else EV_SINK=tui; fi
export EV_SINK

# The frame is measured in characters: in a non-UTF-8 locale bash counts bytes, accents and «…» break the widths
# (cut text, right border misaligned). Use a UTF-8 locale for this process when the session's one is not.
case "$(locale charmap 2>/dev/null || true)" in
    UTF-8) ;;
    *) export LC_ALL=C.UTF-8 ;;
esac

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
# shellcheck source=lib/checks.sh
. "$REPO_DIR/lib/checks.sh"
# shellcheck source=lib/events.sh
. "$REPO_DIR/lib/events.sh"
# shellcheck source=lib/tui.sh
. "$REPO_DIR/lib/tui.sh"
# shellcheck source=lib/snapshot.sh
. "$REPO_DIR/lib/snapshot.sh"
# shellcheck source=lib/prepare.sh
. "$REPO_DIR/lib/prepare.sh"
# shellcheck source=lib/plan_screen.sh
. "$REPO_DIR/lib/plan_screen.sh"
# shellcheck source=lib/report.sh
. "$REPO_DIR/lib/report.sh"
for m in "$REPO_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    . "$m"
done

# the boot theme can be taken off on its own (it never needs the rest of the installer)
if $BOOT_REVERT; then boot_revert_all; exit $?; fi

# --dry-run without gum: nothing can be prompted
if $DRY_RUN && ! has_gum; then ASSUME_YES=true; fi

EV_ENGINE=1
shopt -s lastpipe       # `cmd | while read` keeps its state in this shell (event streaming)
# a readable version (the VERSION file), never the git tag («vfix1»); the short commit tells builds apart
TUI_VERSION="$(< "$REPO_DIR/VERSION")"
TUI_VERSION="${TUI_VERSION//[$'\n\r ']/}"

# =============================================================================
# Module selection. No menu by default: the defaults are the product. --choose shows the menu.
# =============================================================================
SELECTED=()
AUTO_LOGIN=false
if [[ -n "$REQUESTED_MODULES" ]]; then
    IFS=',' read -r -a SELECTED <<<"$REQUESTED_MODULES"
elif $CHOOSE && ! $ASSUME_YES && has_gum; then
    declare -A LABEL=()
    labels=() pre=() picked=()
    for m in "${ALL_MODULES[@]}"; do LABEL[$m]="$m — $("${m}_desc")"; labels+=("${LABEL[$m]}"); done
    for m in "${DEFAULT_MODULES[@]}"; do pre+=("${LABEL[$m]}"); done
    mapfile -t picked < <(gum choose --no-limit --header "Módulos (Espacio marca/desmarca, Enter confirma; core es obligatorio):" \
        --selected "$(IFS=,; echo "${pre[*]}")" "${labels[@]}")
    for p in "${picked[@]}"; do SELECTED+=("${p%% *}"); done
else
    SELECTED=("${DEFAULT_MODULES[@]}")
    # a bare install has no login manager: without one nobody can log into Hyprland, so module login (SDDM) comes along
    if [[ "$(display_manager)" == none ]]; then SELECTED+=(login); AUTO_LOGIN=true; fi
fi
# validate, core always first, no duplicates
clean=(core)
for m in "${SELECTED[@]}"; do
    [[ " ${ALL_MODULES[*]} " == *" $m "* ]] || { echo "Módulo desconocido: $m (válidos: ${ALL_MODULES[*]})" >&2; exit 2; }
    [[ " ${clean[*]} " == *" $m "* ]] || clean+=("$m")
done
SELECTED=("${clean[@]}")
has_module() { [[ " ${SELECTED[*]} " == *" $1 "* ]]; }

if $CHOOSE && ! $ASSUME_YES && has_gum; then
    CHOICE="$(gum choose --header "¿Cómo desplegar los archivos de configuración?" \
        "Symlink (recomendado: se actualiza con git pull)" "Copia (archivos independientes en ~/.config)")"
    [[ "$CHOICE" == Copia* ]] && LINK_MODE="copy"
fi
# the keyboard module would open an input box: the one-command install uses the default layouts silently
if ! $CHOOSE && [[ -z "${DRAGON_KB_LAYOUTS:-}" ]]; then
    kb_saved="$(local_conf_get KB_LAYOUTS)"
    export DRAGON_KB_LAYOUTS="${kb_saved:-${KB_DEFAULT:-us,latam}}"
fi

# =============================================================================
# From here on stdout/stderr go to the log (a temporary file until the first change, nothing in dry-run);
# fd 3 is the real terminal, where only events are drawn.
# =============================================================================
exec 3>&1
EV_OUT_FD=3
PRELOG=""
if $DRY_RUN; then LOG=/dev/null
else PRELOG="$(mktemp "${TMPDIR:-/tmp}/dragon-install.XXXXXX")"; LOG="$PRELOG"; fi
exec >>"$LOG" 2>&1
REPORT_ARMED=false
trap 'echo "✗ Error en ${BASH_SOURCE[0]##*/}:$LINENO (${FUNCNAME[1]:-main}). Revisa el registro en: $LOG" >&3' ERR

# shellcheck disable=SC2329  # called by the EXIT trap
cleanup() {
    local rc=$?
    if [[ -n "$SUDO_KEEPALIVE" ]]; then pkill -P "$SUDO_KEEPALIVE" 2>/dev/null || true; kill "$SUDO_KEEPALIVE" 2>/dev/null || true; fi
    # a run that dies on its own still leaves its report (before the temporary log disappears)
    if $REPORT_ARMED && ! $REPORT_WRITTEN && (( rc != 0 )); then report_write error "El instalador terminó con salida $rc en: ${EV_LAST_STEP:-?}" || true; fi
    tui_close || true
    [[ -n "$PRELOG" && -f "$PRELOG" ]] && rm -f "$PRELOG"
    [[ -n "${PLAN_JSON:-}" ]] && rm -f "$PLAN_JSON" "${PLAN_TSV:-}"
    return 0
}
trap cleanup EXIT

# --- prompts (the only place the installer asks anything; they use the real terminal) -------------
gum() {   # gum prompts draw on the terminal even when stdout is captured or logged
    case "${1:-}" in
        choose|input|confirm|filter|write)
            local rc=0
            tui_suspend
            command gum "$@" </dev/tty 2>/dev/tty || rc=$?
            tui_resume
            return "$rc" ;;
        *) command gum "$@" ;;
    esac
}
# engine_confirm <question> <yes|no>   (default button). Shows CONFIRM_DETAIL first, on the terminal.
# CONFIRM_YES / CONFIRM_NO name the buttons ("Instalar todo" / "Cancelar").
engine_confirm() {
    local rc=0 flag=()
    [[ "$2" == no ]] && flag=(--default=false)
    if [[ "$EV_SINK" == json ]]; then [[ "$2" == yes ]]; return; fi    # nothing to ask in a machine-readable run
    tui_suspend
    if [[ -n "$CONFIRM_DETAIL" ]]; then printf '\n%s\n\n' "$CONFIRM_DETAIL" >/dev/tty; fi
    if has_gum; then
        command gum confirm "${flag[@]}" --affirmative "${CONFIRM_YES:-Sí}" --negative "${CONFIRM_NO:-No}" "$1" </dev/tty >/dev/tty 2>/dev/tty || rc=$?
    else
        ask_plain "$1" "$2" || rc=$?
    fi
    CONFIRM_DETAIL=""
    tui_resume
    return "$rc"
}

# --- helpers --------------------------------------------------------------------------------------
declare -A RESULT=()
HARD=0
BLOCKERS=()
PLAN_PKGS=()          # name<TAB>state<TAB>detail<TAB>source<TAB>engine
SIZE_BYTES=0
PAUSE_MESSAGE=""
REPORT_PATH_SHOWN=""

human_size() {
    awk -v b="$1" 'BEGIN { if (b < 1048576) printf "%.0f KiB", b / 1024; else if (b < 1073741824) printf "%.1f MiB", b / 1048576; else printf "%.2f GiB", b / 1073741824 }'
}

# replay_file <file>: lines a module wrote with plain echo become log events (and reach the real log)
replay_file() {
    local line
    while IFS= read -r line; do ev_log "$line"; done < "$1"
    cat "$1" >> "$LOG"
}

# run_captured <function> [args]: runs a module function, its direct output becoming log events afterwards
run_captured() {
    local out rc=0
    out="$(mktemp)"
    "$@" >"$out" 2>&1 || rc=$?
    replay_file "$out"; rm -f "$out"
    return "$rc"
}

# finish <status> <message> <exit-code>: the report is written first so that its path is part of the final message
finish() {
    local status="$1" message="$2"
    if ! $DRY_RUN && $REPORT_ARMED; then
        report_write "$status" "$message"
        [[ -n "$REPORT_PATH_SHOWN" ]] && message+=$'\n\n'"Informe: $REPORT_PATH_SHOWN"
    elif $DRY_RUN; then
        message+=$'\n\n'"Informe: en una instalación real se escribe en ~/dragon-informe.txt (en --dry-run no se escribe nada)."
    fi
    ev_done "$status" "$message"
    exit "$3"
}

# check_result <id> <label>: runs check_<id>, records it for the report and surfaces its message. 0 ok · 1 failed · 2 warning
check_result() {
    local id="$1" label="$2" out rc=0 line
    out="$("check_$id" 2>&1)" || rc=$?
    case "$rc" in
        0) REPORT_CHECKS+=("ok     $label") ;;
        2) REPORT_CHECKS+=("aviso  $label"); ev_warn "$label" ;;
        *) REPORT_CHECKS+=("fallo  $label"); ev_warn "Requisito previo sin cumplir: $label" ;;
    esac
    if (( rc != 0 )); then while IFS= read -r line; do [[ -n "$line" ]] && ev_log "$line"; done <<<"$out"; fi
    return "$rc"
}

REPORT_ARMED=true
$RESTART && progress_clear
# test hook (tests/installer_ux): stop cleanly after a stage — prepare | plan | packages. Never set in normal use.
stop_point() { [[ "${DRAGON_STOP_AFTER:-}" == "$1" ]] && finish ok "Detenido tras «$1» (DRAGON_STOP_AFTER, solo para pruebas)." 0; return 0; }

# =============================================================================
# Phase 1 · Preflight: diagnose, prepare the system (prerequisites + full update + headers), then look for conflicts.
# =============================================================================
ev_phase Preflight
$DRY_RUN && ev_step "Modo --dry-run: no se cambia nada, no se pide sudo y no se escribe en tu HOME."
if [[ "$(progress_get stage)" == reboot ]] && ! $DRY_RUN; then
    ev_step "Continuando donde lo dejaste: el sistema ya se actualizó y faltaba reiniciar."
fi
ev_step "Diagnóstico del sistema (equivale a ./doctor.sh --pre)"
"$REPO_DIR/doctor.sh" --pre --no-ask 2>&1 | ev_stream || true

# Needed before anything can be installed: not root, a supported distro, the network, sudo.
for id in root distro network; do
    case "$id" in root) l="No eres root" ;; distro) l="Distribución soportada" ;; *) l="Red: archlinux.org alcanzable" ;; esac
    check_result "$id" "$l" || HARD=$((HARD + 1))
done
if ! $DRY_RUN && ! $NO_SUDO; then check_result sudo "sudo disponible y usuario en wheel" || HARD=$((HARD + 1)); fi
if (( HARD > 0 )); then
    if $DRY_RUN; then ev_warn "$HARD requisito(s) previos fallan. En una instalación real el instalador se detendría aquí."
    else finish error "Faltan $HARD requisito(s) previos (arriba). Corrígelos y repite ./install.sh (más detalle: ./doctor.sh --pre)" 1; fi
fi

# prerequisites + update + reboot check + headers + AUR helper
prep_rc=0
prepare_system || prep_rc=$?
case "$prep_rc" in
    0) ;;
    10) finish pause "$PAUSE_MESSAGE" 0 ;;
    11) finish ok "$PAUSE_MESSAGE" 0 ;;
    *) finish error "No se pudo preparar el sistema (paso: ${EV_LAST_STEP:-?}). Corrige lo indicado y repite ./install.sh: continuará donde lo dejó." 1 ;;
esac

stop_point prepare
# What is only needed on a real run: after the preparation these must hold. A dry-run reports what would be installed instead.
for id in base aur versions; do
    case "$id" in base) l="Herramientas base (git, curl, unzip, gum, pciutils, base-devel)" ;; aur) l="Ayudante de AUR" ;; *) l="Hyprland ≥ 0.55 y Quickshell ≥ 0.3 disponibles" ;; esac
    if $DRY_RUN && [[ "$id" != versions ]]; then
        check_result "$id" "$l" || ev_log "[dry-run] se instalaría en la preparación: $l"
    else
        check_result "$id" "$l" || HARD=$((HARD + 1))
    fi
done
for id in gpu dm time disk; do
    case "$id" in gpu) l="GPU y driver de video" ;; dm) l="Gestor de acceso (display manager)" ;; time) l="Hora sincronizada (NTP)" ;; *) l="Espacio libre ≥ 5 GB" ;; esac
    check_result "$id" "$l" || true
done
if $AUTO_LOGIN; then ev_step "Sin gestor de acceso: se añade el módulo login (instala y habilita SDDM)."; fi
if (( HARD > 0 )) && ! $DRY_RUN; then
    finish error "Faltan $HARD requisito(s) previos tras la preparación (arriba). Repite ./install.sh o mira ./doctor.sh --pre" 1
fi
AUR_HELPER="$(aur_helper)"
if pacman -Qq plasma-desktop >/dev/null 2>&1 || pacman -Qq plasma-workspace >/dev/null 2>&1; then
    ev_step "KDE Plasma detectado: Hyprland se instala como sesión adicional (Plasma no se toca)."
fi

ev_step "Conflictos de paquetes y sistema (solo lectura)"
PLAN_JSON="$(mktemp)"; PLAN_TSV="$(mktemp)"
pf_rc=0
# stderr of the engine is its progress: «done<TAB>total<TAB>message» → events (the screen is alive, never an empty 0/0)
PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_preflight.py" --json --progress --modules "$(IFS=,; echo "${SELECTED[*]}")" 2>&1 >"$PLAN_JSON" \
    | while IFS=$'\t' read -r p_done p_total p_msg; do
        [[ "$p_done" =~ ^[0-9]+$ && "$p_total" =~ ^[0-9]+$ ]] || { [[ -n "$p_done" ]] && ev_log "$p_done"; continue; }
        if (( p_total == 0 || p_done == 0 || p_done % 10 == 0 || p_done == p_total )); then ev_progress "$p_done" "$p_total" "$p_msg"; fi
    done || true
pf_rc=${PIPESTATUS[0]}
if (( pf_rc > 1 )) || ! PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_plan.py" "$PLAN_JSON" \
        --engine "$ENGINE_PROFILES" >"$PLAN_TSV"; then
    finish error "El preflight no pudo ejecutarse (salida $pf_rc). Prueba: ./install.sh --check" 1
fi
while IFS=$'\t' read -r kind a b c d e; do
    case "$kind" in
        pkg)   PLAN_PKGS+=("$a"$'\t'"$b"$'\t'"$c"$'\t'"$d"$'\t'"$e") ;;
        issue) PLAN_ISSUES+=("$a"$'\t'"$b"$'\t'"$c"$'\t'"$d")
               REPORT_ISSUES+=("[$a] $b — $c → $d")
               [[ "$a" == bloquear ]] && BLOCKERS+=("$b — $c") ;;
        meta)  case "$a" in size_bytes) SIZE_BYTES="$b" ;; deps) DEPS_COUNT="$b" ;; esac ;;
    esac
done < "$PLAN_TSV"
if (( ${#BLOCKERS[@]} > 0 )); then
    if $DRY_RUN; then ev_warn "${#BLOCKERS[@]} bloqueo(s) del preflight. En una instalación real el instalador se detendría aquí, antes de instalar nada."
    else
        finish error "El preflight encontró ${#BLOCKERS[@]} bloqueo(s); no se instaló ningún paquete.
$(printf '  - %s\n' "${BLOCKERS[@]}")
Detalle: ./install.sh --check" 1
    fi
fi

# =============================================================================
# Phase 2 · Plan: the table, the size, every incident explained, the steps with sudo. ONE confirmation: «Instalar todo».
# =============================================================================
ev_phase Plan
n_new=0; n_aur=0; n_have=0; n_bad=0
for row in "${PLAN_PKGS[@]}"; do
    IFS=$'\t' read -r name state detail source _ <<<"$row"
    ev_pkg "$name" "$state" "$detail"
    case "$state" in install) n_new=$((n_new + 1)) ;; aur) n_aur=$((n_aur + 1)) ;; installed) n_have=$((n_have + 1)) ;; conflict) n_bad=$((n_bad + 1)) ;; esac
done
ev_step "Paquetes: ${#PLAN_PKGS[@]} en el plan · $n_new oficiales a instalar · $n_aur AUR · $n_have ya instalados · descarga ≈ $(human_size "$SIZE_BYTES")${DEPS_COUNT:+ (+$DEPS_COUNT dependencias)}"
for row in "${PLAN_ISSUES[@]}"; do
    IFS=$'\t' read -r action subject why does <<<"$row"
    case "$action" in
        bloquear|sustituir|aviso|compilar) ev_warn "$action · $subject — $why → $does" ;;
        *) ev_log "$action · $subject — $why → $does" ;;
    esac
done
ev_step "Módulos: ${SELECTED[*]} · despliegue: $LINK_MODE · sudo: $($NO_SUDO && echo desactivado || echo "una contraseña")"
$NO_SUDO || PLAN_SUDO_STEPS+=("Instalar los paquetes oficiales y AUR de la tabla (sudo pacman -S --needed)")
for m in "${SELECTED[@]}"; do
    ev_step "• $m — $("${m}_desc")"
    run_captured "${m}_plan" || true
    ev_log "    sudo: $("${m}_sudo")"
    $NO_SUDO || PLAN_SUDO_STEPS+=("$m: $("${m}_sudo")")
done
stop_point plan
if ! $DRY_RUN; then
    CONFIRM_YES="Instalar todo" CONFIRM_NO="Cancelar" CONFIRM_DETAIL="$(plan_text)"
    confirm "¿Instalar todo? (los pasos con sudo se anuncian uno a uno)" || finish ok "Cancelado: el sistema ya está preparado, pero no se instaló nada del plan. Repite ./install.sh cuando quieras." 0
    CONFIRM_YES=""; CONFIRM_NO=""      # later questions (docker group…) use the ordinary Sí / No buttons
fi
PLAN_CONFIRMED=true

# =============================================================================
# Phase 3 · Paquetes: snapshot + package list, then the plan's packages (the system was updated in Preflight)
# =============================================================================
ev_phase Paquetes
start_real_log
if ! $DRY_RUN && ! $NO_SUDO; then
    sudo_start || finish error "sudo no autorizó la sesión." 1
fi
snapshot_create

OFFICIAL=(); AURPKGS=()
for row in "${PLAN_PKGS[@]}"; do
    IFS=$'\t' read -r name state _ source engine <<<"$row"
    [[ "$engine" == 1 ]] || continue
    [[ "$state" == install ]] && [[ "$source" == pacman ]] && OFFICIAL+=("$name")
    [[ "$state" == aur ]] && AURPKGS+=("$name")
done

# pkg_failure_cause <log-line-offset> <package>: the first error line the last command wrote, as the cause shown to the user
pkg_failure_cause() {
    local cause=""
    [[ "$LOG" != /dev/null && -f "$LOG" ]] && cause="$(tail -n +"$(( $1 + 1 ))" "$LOG" | grep -E -i -m1 "(error|failed|fall[óo]|could not|no se pudo|unable|==> ERROR)" | cut -c1-140 || true)"
    printf '%s' "${cause:-no quedó instalado (ver el registro)}"
}
log_lines() { [[ "$LOG" != /dev/null && -f "$LOG" ]] && wc -l < "$LOG" || echo 0; }

install_official() {
    local targets
    targets="$(package_targets "${OFFICIAL[@]}")" || return 1
    OFFICIAL=()
    [[ -z "$targets" ]] || mapfile -t OFFICIAL <<<"$targets"
    (( ${#OFFICIAL[@]} > 0 )) || { ev_step "Paquetes oficiales: nada que instalar."; return 0; }
    if $NO_SUDO; then ev_warn "Sin sudo (--no-sudo): hazlo a mano: sudo pacman -S --needed ${OFFICIAL[*]}"
        MANUAL_ITEMS+=("Paquetes oficiales: sudo pacman -S --needed ${OFFICIAL[*]}"); return 0; fi
    ev_step "[sudo] Instalar ${#OFFICIAL[@]} paquetes oficiales (pacman -S --needed)"
    if $DRY_RUN; then
        ev_log "[dry-run] sudo pacman -S --needed --noconfirm ${OFFICIAL[*]}"
        return 0
    fi
    local line last="" rc=0 p mark; mark="$(log_lines)"
    sudo pacman -S --needed --noconfirm "${OFFICIAL[@]}" 2>&1 | tee -a "$LOG" | while IFS= read -r line; do
        ev_log "$line"
        if [[ "$line" =~ ^\([0-9]+/[0-9]+\)\ (installing|upgrading|reinstalling)\ ([^[:space:]]+) ]]; then
            [[ -n "$last" ]] && ev_pkg "$last" ok
            last="${BASH_REMATCH[2]}"; ev_pkg "$last" running
        fi
    done || rc=${PIPESTATUS[0]}
    for p in "${OFFICIAL[@]}"; do
        if pkg_installed "$p"; then ev_pkg "$p" ok
        else
            local cause; cause="$(pkg_failure_cause "$mark" "$p")"
            ev_pkg "$p" failed "$cause"; REPORT_PROBLEMS+=("$p — $cause"); rc=1
        fi
    done
    return "$rc"
}

install_aur() {
    local targets
    targets="$(package_targets "${AURPKGS[@]}")" || return 1
    AURPKGS=()
    [[ -z "$targets" ]] || mapfile -t AURPKGS <<<"$targets"
    (( ${#AURPKGS[@]} > 0 )) || return 0
    if [[ -z "$AUR_HELPER" ]]; then
        ev_warn "Sin yay/paru: instala a mano ${AURPKGS[*]} (ver $PRE_DOC, Paso 3)."
        MANUAL_ITEMS+=("Paquetes AUR sin ayudante: ${AURPKGS[*]}"); return 1
    fi
    ev_step "Paquetes AUR con $AUR_HELPER (${#AURPKGS[@]}; compilan en esta máquina y pueden tardar)"
    local p rc=0 mark
    for p in "${AURPKGS[@]}"; do
        if $DRY_RUN; then ev_log "[dry-run] $AUR_HELPER -S --needed --noconfirm $p"; continue; fi
        ev_pkg "$p" running; mark="$(log_lines)"
        run_streamed "$AUR_HELPER" -S --needed --noconfirm "$p" || true
        if pkg_installed "$p"; then ev_pkg "$p" ok
        else
            local cause; cause="$(pkg_failure_cause "$mark" "$p")"
            ev_pkg "$p" failed "$cause"; REPORT_PROBLEMS+=("$p — $cause"); rc=1
        fi
    done
    return "$rc"
}
install_official || RESULT[paquetes]="con avisos"
install_aur || RESULT[paquetes]="con avisos"
if (( ${#REPORT_PROBLEMS[@]} > 0 )); then RESULT[paquetes]="${#REPORT_PROBLEMS[@]} con problema"
elif [[ -z "${RESULT[paquetes]:-}" ]]; then RESULT[paquetes]="ok"; fi

stop_point packages

# =============================================================================
# Phase 4 · Despliegue: each module (its packages are already there)
# =============================================================================
ev_phase Despliegue
for m in "${SELECTED[@]}"; do
    ev_step "Módulo: $m — $("${m}_desc")"
    if run_captured "${m}_apply"; then RESULT[$m]="ok"; else RESULT[$m]="con avisos"; ev_warn "$m terminó con avisos"; fi
done

# state read by update.sh / uninstall.sh; a fresh install already contains every migration
if ! $DRY_RUN; then
    printf '%s\n' "${SELECTED[@]}" > "$STATE_DIR/modules"
    printf '%s\n' "$LINK_MODE" > "$STATE_DIR/link-mode"
    touch "$STATE_DIR/migrations.done"
    for f in "$REPO_DIR"/migrations/[0-9]*.sh; do
        grep -qxF "$(basename "$f")" "$STATE_DIR/migrations.done" || basename "$f" >> "$STATE_DIR/migrations.done"
    done
    installed_version hyprland > "$STATE_DIR/hyprland-version" || true
fi

# =============================================================================
# Phase 5 · Servicios: docker, keyring/PAM. Every /etc or service step is announced.
# =============================================================================
ev_phase Servicios
for m in "${SELECTED[@]}"; do
    declare -F "${m}_services" >/dev/null || continue
    ev_step "Servicios de $m"
    run_captured "${m}_services" || ev_warn "$m: servicios con avisos"
done

# =============================================================================
# Phase 6 · Verificación: doctor.sh + the final report with what stays manual
# =============================================================================
ev_phase Verificación
doctor_rc=0
if $DRY_RUN; then ev_step "Verificación omitida en --dry-run (no hay nada instalado que comprobar)."
else
    ev_step "doctor.sh: diagnóstico completo"
    "$REPO_DIR/doctor.sh" --no-ask 2>&1 | ev_stream || doctor_rc=${PIPESTATUS[0]}
    (( doctor_rc == 0 )) || ev_warn "doctor.sh encontró $doctor_rc problema(s); sigue sus indicaciones."
fi

report=()
for m in "${SELECTED[@]}"; do report+=("• $m: $($DRY_RUN && echo simulado || echo "${RESULT[$m]:-?}")"); done
if $DRY_RUN; then report+=("• paquetes: $n_new por instalar · $n_aur AUR · $n_have ya instalados · $n_bad con conflicto" "")
else report+=("• paquetes: ${RESULT[paquetes]}" ""); fi
# the TUI box already lists each problem with its cause under the package counts; text and JSON sinks need them here
[[ "$EV_SINK" == tui ]] || for p in "${REPORT_PROBLEMS[@]}"; do report+=("  ✖ $p"); done
has_module plugins && report+=("• Plugins: si no estabas dentro de Hyprland, se compilan en tu primer inicio de sesión (se abre una terminal).")
has_module login && report+=("• Login: reinicia para ver el tema (SDDM).")
if (( ${#MANUAL_ITEMS[@]} > 0 )); then
    report+=("" "Queda para ti (manual):")
    for item in "${MANUAL_ITEMS[@]}"; do report+=("  - $item"); done
fi
if [[ -f "$STATE_DIR/needs-relogin" ]] && ! $DRY_RUN; then
    report+=("" "Cierra sesión y vuelve a entrar:"); while IFS= read -r line; do report+=("  - $line"); done < "$STATE_DIR/needs-relogin"
fi
if $DRY_RUN; then report+=("" "Recuperación: en una instalación real se guarda la lista de paquetes y, si hay snapper o Timeshift, una instantánea previa.")
else
    report+=("" "Recuperación:")
    while IFS= read -r line; do report+=("  $line"); done < <(snapshot_recovery)
fi
report+=("" "Respaldos: $BACKUP_DIR (solo si había algo que reemplazar) · Registro: $LOG"
         "Siguiente paso: cierra sesión → en el login elige «Hyprland»."
         "SUPER+Return terminal · SUPER+Space lanzador · SUPER+D notch · SUPER+L bloquear · SUPER+F1 atajos"
         "Actualizar: ./update.sh · Diagnóstico: ./doctor.sh · Revertir: ./uninstall.sh [--modules a,b]")
status=ok
(( doctor_rc > 0 )) && status=warn
(( ${#REPORT_PROBLEMS[@]} > 0 )) && status=warn
for m in "${!RESULT[@]}"; do [[ "${RESULT[$m]}" == "con avisos" ]] && status=warn; done
$DRY_RUN && status=dry-run
[[ "$status" == dry-run ]] || progress_clear
finish "$status" "$(printf '%s\n' "${report[@]}")" 0
