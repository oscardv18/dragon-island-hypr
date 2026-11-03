#!/usr/bin/env bash
# =============================================================================
# dragon-island — modular installer (gum TUI). Arch / EndeavourOS / CachyOS.
# Requirements BEFORE running it: pre-instalation.md (check them with ./doctor.sh --pre).
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
export DRAGON_EXTRAS="${DRAGON_EXTRAS:-}"

# Gum styling (Sweet / Garuda Dragonized palette)
export GUM_CHOOSE_CURSOR_FOREGROUND="#00c1e4"
export GUM_CHOOSE_SELECTED_FOREGROUND="#c50ed2"
export GUM_CONFIRM_SELECTED_BACKGROUND="#7c3aed"
export GUM_CONFIRM_SELECTED_FOREGROUND="#ffffff"
export GUM_SPIN_SPINNER_FOREGROUND="#c50ed2"

usage() {
    cat <<EOF
Uso: $0 [OPCIONES]

Instalador modular de dragon-island. Antes de ejecutarlo: pre-instalation.md (./doctor.sh --pre lo comprueba).

OPCIONES:
  --check              Preflight de solo lectura; salida 1 si hay bloqueos
  --json               JSON de --check (esquema 1)
  --profiles a,b       Perfiles para --check (manifiesto packages/profiles.json)
  --dry-run            Muestra el plan completo sin cambiar nada (no pide sudo, no escribe en tu HOME)
  --yes, -y            Modo desatendido: respuestas por defecto. Los pasos con sudo siguen mostrando qué hacen
  --modules a,b,c      Módulos a instalar: ${ALL_MODULES[*]}  (core siempre se incluye)
  --extras a,b         Extras sin preguntar: brave,protonvpn,herdr,myapps
  --bootloader B       Módulo boot: grub | limine | auto (por defecto detecta el que esté en uso)
  --revert-boot        Quita el tema de arranque (módulo boot) y vuelve a la configuración anterior
  --plain              Texto lineal, sin interfaz (también se usa solo si no hay terminal)
  --json-events        Una línea JSON por evento (phase, pkg, step, warn, log, done); para pruebas
  --docker-group       Da de antemano la confirmación para añadirte al grupo docker (equivale a root)
  --no-sudo            Omite todo paso que necesite sudo (imprime el comando para hacerlo a mano)
  --copy               Copia los archivos en vez de enlazarlos (por defecto: symlink al repo)
  --update             Equivale a ./update.sh
  --doctor             Equivale a ./doctor.sh
  --uninstall          Equivale a ./uninstall.sh
  -h, --help           Esta ayuda

Sin opciones: menú con los módulos y resumen del plan antes de aplicar.
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
TUI_VERSION="$(git -C "$REPO_DIR" describe --tags --always 2>/dev/null || echo dev)"
TUI_VERSION="${TUI_VERSION#instalador-}"

# =============================================================================
# Module selection (before the screen is taken over: it uses gum on the normal screen)
# =============================================================================
SELECTED=()
if [[ -n "$REQUESTED_MODULES" ]]; then
    IFS=',' read -r -a SELECTED <<<"$REQUESTED_MODULES"
elif $ASSUME_YES; then
    SELECTED=("${DEFAULT_MODULES[@]}")
else
    declare -A LABEL=()
    labels=() pre=() picked=()
    for m in "${ALL_MODULES[@]}"; do LABEL[$m]="$m — $("${m}_desc")"; labels+=("${LABEL[$m]}"); done
    for m in "${DEFAULT_MODULES[@]}"; do pre+=("${LABEL[$m]}"); done
    mapfile -t picked < <(gum choose --no-limit --header "Módulos (Espacio marca/desmarca, Enter confirma; core es obligatorio):" \
        --selected "$(IFS=,; echo "${pre[*]}")" "${labels[@]}")
    for p in "${picked[@]}"; do SELECTED+=("${p%% *}"); done
fi
# validate, core always first, no duplicates
clean=(core)
for m in "${SELECTED[@]}"; do
    [[ " ${ALL_MODULES[*]} " == *" $m "* ]] || { echo "Módulo desconocido: $m (válidos: ${ALL_MODULES[*]})" >&2; exit 2; }
    [[ " ${clean[*]} " == *" $m "* ]] || clean+=("$m")
done
SELECTED=("${clean[@]}")
has_module() { [[ " ${SELECTED[*]} " == *" $1 "* ]]; }

if ! $ASSUME_YES && [[ -z "$REQUESTED_MODULES" ]]; then
    CHOICE="$(gum choose --header "¿Cómo desplegar los archivos de configuración?" \
        "Symlink (recomendado: se actualiza con git pull)" "Copia (archivos independientes en ~/.config)")"
    [[ "$CHOICE" == Copia* ]] && LINK_MODE="copy"
fi

# =============================================================================
# From here on stdout/stderr go to the log (a temporary file until the preflight passes, nothing in dry-run);
# fd 3 is the real terminal, where only events are drawn.
# =============================================================================
exec 3>&1
EV_OUT_FD=3
PRELOG=""
if $DRY_RUN; then LOG=/dev/null
else PRELOG="$(mktemp "${TMPDIR:-/tmp}/dragon-install.XXXXXX")"; LOG="$PRELOG"; fi
exec >>"$LOG" 2>&1
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&3' ERR

SUDO_KEEPALIVE=""
# shellcheck disable=SC2329  # called by the EXIT trap
cleanup() {
    [[ -n "$SUDO_KEEPALIVE" ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null || true
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
engine_confirm() {
    local rc=0 flag=()
    [[ "$2" == no ]] && flag=(--default=false)
    if [[ "$EV_SINK" == json ]]; then [[ "$2" == yes ]]; return; fi    # nothing to ask in a machine-readable run
    tui_suspend
    if [[ -n "$CONFIRM_DETAIL" ]]; then printf '\n%s\n\n' "$CONFIRM_DETAIL" >/dev/tty; fi
    command gum confirm "${flag[@]}" --affirmative "Sí" --negative "No" "$1" </dev/tty >/dev/tty 2>/dev/tty || rc=$?
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

finish() {   # finish <status> <message> <exit-code>
    ev_done "$1" "$2"
    exit "$3"
}

# =============================================================================
# Phase 1 · Preflight (read-only): prerequisites, then conflicts. Blockers stop everything before any change.
# =============================================================================
ev_phase Preflight
$DRY_RUN && ev_step "Modo --dry-run: no se cambia nada."
ev_step "Requisitos previos (./doctor.sh --pre)"
"$REPO_DIR/doctor.sh" --pre 2>&1 | ev_stream || true
for id in root distro base aur network versions; do
    if ! out="$("check_$id" 2>&1)"; then
        HARD=$((HARD + 1)); ev_warn "Requisito previo sin cumplir: $id"
        while IFS= read -r line; do [[ -n "$line" ]] && ev_log "$line"; done <<<"$out"
    fi
done
for id in gpu dm time disk; do "check_$id" >/dev/null 2>&1 || true; done
if (( HARD > 0 )); then
    if $DRY_RUN; then ev_warn "$HARD requisito(s) previos fallan. En una instalación real el instalador se detendría aquí."
    else finish error "Faltan $HARD requisito(s) previos (arriba). Corrígelos y repite; comprueba con: ./doctor.sh --pre" 1; fi
fi
AUR_HELPER="$(aur_helper)"
if pacman -Qq plasma-desktop >/dev/null 2>&1 || pacman -Qq plasma-workspace >/dev/null 2>&1; then
    ev_step "KDE Plasma detectado: Hyprland se instala como sesión adicional (Plasma no se toca)."
fi

ev_step "Conflictos de paquetes y sistema (./install.sh --check, solo lectura)"
PLAN_JSON="$(mktemp)"; PLAN_TSV="$(mktemp)"
pf_rc=0
PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_preflight.py" --json --modules "$(IFS=,; echo "${SELECTED[*]}")" >"$PLAN_JSON" || pf_rc=$?
if (( pf_rc > 1 )) || ! PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_plan.py" "$PLAN_JSON" \
        --engine "$ENGINE_PROFILES" >"$PLAN_TSV"; then
    finish error "El preflight no pudo ejecutarse (salida $pf_rc). Prueba: ./install.sh --check" 1
fi
while IFS=$'\t' read -r kind a b c d e; do
    case "$kind" in
        pkg)   PLAN_PKGS+=("$a"$'\t'"$b"$'\t'"$c"$'\t'"$d"$'\t'"$e") ;;
        check) if [[ "$a" == bloqueante ]]; then BLOCKERS+=("$c ($b)${d:+ → $d}"); ev_warn "BLOQUEANTE · $c ($b)${d:+ → $d}"
               else ev_warn "aviso · $c ($b)"; fi ;;
        meta)  [[ "$a" == size_bytes ]] && SIZE_BYTES="$b" ;;
    esac
done < "$PLAN_TSV"
if (( ${#BLOCKERS[@]} > 0 )); then
    if $DRY_RUN; then ev_warn "${#BLOCKERS[@]} bloqueo(s) del preflight. En una instalación real el instalador se detendría aquí, antes de tocar nada."
    else
        finish error "El preflight encontró ${#BLOCKERS[@]} bloqueo(s); no se tocó nada.
$(printf '  - %s\n' "${BLOCKERS[@]}")
Detalle completo: ./install.sh --check" 1
    fi
fi

# =============================================================================
# Phase 2 · Plan: package table, download size, steps with sudo. One confirmation.
# =============================================================================
ev_phase Plan
n_new=0; n_aur=0
for row in "${PLAN_PKGS[@]}"; do
    IFS=$'\t' read -r name state detail source _ <<<"$row"
    ev_pkg "$name" "$state" "$detail"
    [[ "$state" == install ]] && n_new=$((n_new + 1))
    [[ "$state" == aur ]] && n_aur=$((n_aur + 1))
done
ev_step "Paquetes: ${#PLAN_PKGS[@]} en el plan · $n_new oficiales a instalar · $n_aur AUR · descarga ≈ $(human_size "$SIZE_BYTES")"
ev_step "Módulos: ${SELECTED[*]} · despliegue: $LINK_MODE · sudo: $($NO_SUDO && echo desactivado || echo "con confirmación en cada paso")"
for m in "${SELECTED[@]}"; do
    ev_step "• $m — $("${m}_desc")"
    run_captured "${m}_plan" || true
    ev_log "    sudo: $("${m}_sudo")"
done
if ! $DRY_RUN; then
    CONFIRM_DETAIL="Módulos: ${SELECTED[*]}
Paquetes: ${#PLAN_PKGS[@]} en el plan · $n_new oficiales a instalar · $n_aur AUR · descarga ≈ $(human_size "$SIZE_BYTES")
Antes de cambiar nada: instantánea (si hay snapper/Timeshift) y lista de paquetes. sudo se pide una vez."
    confirm "¿Aplicar este plan?" || finish ok "Cancelado: no se cambió nada." 0
fi

# =============================================================================
# Phase 3 · Paquetes: sudo once, snapshot + package list, full upgrade, then the plan's packages
# =============================================================================
ev_phase Paquetes
if ! $DRY_RUN; then
    mkdir -p "$STATE_DIR"                       # first change: the real log replaces the temporary one
    cat "$PRELOG" >> "$STATE_DIR/install.log"; rm -f "$PRELOG"; PRELOG=""
    LOG="$STATE_DIR/install.log"; exec >>"$LOG" 2>&1
fi
if ! $DRY_RUN && ! $NO_SUDO; then
    tui_suspend
    # shellcheck disable=SC2024  # the password prompt must use the real terminal
    sudo -v </dev/tty >/dev/tty 2>&1 || { tui_resume; finish error "sudo no autorizó la sesión." 1; }
    tui_resume
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE=$!
fi
snapshot_create

# one full upgrade first (never a partial upgrade), then -S --needed without -y
confirm_sudo "Actualizar el sistema (pacman -Syu) antes de instalar: evita actualizaciones parciales" pacman -Syu --noconfirm || true

OFFICIAL=(); AURPKGS=()
for row in "${PLAN_PKGS[@]}"; do
    IFS=$'\t' read -r name state _ source engine <<<"$row"
    [[ "$engine" == 1 ]] || continue
    [[ "$state" == install ]] && [[ "$source" == pacman ]] && OFFICIAL+=("$name")
    [[ "$state" == aur ]] && AURPKGS+=("$name")
done

install_official() {
    (( ${#OFFICIAL[@]} > 0 )) || { ev_step "Paquetes oficiales: nada que instalar."; return 0; }
    if $NO_SUDO; then ev_warn "Sin sudo (--no-sudo): hazlo a mano: sudo pacman -S --needed ${OFFICIAL[*]}"
        MANUAL_ITEMS+=("Paquetes oficiales: sudo pacman -S --needed ${OFFICIAL[*]}"); return 0; fi
    ev_step "[sudo] Instalar ${#OFFICIAL[@]} paquetes oficiales (pacman -S --needed)"
    confirm "¿Ejecutar con sudo?  sudo pacman -S --needed --noconfirm (${#OFFICIAL[@]} paquetes)" || { ev_warn "Omitido por ti."; return 1; }
    if $DRY_RUN; then
        ev_log "[dry-run] sudo pacman -S --needed --noconfirm ${OFFICIAL[*]}"
        return 0
    fi
    local line last="" rc=0 p
    sudo pacman -S --needed --noconfirm "${OFFICIAL[@]}" 2>&1 | tee -a "$LOG" | while IFS= read -r line; do
        ev_log "$line"
        if [[ "$line" =~ ^\([0-9]+/[0-9]+\)\ (installing|upgrading|reinstalling)\ ([^[:space:]]+) ]]; then
            [[ -n "$last" ]] && ev_pkg "$last" ok
            last="${BASH_REMATCH[2]}"; ev_pkg "$last" running
        fi
    done || rc=${PIPESTATUS[0]}
    for p in "${OFFICIAL[@]}"; do
        if pkg_installed "$p"; then ev_pkg "$p" ok; else ev_pkg "$p" failed; rc=1; fi
    done
    return "$rc"
}

install_aur() {
    (( ${#AURPKGS[@]} > 0 )) || return 0
    if [[ -z "$AUR_HELPER" ]]; then
        ev_warn "Sin yay/paru: instala a mano ${AURPKGS[*]} (ver $PRE_DOC, Paso 3)."
        MANUAL_ITEMS+=("Paquetes AUR sin ayudante: ${AURPKGS[*]}"); return 1
    fi
    confirm "¿Instalar ${#AURPKGS[@]} paquetes AUR con $AUR_HELPER? (compila en esta máquina y puede tardar)" || return 1
    local p rc=0
    for p in "${AURPKGS[@]}"; do
        if $DRY_RUN; then ev_log "[dry-run] $AUR_HELPER -S --needed --noconfirm $p"; continue; fi
        ev_pkg "$p" running
        run_streamed "$AUR_HELPER" -S --needed --noconfirm "$p" || true
        if pkg_installed "$p"; then ev_pkg "$p" ok; else ev_pkg "$p" failed; rc=1; fi
    done
    return "$rc"
}
install_official || RESULT[paquetes]="con avisos"
install_aur || RESULT[paquetes]="con avisos"
[[ -n "${RESULT[paquetes]:-}" ]] || RESULT[paquetes]="ok"

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
# Phase 5 · Servicios: docker, keyring/PAM. Every /etc or service step is shown and confirmed.
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
    "$REPO_DIR/doctor.sh" 2>&1 | ev_stream || doctor_rc=${PIPESTATUS[0]}
    (( doctor_rc == 0 )) || ev_warn "doctor.sh encontró $doctor_rc problema(s); sigue sus indicaciones."
fi

report=()
for m in "${SELECTED[@]}"; do report+=("• $m: ${RESULT[$m]:-(dry-run)}"); done
report+=("• paquetes: ${RESULT[paquetes]:-(dry-run)}" "")
has_module plugins && report+=("• Plugins: si no estabas dentro de Hyprland, se compilan en tu primer inicio de sesión (se abre una terminal).")
has_module login && report+=("• Login: reinicia para ver el tema (SDDM).")
if (( ${#MANUAL_ITEMS[@]} > 0 )); then
    report+=("" "Queda para ti (manual):")
    for item in "${MANUAL_ITEMS[@]}"; do report+=("  - $item"); done
fi
if [[ -f "$STATE_DIR/needs-relogin" ]] && ! $DRY_RUN; then
    report+=("" "Cierra sesión y vuelve a entrar:"); while IFS= read -r line; do report+=("  - $line"); done < "$STATE_DIR/needs-relogin"
fi
report+=("" "Recuperación:")
while IFS= read -r line; do report+=("  $line"); done < <(snapshot_recovery)
report+=("" "Respaldos: $BACKUP_DIR (solo si había algo que reemplazar) · Registro: $LOG"
         "Siguiente paso: cierra sesión → en el login elige «Hyprland»."
         "SUPER+Return terminal · SUPER+Space lanzador · SUPER+D notch · SUPER+L bloquear · SUPER+F1 atajos"
         "Actualizar: ./update.sh · Diagnóstico: ./doctor.sh · Revertir: ./uninstall.sh [--modules a,b]")
status=ok
(( doctor_rc > 0 )) && status=warn
for m in "${!RESULT[@]}"; do [[ "${RESULT[$m]}" == "con avisos" ]] && status=warn; done
$DRY_RUN && status=dry-run
finish "$status" "$(printf '%s\n' "${report[@]}")" 0
