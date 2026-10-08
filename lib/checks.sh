#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables shared with the scripts that source this file
# =============================================================================
# dragon-island — preflight / prerequisite checks (sourced by install.sh and doctor.sh --pre).
# ONE table: check id → "<step number>|<title>" of pre-instalation.md. tests/check-docs.sh verifies every step
# exists in that file, so the code and the guide cannot diverge. A failing check prints the step that fixes it.
# =============================================================================
declare -gA CHECK_STEP=(
    [distro]="1|Instalar EndeavourOS"
    [root]="10|Primera ejecución"
    [sudo]="1|Instalar EndeavourOS"
    [mirrors]="2|Primer arranque"
    [base]="3|Herramientas base"
    [aur]="3|Herramientas base"
    [network]="4|Red y hora"
    [time]="4|Red y hora"
    [gpu]="5|Driver de video"
    [dm]="6|Display manager y Plasma"
    [keymap]="7|Teclado y locale"
    [repo]="8|Acceso al repo"
    [versions]="2|Primer arranque"
    [disk]="12|Problemas comunes antes del script"
)

BASE_TOOLS=(git curl unzip gum)   # commands; base-devel (a group) and the AUR helper are checked separately

# Every check_* prints nothing on success, calls fail_step and returns 1 on failure.
# Callers collect failures; nothing here exits.
check_root() { [[ $EUID -ne 0 ]] || { fail_step root "Estás ejecutando como root: el instalador debe correr con tu usuario."; return 1; }; }

check_distro() {
    detect_distro
    $DISTRO_SUPPORTED && return 0
    fail_step distro "Distro no soportada: $DISTRO_NAME. Solo Arch y derivadas (EndeavourOS, Arch, CachyOS). Otras: docs/INSTALL.md."
    return 1
}

check_sudo() {
    command -v sudo >/dev/null 2>&1 || { fail_step sudo "sudo no está instalado."; return 1; }
    id -nG | tr ' ' '\n' | grep -qxE 'wheel|sudo' || { fail_step sudo "Tu usuario ($USER) no está en el grupo wheel: sin sudo no se pueden instalar paquetes."; return 1; }
}

check_base() {
    local t rc=0
    for t in "${BASE_TOOLS[@]}"; do
        command -v "$t" >/dev/null 2>&1 || { fail_step base "Falta $t."; rc=1; }
    done
    pkg_installed base-devel || { fail_step base "Falta base-devel."; rc=1; }
    command -v gh >/dev/null 2>&1 || log_warn "github-cli (gh) no está: solo hace falta si clonas por HTTPS con gh (Paso 8)."
    return $rc
}

check_aur() {
    [[ -n "$(aur_helper)" ]] && return 0
    fail_step aur "No hay yay ni paru (ayudante de AUR)."
    return 1
}

check_network() {
    curl -fsS --max-time 6 -o /dev/null https://archlinux.org && return 0
    fail_step network "Sin conexión a internet (no se alcanza archlinux.org)."
    return 1
}

check_time() {
    if command -v timedatectl >/dev/null 2>&1 && [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" == "yes" ]]; then return 0; fi
    fail_step time "La hora no está sincronizada por NTP: una hora incorrecta rompe HTTPS y las firmas de pacman."
    return 1
}

# GPU: the installer never installs drivers. Warn-level: returns 1 so doctor shows ✘, install.sh only warns.
check_gpu() {
    detect_gpu
    if [[ "$GPU_VENDOR" == "unknown" ]]; then
        fail_step gpu "No se pudo identificar la GPU (¿falta pciutils / lspci?)."
        return 1
    fi
    $GPU_DRIVER_LOADED && return 0
    fail_step gpu "La GPU ($GPU_VENDOR: $GPU_NAME) no tiene driver del kernel cargado."
    return 1
}

check_dm() {
    local dm; dm="$(display_manager)"
    case "$dm" in
        sddm) return 0 ;;
        plasmalogin) log_warn "Display manager: Plasma Login Manager. Hyprland arranca igual, pero el tema de login solo funciona con SDDM (Paso 6)."; return 0 ;;
        *) fail_step dm "No hay un display manager activo reconocido (se encontró: $dm)."; return 1 ;;
    esac
}

check_keymap() {
    command -v localectl >/dev/null 2>&1 || return 0
    local x11; x11="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/ {print $2}')"
    [[ "$x11" == us* ]] && return 0
    fail_step keymap "El teclado del login es «${x11:-sin definir}»; debe empezar por us (us,latam)."
    return 1
}

check_versions() {
    # Hyprland >= 0.55 (Lua config) and Quickshell >= 0.3: the installed one, or what the repos offer if not installed yet
    local rc=0 v
    v="$(installed_version hyprland)"; [[ -n "$v" ]] || v="$(repo_version hyprland)"
    if [[ -z "$v" ]]; then log_warn "No se pudo saber la versión de Hyprland (¿bases de pacman sin sincronizar?)."
    elif ! ver_ge "$v" 0.55; then fail_step versions "Hyprland $v es anterior a 0.55 (la config Lua lo exige). Actualiza el sistema."; rc=1; fi
    v="$(installed_version quickshell)"; [[ -n "$v" ]] || v="$(repo_version quickshell)"
    if [[ -z "$v" ]]; then log_warn "No se pudo saber la versión de Quickshell."
    elif ! ver_ge "$v" 0.3; then fail_step versions "Quickshell $v es anterior a 0.3."; rc=1; fi
    return $rc
}

check_disk() {
    local free_kb; free_kb="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
    [[ "${free_kb:-0}" -ge 5242880 ]] && return 0
    fail_step disk "Menos de 5 GB libres en $HOME."
    return 1
}

# run_checks <id>...  → number of failures
run_checks() {
    local id fails=0
    for id in "$@"; do "check_$id" || fails=$((fails + 1)); done
    return "$fails"
}
