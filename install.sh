#!/usr/bin/env bash
# =============================================================================
# dragon-island — Interactive TUI Installer & Dotfiles Manager
# Target: Arch Linux / EndeavourOS (next to KDE Plasma) with a gum TUI
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/install.log"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_DIR/backups/$TS"
MANIFEST="$STATE_DIR/manifest"   # lines: <action>\t<target>\t<backup-or-source>

ALL_COMPONENTS=(core shell plugins tools fonts services)
# Optional components: unchecked by default (--glass checks them), shown with a friendly label
OPTIONAL_COMPONENTS=(glass)
declare -A COMPONENT_LABEL=([glass]="Efecto cristal (hyprglass)")
WANT_GLASS=false

DRY_RUN=false
ASSUME_YES=false
MODE="install"
LINK_MODE="symlink"

# Gum styling (Sweet / Garuda Dragonized palette)
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
  --dry-run       Muestra las acciones sin ejecutarlas (no pide sudo ni instala nada)
  --yes, -y       Modo desatendido: usa valores por defecto sin preguntas
  --glass         Incluye el componente opcional «Efecto cristal (hyprglass)»
  --uninstall     Desinstala dragon-island y restaura copias de seguridad
  -h, --help      Muestra esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --yes|-y)    ASSUME_YES=true ;;
        --glass)     WANT_GLASS=true ;;
        --uninstall) MODE="uninstall" ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $arg" >&2; exit 2 ;;
    esac
done

[[ -t 0 && -t 1 ]] || ASSUME_YES=true

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&2' ERR

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
run() {
    if $DRY_RUN; then
        printf '[dry-run] %q ' "$@"
        echo
    else
        "$@"
    fi
}

has_gum() { command -v gum >/dev/null 2>&1; }

log_info() { if has_gum; then gum log --level info "$1"; else echo ":: $1"; fi; }
log_warn() { if has_gum; then gum log --level warn "$1"; else echo ":: AVISO: $1"; fi; }

# box <border-color> <line>...   (plain text fallback when gum is missing, e.g. in --dry-run)
box() {
    local color="$1"; shift
    if has_gum; then
        gum style --border rounded --border-foreground "$color" --padding "1 2" --foreground "#e6e8ef" "$@"
    else
        printf '%s\n' "------------------------------------------------------------" "$@" \
            "------------------------------------------------------------"
    fi
}

# confirm <question>  → 0 = yes. In --yes mode (or without gum) always yes.
confirm() {
    if $ASSUME_YES || ! has_gum; then return 0; fi
    gum confirm --affirmative "Sí" --negative "No" "$1"
}

# read_packages <file> <component>...  → prints the packages of the selected sections
read_packages() {
    local file="$1"; shift
    [[ -f "$file" ]] || return 0
    awk -v sel=" $* " '
        /^[[:space:]]*(#|$)/ { next }
        /^@/ { section = substr($1, 2); next }
        index(sel, " " section " ") { print $1 }
    ' "$file"
}

# =============================================================================
# Uninstall (--uninstall): process the manifest in reverse
# =============================================================================
do_uninstall() {
    box "#ed254e" "Desinstalador de dragon-island" \
        "Se eliminarán los archivos desplegados y se restaurarán los respaldos." \
        "Los paquetes instalados NO se desinstalan."
    confirm "¿Deseas proceder con la desinstalación?" || exit 0

    if [[ ! -f "$MANIFEST" ]]; then
        echo "No se encontró el manifiesto en $MANIFEST. Nada que desinstalar."
        exit 0
    fi

    log_info "Procesando manifiesto en orden inverso..."
    local lines=() line action target extra idx
    mapfile -t lines < "$MANIFEST"

    for (( idx=${#lines[@]}-1; idx>=0; idx-- )); do
        line="${lines[idx]}"
        [[ -z "$line" ]] && continue
        IFS=$'\t' read -r action target extra <<< "$line"
        case "$action" in
            deploy)
                if [[ -L "$target" || -e "$target" ]]; then
                    log_info "Eliminando: $target"
                    run rm -rf -- "$target"
                fi
                ;;
            backup)
                if [[ -e "$extra" || -L "$extra" ]]; then
                    log_info "Restaurando respaldo: $extra -> $target"
                    run mkdir -p "$(dirname "$target")"
                    run mv -- "$extra" "$target"
                fi
                ;;
        esac
    done

    run rm -f "$STATE_DIR/firstrun.done" "$MANIFEST"
    box "#06c993" "Desinstalación finalizada" "Los dotfiles fueron retirados y los respaldos restaurados."
    exit 0
}

[[ "$MODE" == "uninstall" ]] && do_uninstall

# =============================================================================
# Preflight
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

if ! $DRY_RUN && ! curl -fsS --max-time 5 -o /dev/null https://archlinux.org; then
    echo "ERROR: No hay conexión a internet disponible." >&2
    exit 1
fi

if ! $DRY_RUN; then
    sudo -v
    # keep sudo alive while the installer runs
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
fi

# --dry-run without gum: nothing can be prompted, use defaults
if $DRY_RUN && ! has_gum; then ASSUME_YES=true; fi

if ! has_gum; then
    log_info "Instalando gum para la interfaz de terminal..."
    run sudo pacman -S --needed --noconfirm gum
fi

if pacman -Qq plasma-desktop >/dev/null 2>&1 || pacman -Qq plasma-workspace >/dev/null 2>&1; then
    log_info "KDE Plasma detectado: se instalará Hyprland como sesión adicional en SDDM (Plasma no se toca)."
fi

# =============================================================================
# Welcome and choices
# =============================================================================
box "#c50ed2" "dragon-island — Instalador" \
    "Hyprland 0.56 (Lua) + Quickshell 0.3.1 (barra + notch)" \
    "EndeavourOS / Arch Linux, junto a KDE Plasma"

# One full upgrade first (never partial upgrades); default yes in --yes mode
if confirm "¿Actualizar el sistema ahora (pacman -Syu)? Recomendado antes de instalar."; then
    log_info "Actualizando el sistema..."
    run sudo pacman -Syu --noconfirm
fi

if ! $ASSUME_YES; then
    CHOICE="$(gum choose --header "¿Cómo desplegar los archivos de configuración?" \
        "Symlink (recomendado: se actualiza con git pull)" \
        "Copia (archivos independientes en ~/.config)")"
    [[ "$CHOICE" == Copia* ]] && LINK_MODE="copy"
fi

SELECTED_COMPONENTS=("${ALL_COMPONENTS[@]}")
$WANT_GLASS && SELECTED_COMPONENTS+=("${OPTIONAL_COMPONENTS[@]}")
if ! $ASSUME_YES; then
    # gum shows labels; map them back to component keys afterwards
    labels=() preselected=() picked=()
    for c in "${ALL_COMPONENTS[@]}" "${OPTIONAL_COMPONENTS[@]}"; do
        labels+=("${COMPONENT_LABEL[$c]:-$c}")
    done
    for c in "${SELECTED_COMPONENTS[@]}"; do preselected+=("${COMPONENT_LABEL[$c]:-$c}"); done
    mapfile -t picked < <(gum choose --no-limit \
        --header "Componentes (Espacio marca/desmarca, Enter confirma):" \
        --selected "$(IFS=,; echo "${preselected[*]}")" \
        "${labels[@]}")
    SELECTED_COMPONENTS=()
    for p in "${picked[@]}"; do
        key="$p"
        for c in "${OPTIONAL_COMPONENTS[@]}"; do [[ "${COMPONENT_LABEL[$c]}" == "$p" ]] && key="$c"; done
        SELECTED_COMPONENTS+=("$key")
    done
fi
if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
    log_warn "No se seleccionó ningún componente. Saliendo."
    exit 0
fi
log_info "Componentes: ${SELECTED_COMPONENTS[*]}"

has_component() {
    local c
    for c in "${SELECTED_COMPONENTS[@]}"; do [[ "$c" == "$1" ]] && return 0; done
    return 1
}

# =============================================================================
# AUR helper (only if some selected component needs AUR packages)
# =============================================================================
mapfile -t AUR_PKGS < <(read_packages "$REPO_DIR/packages/aur.txt" "${SELECTED_COMPONENTS[@]}")

AUR_HELPER=""
for h in paru yay; do
    if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; break; fi
done

if [[ -z "$AUR_HELPER" && ${#AUR_PKGS[@]} -gt 0 ]]; then
    if confirm "No hay ayudante de AUR (yay/paru). ¿Compilar e instalar yay-bin?"; then
        log_info "Instalando yay-bin desde AUR..."
        run sudo pacman -S --needed --noconfirm base-devel git
        if $DRY_RUN; then
            run git clone https://aur.archlinux.org/yay-bin.git "<tmp>/yay-bin"
            run makepkg -si --noconfirm
        else
            BUILD_DIR="$(mktemp -d)"
            git clone https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay-bin"
            ( cd "$BUILD_DIR/yay-bin" && makepkg -si --noconfirm )
            rm -rf "$BUILD_DIR"
        fi
        AUR_HELPER="yay"
    else
        log_warn "Sin ayudante de AUR: instala a mano: ${AUR_PKGS[*]}"
    fi
fi

# =============================================================================
# Packages
# =============================================================================
mapfile -t PACMAN_PKGS < <(read_packages "$REPO_DIR/packages/pacman.txt" "${SELECTED_COMPONENTS[@]}")

if [[ ${#PACMAN_PKGS[@]} -gt 0 ]]; then
    log_info "Instalando ${#PACMAN_PKGS[@]} paquetes de los repositorios oficiales..."
    run sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
fi

if [[ -n "$AUR_HELPER" && ${#AUR_PKGS[@]} -gt 0 ]]; then
    log_info "Instalando paquetes de AUR con $AUR_HELPER: ${AUR_PKGS[*]}"
    run "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

# =============================================================================
# Configs: backup + link/copy (idempotent)
# =============================================================================
deploy_item() {
    local src="$1" dest="$2" rel_path

    # Already a symlink to our repo → nothing to do
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Ya enlazado: $dest"
        return 0
    fi
    # Copy mode and identical content → nothing to do
    if [[ "$LINK_MODE" == "copy" && -e "$dest" && ! -L "$dest" ]] && diff -rq -- "$src" "$dest" >/dev/null 2>&1; then
        log_info "Ya copiado y sin cambios: $dest"
        return 0
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        rel_path="${dest#"$HOME"/}"
        run mkdir -p "$BACKUP_DIR/$(dirname "$rel_path")"
        run mv -- "$dest" "$BACKUP_DIR/$rel_path"
        $DRY_RUN || printf 'backup\t%s\t%s\n' "$dest" "$BACKUP_DIR/$rel_path" >> "$MANIFEST"
        log_info "Respaldo: $dest -> $BACKUP_DIR/$rel_path"
    fi

    run mkdir -p "$(dirname "$dest")"
    if [[ "$LINK_MODE" == "symlink" ]]; then
        run ln -sfn -- "$src" "$dest"
    else
        run cp -a -- "$src" "$dest"
    fi
    $DRY_RUN || printf 'deploy\t%s\t%s\n' "$dest" "$src" >> "$MANIFEST"
    log_info "Desplegado ($LINK_MODE): $dest"
}

log_info "Desplegando configuración..."

if has_component core; then
    deploy_item "$REPO_DIR/config/hypr"  "$HOME/.config/hypr"
    deploy_item "$REPO_DIR/config/kitty" "$HOME/.config/kitty"
    # Keyring: the Secret portal → gnome-keyring in Hyprland (Plasma keeps kde-portals.conf),
    # and Brave forced to libsecret so both sessions share its passwords and cookies
    deploy_item "$REPO_DIR/config/xdg-desktop-portal/hyprland-portals.conf" \
        "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
    deploy_item "$REPO_DIR/config/brave/brave-flags.conf" "$HOME/.config/brave-flags.conf"
fi

if has_component shell; then
    deploy_item "$REPO_DIR/config/quickshell" "$HOME/.config/quickshell"
fi

if has_component core; then
    # Default wallpaper, only when the user has none (never replaces a custom one)
    WALLPAPER="${XDG_DATA_HOME:-$HOME/.local/share}/$PROJECT/wallpaper.jpg"
    if [[ -e "$WALLPAPER" || -L "$WALLPAPER" ]]; then
        log_info "Fondo de pantalla existente conservado: $WALLPAPER"
    else
        deploy_item "$REPO_DIR/assets/wallpapers/dragon-island.jpg" "$WALLPAPER"
    fi
fi

if has_component plugins; then
    # Run once, from autostart.lua, inside the first Hyprland session (hyprpm needs a running Hyprland)
    run chmod +x "$REPO_DIR/installer/firstrun.sh"
    deploy_item "$REPO_DIR/installer/firstrun.sh" "$STATE_DIR/firstrun.sh"
fi

# Optional: hyprglass (acrylic / liquid glass). hyprpm needs a running Hyprland, so inside Hyprland it
# runs now in the foreground; otherwise autostart.lua runs it at the next login (glass.pending).
if has_component glass; then
    run chmod +x "$REPO_DIR/installer/glass.sh"
    deploy_item "$REPO_DIR/installer/glass.sh" "$STATE_DIR/glass.sh"
    if ! $DRY_RUN; then touch "$STATE_DIR/glass.pending"; fi
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && ! $DRY_RUN && confirm "Estás dentro de Hyprland: ¿instalar hyprglass ahora (en primer plano)?"; then
        "$STATE_DIR/glass.sh" || log_warn "hyprglass no se instaló: se reintentará en el próximo inicio de sesión en Hyprland."
    else
        log_info "hyprglass se instalará en tu próximo inicio de sesión en Hyprland (terminal visible)."
    fi
fi

# =============================================================================
# Services (system units; skipped when already enabled)
# =============================================================================
if has_component services; then
    log_info "Configurando servicios del sistema..."
    for s in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl is-enabled --quiet "$s" 2>/dev/null; then
            log_info "Servicio $s ya habilitado."
        else
            run sudo systemctl enable --now "$s" || log_warn "No se pudo habilitar $s"
        fi
    done
fi

# =============================================================================
# Post-install checks for the shell (warnings only, nothing is changed)
# =============================================================================
if has_component shell && ! $DRY_RUN; then
    if command -v qs >/dev/null 2>&1; then
        log_info "Quickshell: $(qs --version 2>/dev/null | head -n1)"
    else
        log_warn "No se encontró 'qs' (quickshell). La barra y el notch no se mostrarán."
    fi

    # Only one notification daemon per session: ours (Quickshell). Others may be D-Bus activated.
    for d in mako dunst swaync; do
        if pacman -Qq "$d" >/dev/null 2>&1; then
            log_warn "$d está instalado: si arranca en Hyprland competirá con las notificaciones de Quickshell."
        fi
    done
fi

# Only one Secret Service: gnome-keyring. KWallet (Plasma) must not offer it too, or the two
# daemons race for org.freedesktop.secrets. Warn only: it is Plasma's setting, the user decides.
if has_component core && ! $DRY_RUN && pacman -Qq kwallet >/dev/null 2>&1; then
    kw_api="$(kreadconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled 2>/dev/null || true)"
    if [[ "$kw_api" != "false" ]]; then
        log_warn "KWallet también ofrece el servicio de secretos y compite con gnome-keyring."
        log_warn "Desactívalo (lee README → Llavero / contraseñas):"
        log_warn "  kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false"
    fi
fi

if has_component fonts && ! $DRY_RUN && command -v fc-list >/dev/null 2>&1; then
    fc-list | grep -qi "Outfit" || log_warn "Fuente Outfit no encontrada (paquete AUR ttf-outfit)."
    fc-list | grep -qi "JetBrainsMono Nerd\|JetBrains Mono Nerd" || log_warn "JetBrains Mono Nerd Font no encontrada (ttf-jetbrains-mono-nerd)."
fi

# =============================================================================
# Final screen
# =============================================================================
box "#06c993" "dragon-island instalado" \
    "" \
    "  • Despliegue: $LINK_MODE · componentes: ${SELECTED_COMPONENTS[*]}" \
    "  • Respaldos: $BACKUP_DIR (solo si había algo que reemplazar)" \
    "  • Registro: $LOG" \
    "" \
    "Para empezar: cierra sesión → en la pantalla de inicio (SDDM o Plasma Login) elige «Hyprland»." \
    "En el primer arranque se abre una terminal que compila hyprbars/hyprfocus" \
    "(y hyprglass, si marcaste «Efecto cristal»)." \
    "" \
    "  SUPER + Return  terminal      SUPER + Space   lanzador" \
    "  SUPER + D       notch         SUPER + N       notificaciones" \
    "  SUPER + Escape  energía       SUPER + L       bloquear" \
    "" \
    "Llavero: gnome-keyring, el mismo en Plasma y Hyprland; PAM lo abre al entrar." \
    "  El llavero «login» debe tener la MISMA contraseña que tu usuario (compruébalo" \
    "  con Seahorse) y no debe usarse el inicio de sesión automático." \
    "  Antes del primer arranque con la nueva opción de Brave, exporta sus contraseñas." \
    "  Detalles: README → Llavero / contraseñas" \
    "" \
    "Pruebas: docs/TESTING.md · Atajos: docs/KEYBINDS.md" \
    "" \
    "Desinstalar: $REPO_DIR/install.sh --uninstall"
