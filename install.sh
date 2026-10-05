#!/usr/bin/env bash
# =============================================================================
# dragon-island — Interactive TUI Installer & Dotfiles Manager
# Target: Arch Linux / EndeavourOS with gum TUI
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/install.log"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_DIR/backups/$TS"
MANIFEST="$STATE_DIR/manifest"

DRY_RUN=false
ASSUME_YES=false
MODE="install"
LINK_MODE="symlink"

# Gum styling variables (Sweet / Garuda Dragonized palette)
export GUM_CHOOSE_CURSOR_FOREGROUND="#00c1e4"
export GUM_CHOOSE_SELECTED_FOREGROUND="#c50ed2"
export GUM_CONFIRM_SELECTED_BACKGROUND="#7c3aed"
export GUM_CONFIRM_SELECTED_FOREGROUND="#ffffff"
export GUM_SPIN_SPINNER_FOREGROUND="#c50ed2"

usage() {
    cat <<EOF
Uso: $0 [OPCIONES]

Instalador modular con interfaz TUI para dragon-island en Arch Linux / EndeavourOS.

OPCIONES:
  --dry-run       Muestra las acciones sin ejecutarlas
  --yes, -y       Modo desatendido: usa valores por defecto sin preguntas
  --uninstall     Desinstala dragon-island y restaura copias de seguridad
  -h, --help      Muestra esta ayuda
EOF
}

# Parse CLI arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --yes|-y)    ASSUME_YES=true ;;
        --uninstall) MODE="uninstall" ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $arg" >&2; exit 2 ;;
    esac
done

[[ -t 0 && -t 1 ]] || ASSUME_YES=true

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&2' ERR

run() {
    if $DRY_RUN; then
        printf '[dry-run] %q ' "$@"
        echo
    else
        "$@"
    fi
}

log_info() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level info "$1"
    else
        echo ":: $1"
    fi
}

log_warn() {
    if command -v gum >/dev/null 2>&1; then
        gum log --level warn "$1"
    else
        echo ":: ADVERTENCIA: $1"
    fi
}

# =============================================================================
# Modo Desinstalación (--uninstall)
# =============================================================================
do_uninstall() {
    if command -v gum >/dev/null 2>&1; then
        gum style --border rounded --border-foreground "#ed254e" --padding "1 2" \
            "Desinstalador de dragon-island" "Se revertirán los archivos desplegados y restaurarán respaldos."
        if ! $ASSUME_YES; then
            gum confirm "¿Deseas proceder con la desinstalación?" || exit 0
        fi
    fi

    if [[ ! -f "$MANIFEST" ]]; then
        echo "No se encontró el archivo de manifiesto en $MANIFEST. Nada que desinstalar."
        exit 0
    fi

    log_info "Procesando manifiesto en orden inverso..."
    local lines=()
    mapfile -t lines < "$MANIFEST"

    for (( idx=${#lines[@]}-1; idx>=0; idx-- )); do
        local line="${lines[idx]}"
        [[ -z "$line" ]] && continue
        local action target extra
        action="$(echo "$line" | cut -f1)"
        target="$(echo "$line" | cut -f2)"
        extra="$(echo "$line" | cut -f3)"

        if [[ "$action" == "deploy" ]]; then
            if [[ -L "$target" || -e "$target" ]]; then
                log_info "Eliminando objetivo desplegado: $target"
                run rm -rf "$target"
            fi
        elif [[ "$action" == "backup" ]]; then
            if [[ -e "$extra" ]]; then
                log_info "Restaurando respaldo: $extra -> $target"
                run mkdir -p "$(dirname "$target")"
                run mv "$extra" "$target"
            fi
        fi
    done

    # Remove firstrun marker if present
    run rm -f "$STATE_DIR/firstrun.done"
    run rm -f "$MANIFEST"

    echo
    if command -v gum >/dev/null 2>&1; then
        gum style --border rounded --border-foreground "#06c993" --padding "1 2" \
            "Desinstalación finalizada" "Los dotfiles y respaldos fueron revertidos correctamente."
    else
        echo "Desinstalación finalizada con éxito."
    fi
    exit 0
}

if [[ "$MODE" == "uninstall" ]]; then
    do_uninstall
fi

# =============================================================================
# Preflight Checks
# =============================================================================
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Por seguridad, no ejecutes este instalador como root." >&2
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: No se detectó un sistema Linux compatible." >&2
    exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
if [[ "$ID" != "arch" && "$ID" != "endeavouros" && " ${ID_LIKE:-} " != *" arch "* ]]; then
    echo "ERROR: Este instalador solo es compatible con Arch Linux y EndeavourOS." >&2
    exit 1
fi

if ! curl -fsS --max-time 5 -o /dev/null https://archlinux.org; then
    echo "ERROR: No hay conexión a internet disponible." >&2
    exit 1
fi

# Ensure gum is installed
if ! command -v gum >/dev/null 2>&1; then
    echo ":: Instalando gum para la interfaz gráfica de terminal..."
    run sudo pacman -S --needed --noconfirm gum
fi

# Detect or install AUR helper (yay or paru)
AUR_HELPER=""
for h in yay paru; do
    if command -v "$h" >/dev/null 2>&1; then
        AUR_HELPER="$h"
        break
    fi
done

if [[ -z "$AUR_HELPER" ]]; then
    if $ASSUME_YES; then
        INSTALL_YAY=true
    else
        gum style --border normal --border-foreground "#f9ae58" \
            "No se detectó un ayudante de AUR (yay o paru)."
        INSTALL_YAY=false
        if gum confirm "¿Deseas compilar e instalar yay-bin automáticamente?"; then
            INSTALL_YAY=true
        fi
    fi

    if $INSTALL_YAY; then
        log_info "Instalando yay-bin desde AUR..."
        BUILD_DIR="$(mktemp -d)"
        run git clone https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay-bin"
        ( cd "$BUILD_DIR/yay-bin" && run makepkg -si --noconfirm )
        run rm -rf "$BUILD_DIR"
        AUR_HELPER="yay"
    else
        log_warn "Se continuará sin AUR helper. Los paquetes de AUR deberán instalarse manualmente."
    fi
fi

# Keep sudo credentials alive in background
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

# =============================================================================
# Bienvenida y Selección de Componentes
# =============================================================================
gum style --border rounded --border-foreground "#c50ed2" --padding "1 2" --foreground "#e6e8ef" \
    "dragon-island — Instalador de Entorno de Escritorio" \
    "Hyprland 0.56.x (Lua) + Quickshell 0.3.1 (Dynamic Island)" \
    "Base: EndeavourOS / Arch Linux (Coexistencia segura con KDE Plasma)"

# Full system update prompt
if ! $ASSUME_YES; then
    if gum confirm "¿Deseas realizar una actualización completa del sistema (pacman -Syu)?"; then
        log_info "Actualizando repositorios y paquetes del sistema..."
        run sudo pacman -Syu --noconfirm
    fi
fi

# Choose installation mode
if ! $ASSUME_YES; then
    CHOICE="$(gum choose --header "¿Método de despliegue para los archivos de configuración?" \
        "Symlink (Recomendado para desarrollo/actualizaciones de git)" \
        "Copia (Archivos independientes en ~/.config)")"
    if [[ "$CHOICE" == Copia* ]]; then
        LINK_MODE="copy"
    else
        LINK_MODE="symlink"
    fi
fi

# Component selection
SELECTED_COMPONENTS=("core" "shell" "plugins" "fonts" "services")
if ! $ASSUME_YES; then
    mapfile -t SELECTED_COMPONENTS < <(gum choose --no-limit \
        --header "Selecciona los componentes a instalar (Espacio para marcar/desmarcar, Enter para confirmar):" \
        --selected "core,shell,plugins,fonts,services" \
        "core" \
        "shell" \
        "plugins" \
        "fonts" \
        "services")
fi

has_component() {
    local target="$1"
    for c in "${SELECTED_COMPONENTS[@]}"; do
        [[ "$c" == "$target" ]] && return 0
    done
    return 1
}

# =============================================================================
# Instalación de Paquetes
# =============================================================================
PACMAN_FILE="$REPO_DIR/packages/pacman.txt"
AUR_FILE="$REPO_DIR/packages/aur.txt"

if [[ -f "$PACMAN_FILE" ]]; then
    mapfile -t ALL_PACMAN_PKGS < <(grep -vE '^\s*(#|$)' "$PACMAN_FILE")
    if [[ ${#ALL_PACMAN_PKGS[@]} -gt 0 ]]; then
        log_info "Instalando paquetes desde repositorios oficiales..."
        run sudo pacman -S --needed --noconfirm "${ALL_PACMAN_PKGS[@]}"
    fi
fi

if [[ -n "$AUR_HELPER" && -f "$AUR_FILE" ]]; then
    mapfile -t ALL_AUR_PKGS < <(grep -vE '^\s*(#|$)' "$AUR_FILE")
    if [[ ${#ALL_AUR_PKGS[@]} -gt 0 ]]; then
        log_info "Instalando paquetes desde AUR con $AUR_HELPER..."
        run "$AUR_HELPER" -S --needed --noconfirm "${ALL_AUR_PKGS[@]}"
    fi
fi

# =============================================================================
# Despliegue de Configuraciones (Idempotente + Respaldos)
# =============================================================================
deploy_item() {
    local src="$1"
    local dest="$2"

    # Already deployed as symlink pointing to our repo? Skip!
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Ya enlazado correctamente: $dest"
        return 0
    fi

    # Backup existing file/dir
    if [[ -e "$dest" || -L "$dest" ]]; then
        local rel_path="${dest#"$HOME"/}"
        run mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
        run mv "$dest" "$BACKUP_DIR/$rel_path"
        $DRY_RUN || printf 'backup\t%s\t%s\n' "$dest" "$BACKUP_DIR/$rel_path" >> "$MANIFEST"
        log_info "Respaldo creado: $dest -> $BACKUP_DIR/$rel_path"
    fi

    run mkdir -p "$(dirname "$dest")"
    if [[ "$LINK_MODE" == "symlink" ]]; then
        run ln -sfn "$src" "$dest"
        log_info "Enlace creado: $dest -> $src"
    else
        run cp -a "$src" "$dest"
        log_info "Copia creada: $dest"
    fi

    $DRY_RUN || printf 'deploy\t%s\t%s\n' "$dest" "$src" >> "$MANIFEST"
}

log_info "Desplegando archivos de configuración..."

if has_component "core"; then
    deploy_item "$REPO_DIR/config/hypr" "$HOME/.config/hypr"
    deploy_item "$REPO_DIR/config/kitty" "$HOME/.config/kitty"
fi

if has_component "shell"; then
    deploy_item "$REPO_DIR/config/quickshell" "$HOME/.config/quickshell"
fi

if has_component "plugins"; then
    # Deploy first-run script into ~/.local/state/dragon-island/firstrun.sh
    run mkdir -p "$STATE_DIR"
    deploy_item "$REPO_DIR/installer/firstrun.sh" "$STATE_DIR/firstrun.sh"
    run chmod +x "$STATE_DIR/firstrun.sh"
fi

# =============================================================================
# Habilitación de Servicios del Sistema
# =============================================================================
if has_component "services"; then
    log_info "Configurando servicios del sistema..."
    SYSTEM_SERVICES=("NetworkManager" "bluetooth" "power-profiles-daemon")
    for s in "${SYSTEM_SERVICES[@]}"; do
        if systemctl is-active --quiet "$s" 2>/dev/null; then
            log_info "Servicio $s ya está activo."
        else
            log_info "Habilitando e iniciando servicio: $s"
            run sudo systemctl enable --now "$s" || log_warn "No se pudo habilitar $s"
        fi
    done
fi

# =============================================================================
# Pantalla Final y Resumen
# =============================================================================
echo
gum style --border rounded --border-foreground "#06c993" --padding "1 2" \
    "¡Instalación de dragon-island completada con éxito!" \
    "" \
    "Resumen:" \
    "  • Modo de despliegue: $LINK_MODE" \
    "  • Respaldos guardados en: $BACKUP_DIR" \
    "  • Registro de instalación: $LOG" \
    "" \
    "Instrucciones de inicio:" \
    "  1. Cierra sesión en tu entorno actual." \
    "  2. En la pantalla de SDDM, selecciona la sesión 'Hyprland'." \
    "  3. Inicia sesión: Quickshell y los plugins se cargarán automáticamente." \
    "" \
    "Atajos clave:" \
    "  • SUPER + Return   : Terminal kitty" \
    "  • SUPER + Space    : Lanzador de aplicaciones" \
    "  • SUPER + D        : Dashboard (Dynamic Island expandida)" \
    "  • SUPER + L        : Bloquear pantalla (hyprlock)" \
    "  • SUPER + Q        : Cerrar ventana" \
    "" \
    "Para desinstalar en cualquier momento:" \
    "  $REPO_DIR/install.sh --uninstall"
