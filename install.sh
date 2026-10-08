#!/usr/bin/env bash
# =============================================================================
# dragon-island — modular installer (gum TUI). Arch / EndeavourOS / CachyOS.
# Requirements BEFORE running it: pre-instalation.md (check them with ./doctor.sh --pre).
# Modules: core (mandatory) shell theme plugins login keyring keyboard extras — see docs/INSTALL.md.
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/install.log"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$STATE_DIR/manifest"   # lines: <action>\t<target>\t<backup-or-source>

ALL_MODULES=(core shell theme plugins login keyring keyboard extras)
DEFAULT_MODULES=(core shell theme plugins keyboard)   # login, keyring and extras touch /etc or install apps: opt-in

DRY_RUN=false
ASSUME_YES=false
NO_SUDO=false
LINK_MODE="symlink"
REQUESTED_MODULES=""
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
  --dry-run            Muestra el plan completo sin cambiar nada (no pide sudo, no escribe en tu HOME)
  --yes, -y            Modo desatendido: respuestas por defecto. Los pasos con sudo siguen mostrando qué hacen
  --modules a,b,c      Módulos a instalar: ${ALL_MODULES[*]}  (core siempre se incluye)
  --extras a,b         Extras sin preguntar: brave,protonvpn,herdr,myapps
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
        --dry-run)   DRY_RUN=true ;;
        --yes|-y)    ASSUME_YES=true ;;
        --no-sudo)   NO_SUDO=true ;;
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
export DRAGON_EXTRAS

[[ -t 0 && -t 1 ]] || ASSUME_YES=true

# dry-run must not write anywhere: no state dir, no log
if $DRY_RUN; then
    LOG=/dev/null
else
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$LOG") 2>&1
fi
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&2' ERR

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
# shellcheck source=lib/checks.sh
. "$REPO_DIR/lib/checks.sh"
for m in "$REPO_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    . "$m"
done

# --dry-run without gum: nothing can be prompted
if $DRY_RUN && ! has_gum; then ASSUME_YES=true; fi

# =============================================================================
# Preflight: every failure names the step of pre-instalation.md that fixes it
# =============================================================================
box "#c50ed2" "dragon-island — Instalador" \
    "Hyprland 0.56 (Lua) + Quickshell 0.3 · Arch / EndeavourOS / CachyOS" \
    "Requisitos previos: $PRE_DOC"
$DRY_RUN && log_info "Modo --dry-run: no se cambia nada."

# hard failures stop a real run (a dry run reports them and goes on, to show the plan)
hard=0
for id in root distro base aur network versions; do
    "check_$id" || hard=$((hard + 1))
done
# soft: warn only
for id in gpu dm time disk; do "check_$id" || true; done
if (( hard > 0 )); then
    if $DRY_RUN; then log_warn "$hard requisito(s) previos fallan (arriba). En una instalación real el instalador se detendría aquí."
    else echo "Corrige los requisitos marcados y vuelve a ejecutar (comprueba: ./doctor.sh --pre)." >&2; exit 1; fi
fi
AUR_HELPER="$(aur_helper)"

if pacman -Qq plasma-desktop >/dev/null 2>&1 || pacman -Qq plasma-workspace >/dev/null 2>&1; then
    log_info "KDE Plasma detectado: Hyprland se instala como sesión adicional (Plasma no se toca)."
fi

# =============================================================================
# Module selection
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
# Plan
# =============================================================================
echo
echo "== Plan =="
echo "Módulos: ${SELECTED[*]} · despliegue: $LINK_MODE · sudo: $($NO_SUDO && echo desactivado || echo "con confirmación en cada paso")"
for m in "${SELECTED[@]}"; do
    echo "• $m — $("${m}_desc")"
    "${m}_plan"
    echo "    sudo: $("${m}_sudo")"
done
echo
if ! $DRY_RUN && ! confirm "¿Aplicar este plan?"; then log_info "Cancelado."; exit 0; fi

# sudo once, kept alive while the installer runs (never stores or asks for the password itself)
if ! $DRY_RUN && ! $NO_SUDO; then
    sudo -v
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE=$!
    trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT
fi

# one full upgrade first (never a partial upgrade), then -S --needed without -y
confirm_sudo "Actualizar el sistema (pacman -Syu) antes de instalar: evita actualizaciones parciales" pacman -Syu --noconfirm || true

# =============================================================================
# Apply
# =============================================================================
declare -A RESULT=()
for m in "${SELECTED[@]}"; do
    box "#7c3aed" "Módulo: $m" "$("${m}_desc")"
    if "${m}_apply"; then RESULT[$m]="ok"; else RESULT[$m]="con avisos"; fi
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
# Final: doctor + summary
# =============================================================================
if ! $DRY_RUN; then "$REPO_DIR/doctor.sh" || log_warn "doctor.sh encontró problemas (arriba); sigue sus indicaciones."; fi

lines=("")
for m in "${SELECTED[@]}"; do lines+=("  • $m: ${RESULT[$m]:-(dry-run)}"); done
lines+=("" "  • Respaldos: $BACKUP_DIR (solo si había algo que reemplazar)" "  • Registro: $LOG" "")
has_module plugins && lines+=("  • Plugins: si no estabas dentro de Hyprland, se compilan en tu primer inicio de sesión (se abre una terminal)." "")
has_module login && lines+=("  • Login: reinicia para ver el tema (SDDM)." "")
lines+=(
    "Siguiente paso: cierra sesión → en el login elige «Hyprland»."
    "  SUPER + Return terminal · SUPER + Space lanzador · SUPER + D notch · SUPER + L bloquear · SUPER + F1 atajos"
    ""
    "Revertir: ./uninstall.sh [--modules a,b]   ·   Actualizar: ./update.sh   ·   Diagnóstico: ./doctor.sh"
)
$DRY_RUN && title="dragon-island: instalación simulada (dry-run)" || title="dragon-island: instalación terminada"
box "#06c993" "$title" "${lines[@]}"
