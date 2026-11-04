#!/usr/bin/env bash
# =============================================================================
# dragon-island — instalador. Arch / EndeavourOS / CachyOS.  Un solo comando:  ./install.sh
# LINEAL a propósito: escanea → instala lo que falta (UN sudo pacman y paru) → despliega → servicios → llavero → verifica con doctor.sh.
# La salida real de pacman y paru se ve en pantalla; la presentación (lib/ui.sh) solo imprime. Ningún paso fallido aborta los demás
# y el resumen sale de las comprobaciones reales (pacman -T y doctor.sh), nunca de suponer éxito.
# La interfaz de pantalla alterna anterior sigue disponible con --tui (install-tui.sh).
# Requisitos previos: pre-instalation.md (compruébalos con ./doctor.sh --pre).
# =============================================================================
set -uo pipefail
shopt -s nullglob extglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$HOME/dragon-install.log"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$STATE_DIR/manifest"   # lines: <action>\t<target>\t<backup-or-source>

ALL_MODULES=(core shell editor taller archivos theme plugins login keyring keyboard boot extras)
# boot and extras are opt-in: boot touches /boot (its own question), extras installs your own apps
DEFAULT_MODULES=(core shell editor taller archivos theme plugins login keyring keyboard)
PHASES_TOTAL=7

CHECK_ONLY=false; CHECK_JSON=false; REQUESTED_PROFILES=""
DRY_RUN=false; ASSUME_YES=false; NO_SUDO=false; NO_UPDATE=false
DOCKER_GROUP_FLAG=false; LINK_MODE="symlink"; REQUESTED_MODULES=""
BOOTLOADER="auto"; BOOT_REVERT=false; RESTART=false
export DRAGON_EXTRAS="${DRAGON_EXTRAS:-}"

usage() {
    cat <<EOF
Uso: $0

Instala dragon-island de principio a fin con UN comando. Escribes tu clave de administrador una vez; el instalador escanea el
sistema, instala lo que falte (sudo pacman -S y paru), despliega las configuraciones, levanta los servicios, configura SDDM y el
llavero y lo comprueba todo con doctor.sh. No hace falta ninguna opción.

OPCIONES AVANZADAS (docs/INSTALL.md):
  --check              Preflight de solo lectura (conflictos y avisos); no cambia nada
  --json               JSON de --check
  --profiles a,b       Perfiles para --check (manifiesto packages/profiles.json)
  --dry-run            Muestra lo que haría sin cambiar nada (no pide sudo, no escribe en tu HOME)
  --yes, -y            Sin preguntas: respuestas por defecto (el grupo docker y el tema de arranque nunca se dan por sí solos)
  --modules a,b,c      Módulos a instalar: ${ALL_MODULES[*]}  (core siempre se incluye)
  --extras a,b         Extras sin preguntar: brave,protonvpn,herdr,myapps
  --bootloader B       Módulo boot: grub | limine | auto (por defecto detecta el que esté en uso)
  --revert-boot        Quita el tema de arranque (módulo boot) y vuelve a la configuración anterior
  --docker-group       Da de antemano la confirmación para añadirte al grupo docker (equivale a root)
  --no-sudo            Omite todo paso que necesite sudo (imprime el comando para hacerlo a mano)
  --no-update          Instala con «pacman -S» en vez de «pacman -Syu» (no actualiza el sistema entero)
  --copy               Copia los archivos en vez de enlazarlos (por defecto: symlink al repo)
  --restart            Olvida el progreso guardado de versiones anteriores
  --tui                Interfaz de pantalla alterna anterior (install-tui.sh); también --choose y --json-events
  --update | --doctor | --uninstall   Equivalen a ./update.sh · ./doctor.sh · ./uninstall.sh
  -h, --help           Esta ayuda
EOF
}

# --- hand over to the sibling scripts before anything else ---------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --update|--doctor|--uninstall)
            target="${arg#--}.sh"; args=()
            for a in "$@"; do [[ "$a" == "$arg" ]] || args+=("$a"); done
            exec "$REPO_DIR/$target" "${args[@]}" ;;
        --tui|--choose|--json-events)
            args=()
            for a in "$@"; do [[ "$a" == --tui ]] || args+=("$a"); done
            exec "$REPO_DIR/install-tui.sh" "${args[@]}" ;;
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
        --no-update) NO_UPDATE=true ;;
        --plain)     ;;     # kept for old command lines: this installer is always plain text
        --docker-group) DOCKER_GROUP_FLAG=true ;;
        --bootloader)   BOOTLOADER="${2:?--bootloader necesita grub, limine o auto}"; shift ;;
        --bootloader=*) BOOTLOADER="${1#*=}" ;;
        --revert-boot)  BOOT_REVERT=true ;;
        --copy)      LINK_MODE="copy" ;;
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

# --check: the SAME preflight function as the installer uses, read-only. Nothing is sourced, logged or created.
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
if $CHECK_JSON || [[ -n "$REQUESTED_PROFILES" ]]; then echo "--json y --profiles requieren --check." >&2; exit 2; fi

# --- the look is decided once, on the real terminal -----------------------------------------------------------------------------
INTERACTIVE=false
[[ -t 0 && -t 1 ]] && INTERACTIVE=true
$INTERACTIVE || ASSUME_YES=true      # nobody to ask: default answers (docker group and boot theme still need an explicit yes)
case "$(locale charmap 2>/dev/null || true)" in UTF-8) ;; *) export LC_ALL=C.UTF-8 ;; esac   # the frame is measured in characters

# shellcheck source=lib/ui.sh
. "$REPO_DIR/lib/ui.sh"
ui_init 1
# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
# shellcheck source=lib/preflight.sh
. "$REPO_DIR/lib/preflight.sh"
# shellcheck source=lib/snapshot.sh
. "$REPO_DIR/lib/snapshot.sh"
# shellcheck source=lib/report.sh
. "$REPO_DIR/lib/report.sh"
# shellcheck source=lib/linear.sh
. "$REPO_DIR/lib/linear.sh"
for m in "$REPO_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    . "$m"
done
$BOOT_REVERT && { boot_revert_all; exit $?; }
$RESTART && ! $DRY_RUN && rm -f "$STATE_DIR/install-progress"

VERSION_TEXT="$(< "$REPO_DIR/VERSION")"; VERSION_TEXT="${VERSION_TEXT//[$'\n\r ']/}"
TUI_VERSION="$VERSION_TEXT"          # read by lib/report.sh

# --- modules ---------------------------------------------------------------------------------------------------------------------
SELECTED=()
if [[ -n "$REQUESTED_MODULES" ]]; then IFS=',' read -r -a SELECTED <<<"$REQUESTED_MODULES"
else SELECTED=("${DEFAULT_MODULES[@]}"); fi
clean=(core)
for m in "${SELECTED[@]}"; do
    [[ " ${ALL_MODULES[*]} " == *" $m "* ]] || { echo "Módulo desconocido: $m (válidos: ${ALL_MODULES[*]})" >&2; exit 2; }
    [[ " ${clean[*]} " == *" $m "* ]] || clean+=("$m")
done
ORDERED=()
for m in "${ALL_MODULES[@]}"; do [[ " ${clean[*]} " == *" $m "* ]] && ORDERED+=("$m"); done
SELECTED=("${ORDERED[@]}")
has_module() { [[ " ${SELECTED[*]} " == *" $1 "* ]]; }
if [[ -z "${DRAGON_KB_LAYOUTS:-}" ]]; then      # the keyboard module would open an input box: the default layouts are used
    kb_saved="$(local_conf_get KB_LAYOUTS)"
    export DRAGON_KB_LAYOUTS="${kb_saved:-${KB_DEFAULT:-us,latam}}"
fi

# --- from here on everything printed also goes to ~/dragon-install.log (nothing in --dry-run) ---------------------------------------
lin_log_start
FINISHED=false; REPORT_EXIT=""; REPORT_PATH_SHOWN=""

# finish <ok|warn|incomplete|dry-run|error> <exit-code> <line>...: the report first (its path goes in the box), then the box
finish() {
    local status="$1" code="$2"; shift 2
    local lines=("$@") msg
    FINISHED=true; REPORT_EXIT="$code"
    if ! $DRY_RUN; then
        msg="$(printf '%s\n' "${lines[@]}")"
        report_write "$status" "$msg" >/dev/null
        [[ -n "$REPORT_PATH_SHOWN" ]] && lines+=("" "Informe: $REPORT_PATH_SHOWN · Registro: ~/dragon-install.log")
    else
        lines+=("" "Informe: en una instalación real se escribe en ~/dragon-informe.txt (en --dry-run no se escribe nada).")
    fi
    case "$status" in error) status=incomplete ;; esac
    ui_summary "$status" "${lines[@]}"
    exit "$code"
}

# shellcheck disable=SC2329  # called by the EXIT trap
cleanup() {
    local rc=$?
    sudo_end
    if ! $FINISHED && (( rc != 0 )); then
        # never a silent exit and never a success box
        printf '\n%s✘ El instalador se detuvo de forma inesperada (salida %s) en: %s%s\n  Reintenta con ./install.sh: lo ya instalado no se repite.\n' \
            "$(ui_c red)" "$rc" "${EV_LAST_STEP:-?}" "$(ui_c reset)"
        REPORT_EXIT="$rc"
        report_write error "El instalador terminó con salida $rc en la fase «${EV_LAST_PHASE:-?}», paso: ${EV_LAST_STEP:-?}" >/dev/null 2>&1 || true
        [[ -n "$REPORT_PATH_SHOWN" ]] && printf '  Informe: %s\n' "$REPORT_PATH_SHOWN"
    fi
    lin_log_stop
    return 0
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# =============================================================================
# Portada y escaneo
# =============================================================================
ui_banner "$VERSION_TEXT"
$DRY_RUN && ui_note "Modo --dry-run: no se cambia nada, no se pide sudo y no se escribe en tu HOME."
if [[ $EUID -eq 0 ]]; then finish error 1 "No ejecutes el instalador como root: usa tu usuario; sudo se pide solo cuando hace falta."; fi
command -v pacman >/dev/null 2>&1 || finish error 1 "No hay pacman: este instalador es para Arch, EndeavourOS y CachyOS." "Requisitos: pre-instalation.md"
detect_distro; detect_virt
$DISTRO_SUPPORTED || ui_warn "Distribución no probada: ${DISTRO_NAME}. Se continúa; los paquetes pueden diferir."
[[ "$VIRT_KIND" == none ]] || ui_note "Entorno virtual: $VIRT_KIND (la aceleración gráfica y SDDM pueden comportarse distinto)."
AUR_HELPER="$(aur_helper)"

# The preflight only WARNS (conflicts, desktops, ABI notes): it never blocks and never changes the exit code. ./install.sh --check shows it alone.
if [[ -z "${DRAGON_SKIP_PREFLIGHT:-}" ]]; then
    lin_step "Preflight (solo avisa)"
    pf_out="$(mktemp)"; pf_rc=0
    preflight --modules "$(IFS=,; echo "${SELECTED[*]}")" >"$pf_out" 2>&1 || pf_rc=$?
    if (( pf_rc > 1 )) || [[ ! -s "$pf_out" ]]; then
        ui_warn "El preflight no pudo ejecutarse (salida $pf_rc); se continúa. Detalle: ./install.sh --check"
    else
        pf_summary="$(sed -n '2p' "$pf_out")"
        if (( pf_rc == 1 )); then ui_warn "Preflight: ${pf_summary:-hay bloqueos} — solo aviso, no detiene la instalación. Detalle: ./install.sh --check"
        else ui_ok "Preflight: ${pf_summary:-sin bloqueos}"; fi
    fi
    rm -f "$pf_out"
fi

lin_step "Escaneo de paquetes"
if ! scan_packages; then finish error 1 "No se pudo escanear los paquetes (pacman -T o packages/profiles.json)." "Comprueba: pacman -T git  ·  python3 lib/manifest.py --source pacman"; fi
ui_info_box "$DISTRO_NAME" "$(uname -r)" "$(human_ram)" "${PROFILES_TEXT:-?}" "${#OFF_MISSING[@]}" "${#AUR_MISSING[@]}"
if (( ${#OFF_MISSING[@]} + ${#AUR_MISSING[@]} > 0 )); then
    echo
    (( ${#OFF_MISSING[@]} == 0 )) || ui_wrap_list "faltan ${#OFF_MISSING[@]} paquetes oficiales:" "${OFF_MISSING[@]}"
    (( ${#AUR_MISSING[@]} == 0 )) || ui_wrap_list "faltan ${#AUR_MISSING[@]} paquetes AUR ($AUR_HELPER):" "${AUR_MISSING[@]}"
fi
echo; ui_note "Módulos: ${SELECTED[*]} · despliegue: $LINK_MODE · ayudante AUR: ${AUR_HELPER:-ninguno}"

if ! $DRY_RUN && ! $NO_SUDO && $INTERACTIVE && ! $ASSUME_YES; then
    echo
    if ! ask_plain "¿Instalar todo ahora? (sudo se pide una sola vez; cada paso con sudo se anuncia)" yes; then
        finish ok 0 "Cancelado: no se cambió nada."
    fi
fi
PLAN_CONFIRMED=true
export DRAGON_PKGS_DONE=1 DRAGON_DEFER_SERVICES=1

if ! $DRY_RUN; then
    mkdir -p "$STATE_DIR"
    if ! $NO_SUDO; then
        sudo_begin || finish error 1 "sudo no autorizó la sesión: sin él no se pueden instalar paquetes." "Repite ./install.sh o prueba:  sudo -v"
    fi
    snapshot_create >/dev/null 2>&1 || true
fi

# =============================================================================
# [1/7] Paquetes oficiales — UNA llamada a sudo pacman
# =============================================================================
lin_phase 1 "Paquetes oficiales"
install_official
show_package_result off

# =============================================================================
# [2/7] Paquetes AUR — con el ayudante detectado
# =============================================================================
lin_phase 2 "Paquetes AUR"
install_aur
show_package_result aur
verify_packages
if [[ ! -d "${DRAGON_PREFLIGHT_ROOT:-}/usr/lib/modules/$(uname -r)" ]] && ! $DRY_RUN; then
    NEEDS_REBOOT=true; ui_warn "El kernel se actualizó: reinicia al terminar para usar el nuevo."
fi

# =============================================================================
# [3/7] Despliegue — enlaces y configuración (backup_copy de lo existente)
# =============================================================================
lin_phase 3 "Despliegue"
for m in "${SELECTED[@]}"; do
    case "$m" in login|boot) continue ;; esac     # their own phases (SDDM · Arranque)
    run_mod "$m" "${m}_apply" "despliegue" quiet
done
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
# [4/7] Servicios y SDDM
# =============================================================================
lin_phase 4 "Servicios y SDDM"
$NO_SUDO || $DRY_RUN || sudo_ensure || true
run_mod core core_services "servicios"
has_module taller && run_mod taller taller_docker_service "docker"
if has_module login; then run_mod login login_apply "SDDM y su tema"; fi
$DRY_RUN || check_services

# =============================================================================
# [5/7] Llavero y grupos
# =============================================================================
lin_phase 5 "Llavero y grupos"
has_module keyring && run_mod keyring keyring_services "llavero (PAM)"
has_module taller && run_mod taller taller_group "grupo docker"
for m in "${SELECTED[@]}"; do
    case "$m" in core|keyring|taller) continue ;; esac
    declare -F "${m}_services" >/dev/null && run_mod "$m" "${m}_services" "servicios"
done

# =============================================================================
# [6/7] Arranque — opt-in, con su propia pregunta
# =============================================================================
lin_phase 6 "Arranque (GRUB/Limine)"
if has_module boot; then run_mod boot boot_apply "tema de arranque"
elif $DRY_RUN || $ASSUME_YES; then ui_skip "Tema de arranque: no solicitado (opt-in: ./install.sh --modules boot)."
else
    if confirm_default_no "¿Instalar también el tema de arranque (GRUB/Limine)? Toca /boot; pregunta antes de cada paso."; then
        SELECTED+=(boot); run_mod boot boot_apply "tema de arranque"
    else ui_skip "Tema de arranque: omitido por ti (opt-in: ./install.sh --modules boot)."; fi
fi

# =============================================================================
# [7/7] Verificación — doctor.sh decide cómo se lee el resumen
# =============================================================================
lin_phase 7 "Verificación"
if $DRY_RUN; then ui_skip "Verificación omitida en --dry-run (no hay nada instalado que comprobar)."
else
    lin_step "doctor.sh"
    sudo_end
    doctor_verify
    if (( DOCTOR_RC == 0 )); then ui_ok "doctor.sh: todo en orden"
    else ui_fail "doctor.sh encontró $DOCTOR_RC problema(s); el resumen los lista con su comando."; fi
fi

# =============================================================================
# Resumen honesto: «completa» solo si doctor.sh pasa; «incompleta» con el comando exacto de cada punto
# =============================================================================
lines=()
if $DRY_RUN; then
    lines+=("Faltan ${#OFF_MISSING[@]} paquetes oficiales y ${#AUR_MISSING[@]} AUR (se instalarían en una ejecución real).")
    for m in "${SELECTED[@]}"; do lines+=("• $m: simulado"); done
    lines+=("" "Nada se instaló ni se cambió. Para instalar: ./install.sh")
    finish dry-run 0 "${lines[@]}"
fi

status=ok; code=0
res_line() { printf '%s' "${RESULT[$1]:-omitido (no se ejecutó)}"; }
lines+=("Paquetes oficiales: $N_OFF_NEW instalados ahora · $(( ${#OFF_ALL[@]} - N_OFF_NEW - N_OFF_BAD )) ya estaban · $N_OFF_BAD con problema")
lines+=("Paquetes AUR: $N_AUR_NEW instalados ahora · $(( ${#AUR_ALL[@]} - N_AUR_NEW - N_AUR_BAD )) ya estaban · $N_AUR_BAD con problema")
lines+=("Enlaces en tu HOME: $(count_links) ($LINK_MODE) · Servicios habilitados: $SERVICES_OK")
for m in "${SELECTED[@]}"; do
    r="$(res_line "$m")"
    lines+=("• $m: $r")
    case "$r" in ok) ;; "con avisos"*) [[ "$status" == ok ]] && status=warn ;; *) status=incomplete ;; esac
done
if (( ${#PKG_FAILED[@]} > 0 )); then
    status=incomplete; lines+=("" "PAQUETES CON PROBLEMA:")
    for p in "${PKG_FAILED[@]}"; do lines+=("  ✘ $p"); done
fi
if (( ${#PKG_SKIPPED[@]} > 0 )); then
    [[ "$status" == ok ]] && status=warn
    lines+=("" "OMITIDOS:"); for p in "${PKG_SKIPPED[@]}"; do lines+=("  ○ $p"); done
fi
if (( DOCTOR_RC > 0 || ${#MISSING_ITEMS[@]} > 0 || ${#SERVICE_PROBLEMS[@]} > 0 )); then
    status=incomplete
    lines+=("" "FALTA (según doctor.sh y la fase de servicios), con su comando:")
    for item in "${MISSING_ITEMS[@]}" "${SERVICE_PROBLEMS[@]}"; do lines+=("  ✘ $item"); done
fi
if [[ "$status" == incomplete ]]; then
    code=1
    lines+=("" "Repite ./install.sh: lo ya instalado no se repite. O ejecuta los comandos de arriba.")
else
    (( ${#MANUAL_ITEMS[@]} > 0 )) && { lines+=("" "Queda para ti (manual):"); for item in "${MANUAL_ITEMS[@]}"; do lines+=("  - $item"); done; }
    [[ -f "$STATE_DIR/needs-relogin" ]] && { lines+=("" "Cierra sesión y vuelve a entrar:"); while IFS= read -r l; do lines+=("  - $l"); done < "$STATE_DIR/needs-relogin"; }
    ${NEEDS_REBOOT:-false} && lines+=("" "Reinicia: el kernel se actualizó.")
    lines+=("" "Reinicia y elige «Hyprland» en SDDM." "SUPER+Return terminal · SUPER+Space lanzador · SUPER+L bloquear · SUPER+F1 atajos")
fi
lines+=("Actualizar: ./update.sh · Diagnóstico: ./doctor.sh · Revertir: ./uninstall.sh")
finish "$status" "$code" "${lines[@]}"
