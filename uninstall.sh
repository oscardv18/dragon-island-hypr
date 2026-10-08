#!/usr/bin/env bash
# =============================================================================
# dragon-island — uninstaller. Reverts only what the installer did (links, marked lines, login theme, PAM copy),
# restoring the backups recorded in the manifest. It does NOT uninstall packages unless you ask, module by module.
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/uninstall.log"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$STATE_DIR/manifest"
ALL_MODULES=(core shell theme plugins login keyring keyboard extras)

DRY_RUN=false
ASSUME_YES=false
NO_SUDO=false
REMOVE_PACKAGES=false
REQUESTED=""
LINK_MODE="symlink"

usage() {
    cat <<EOT
Uso: $0 [OPCIONES]

Revierte lo que instaló dragon-island. Los paquetes NO se desinstalan salvo con --remove-packages.

OPCIONES:
  --modules a,b        Solo esos módulos (por defecto, todos los instalados: ${ALL_MODULES[*]})
  --remove-packages    Además pregunta, módulo a módulo, si desinstalar sus paquetes (pacman -Rns, con sudo)
  --dry-run            Muestra lo que haría sin cambiar nada
  --yes, -y            Sin preguntas (los pasos con sudo siguen mostrando qué hacen)
  --no-sudo            Omite los pasos con sudo
  -h, --help           Esta ayuda
EOT
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --yes|-y) ASSUME_YES=true ;;
        --no-sudo) NO_SUDO=true ;;
        --remove-packages) REMOVE_PACKAGES=true ;;
        --modules) REQUESTED="${2:?--modules necesita una lista}"; shift ;;
        --modules=*) REQUESTED="${1#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
[[ -t 0 && -t 1 ]] || ASSUME_YES=true
[[ $EUID -ne 0 ]] || { echo "ERROR: no ejecutes el desinstalador como root." >&2; exit 1; }

if ! $DRY_RUN; then
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$LOG") 2>&1
fi

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
for m in "$REPO_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    . "$m"
done
[[ -f "$STATE_DIR/link-mode" ]] && LINK_MODE="$(< "$STATE_DIR/link-mode")"

# which modules: the requested ones, else the installed ones (state file), else all (legacy installs)
TARGETS=()
if [[ -n "$REQUESTED" ]]; then IFS=',' read -r -a TARGETS <<<"$REQUESTED"
elif [[ -f "$STATE_DIR/modules" ]]; then mapfile -t TARGETS < "$STATE_DIR/modules"
else TARGETS=("${ALL_MODULES[@]}"); fi
for m in "${TARGETS[@]}"; do
    [[ " ${ALL_MODULES[*]} " == *" $m "* ]] || { echo "Módulo desconocido: $m" >&2; exit 2; }
done

box "#ed254e" "Desinstalador de dragon-island" \
    "Módulos a revertir: ${TARGETS[*]}" \
    "Se retiran enlaces y líneas marcadas y se restauran los respaldos del manifiesto." \
    "Los paquetes NO se desinstalan (salvo --remove-packages, módulo a módulo)."
$DRY_RUN || confirm "¿Proceder con la desinstalación?" || exit 0

# reverse order of installation: extras ... core
for (( i=${#ALL_MODULES[@]}-1; i>=0; i-- )); do
    m="${ALL_MODULES[i]}"
    [[ " ${TARGETS[*]} " == *" $m "* ]] || continue
    box "#7c3aed" "Revirtiendo: $m"
    "${m}_revert" || log_warn "$m: la reversión terminó con avisos."
    if $REMOVE_PACKAGES && [[ "$m" != core || -n "$REQUESTED" ]]; then
        mapfile -t pk < <("${m}_packages" 2>/dev/null | while read -r p; do pkg_installed "$p" && echo "$p"; done)
        if [[ ${#pk[@]} -gt 0 ]] && ! $ASSUME_YES && confirm "¿Desinstalar los paquetes de «$m»? (${pk[*]})"; then
            confirm_sudo "Desinstalar paquetes de $m: ${pk[*]}" pacman -Rns "${pk[@]}" || true
        elif [[ ${#pk[@]} -gt 0 ]]; then
            log_info "Paquetes de $m no desinstalados (hace falta confirmación interactiva): ${pk[*]}"
        fi
    fi
done

if ! $DRY_RUN; then
    if [[ -f "$STATE_DIR/modules" ]]; then
        remaining=(); while read -r m; do [[ " ${TARGETS[*]} " == *" $m "* ]] || remaining+=("$m"); done < "$STATE_DIR/modules"
        if [[ ${#remaining[@]} -gt 0 ]]; then printf '%s\n' "${remaining[@]}" > "$STATE_DIR/modules"
        else rm -f "$STATE_DIR/modules" "$STATE_DIR/link-mode" "$STATE_DIR/plugins.pending"; fi
    fi
fi
box "#06c993" "Desinstalación terminada" "" \
    "  • Revertido: ${TARGETS[*]}" \
    "  • Respaldos y registro conservados en: $STATE_DIR" \
    "  • Reinstalar: ./install.sh"
