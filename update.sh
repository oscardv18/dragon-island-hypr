#!/usr/bin/env bash
# =============================================================================
# dragon-island — Update script (no full reinstall)
# git pull → migrations (once each) → missing packages → configs → optional plugins → live reload.
# `git pull` alone is not enough: changes that touch an installed system ship as migrations/NNN-*.sh.
# =============================================================================
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/update.log"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_DIR/backups/$TS"
MANIFEST="$STATE_DIR/manifest"          # lines: <action>\t<target>\t<backup-or-source>
MIGRATIONS_DONE="$STATE_DIR/migrations.done"
COMPONENTS_FILE="$STATE_DIR/components"
RELOGIN_FILE="$STATE_DIR/needs-relogin"

DRY_RUN=false
ASSUME_YES=false
LINK_MODE="symlink"
SELECTED_COMPONENTS=()

# Gum styling (Sweet / Garuda Dragonized palette)
export GUM_CHOOSE_CURSOR_FOREGROUND="#00c1e4"
export GUM_CHOOSE_SELECTED_FOREGROUND="#c50ed2"
export GUM_CONFIRM_SELECTED_BACKGROUND="#7c3aed"
export GUM_CONFIRM_SELECTED_FOREGROUND="#ffffff"
export GUM_SPIN_SPINNER_FOREGROUND="#c50ed2"

usage() {
    cat <<EOF
Uso: $0 [OPCIONES]

Actualiza dragon-island sin reinstalar: git pull, migraciones, paquetes que falten,
configuraciones, plugins opcionales y recarga en vivo (también: ./install.sh --update).

OPCIONES:
  --dry-run       Muestra lo que haría sin ejecutarlo (no pide sudo ni cambia nada)
  --yes, -y       Modo desatendido: respuestas por defecto (no instala plugins nuevos)
  -h, --help      Muestra esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --yes|-y)  ASSUME_YES=true ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Opción desconocida: $arg" >&2; exit 2 ;;
    esac
done

[[ -t 0 && -t 1 ]] || ASSUME_YES=true

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&2' ERR

# shellcheck source=installer/lib.sh
. "$REPO_DIR/installer/lib.sh"

# Summary counters
APPLIED_MIGRATIONS=()
SKIPPED_MIGRATIONS=()
INSTALLED_PKGS=()
CHANGED_FILES=()
BACKUPS=()

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Por seguridad, no ejecutes este script como root." >&2
    exit 1
fi
box "#c50ed2" "dragon-island — Actualización" \
    "git pull · migraciones · paquetes · configuración · plugins · recarga en vivo"
$DRY_RUN && log_info "Modo --dry-run: no se cambiará nada."

# =============================================================================
# State inference (installs made before update.sh existed have no components / link-mode files)
# =============================================================================
infer_state() {
    if [[ -f "$COMPONENTS_FILE" ]]; then
        mapfile -t SELECTED_COMPONENTS < "$COMPONENTS_FILE"
    else
        SELECTED_COMPONENTS=()
        local action target
        if [[ -f "$MANIFEST" ]]; then
            while IFS=$'\t' read -r action target _; do
                [[ "$action" == "deploy" ]] || continue
                case "$target" in
                    */.config/hypr|*/.config/kitty) SELECTED_COMPONENTS+=(core) ;;
                    */.config/quickshell)           SELECTED_COMPONENTS+=(shell) ;;
                    */firstrun.sh)                  SELECTED_COMPONENTS+=(plugins) ;;
                    */glass.sh)                     SELECTED_COMPONENTS+=(glass) ;;
                    */.zshrc)                       SELECTED_COMPONENTS+=(zsh) ;;
                esac
            done < "$MANIFEST"
        fi
        # tools / fonts / services leave no file: assume the defaults of install.sh
        SELECTED_COMPONENTS+=(tools fonts services)
        [[ -L "$HOME/.config/hypr" || -d "$HOME/.config/hypr" ]] && SELECTED_COMPONENTS+=(core)
        [[ -L "$HOME/.config/quickshell" || -d "$HOME/.config/quickshell" ]] && SELECTED_COMPONENTS+=(shell)
        mapfile -t SELECTED_COMPONENTS < <(printf '%s\n' "${SELECTED_COMPONENTS[@]}" | sort -u)
    fi

    if [[ -f "$STATE_DIR/link-mode" ]]; then
        LINK_MODE="$(< "$STATE_DIR/link-mode")"
    elif [[ -f "$MANIFEST" ]]; then
        local first
        first="$(awk -F'\t' '$1 == "deploy" { print $2; exit }' "$MANIFEST")"
        if [[ -n "$first" && -e "$first" && ! -L "$first" ]]; then LINK_MODE="copy"; fi
    fi
}

has_component() {
    local c
    for c in "${SELECTED_COMPONENTS[@]}"; do [[ "$c" == "$1" ]] && return 0; done
    return 1
}

save_state() {
    $DRY_RUN && return 0
    printf '%s\n' "${SELECTED_COMPONENTS[@]}" > "$COMPONENTS_FILE"
    printf '%s\n' "$LINK_MODE" > "$STATE_DIR/link-mode"
}

infer_state
log_info "Componentes: ${SELECTED_COMPONENTS[*]} · despliegue: $LINK_MODE"

# =============================================================================
# 1. git pull --ff-only
# =============================================================================
step_pull() {
    log_info "1/6 · Repositorio"
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        log_warn "No es un clon de git: se omite el pull."
        return 0
    fi
    if [[ -n "$(git -C "$REPO_DIR" status --porcelain --untracked-files=no)" ]]; then
        log_warn "Hay cambios locales sin commit en $REPO_DIR. Haz commit o stash y vuelve a ejecutar."
        git -C "$REPO_DIR" status --short --untracked-files=no
        exit 1
    fi
    if ! git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        log_warn "La rama actual no sigue ninguna rama remota: se omite el pull."
        return 0
    fi
    local before after
    before="$(git -C "$REPO_DIR" rev-parse HEAD)"
    if $DRY_RUN; then
        run git -C "$REPO_DIR" pull --ff-only
        return 0
    fi
    git -C "$REPO_DIR" pull --ff-only
    after="$(git -C "$REPO_DIR" rev-parse HEAD)"
    if [[ "$before" == "$after" ]]; then
        log_info "Ya estás al día."
    else
        log_info "Actualizado: $(git -C "$REPO_DIR" log --oneline "$before..$after" | wc -l) commits nuevos."
    fi
}

# =============================================================================
# 2. Migrations (each runs once; exit 10 = skipped, retried next time)
# =============================================================================
step_migrations() {
    log_info "2/6 · Migraciones"
    touch "$MIGRATIONS_DONE"
    local f id rc pending=0
    export REPO_DIR STATE_DIR BACKUP_DIR MANIFEST DRY_RUN ASSUME_YES LINK_MODE LOG COMPONENTS_FILE RELOGIN_FILE
    for f in "$REPO_DIR"/migrations/[0-9]*.sh; do
        id="$(basename "$f")"
        if grep -qxF "$id" "$MIGRATIONS_DONE"; then continue; fi
        pending=$((pending + 1))
        log_info "Migración $id"
        rc=0
        bash "$f" || rc=$?
        case "$rc" in
            0)  APPLIED_MIGRATIONS+=("$id")
                $DRY_RUN || echo "$id" >> "$MIGRATIONS_DONE" ;;
            10) SKIPPED_MIGRATIONS+=("$id") ;;
            *)  log_warn "La migración $id falló (código $rc); se reintentará la próxima vez."
                SKIPPED_MIGRATIONS+=("$id (falló)") ;;
        esac
    done
    [[ $pending -gt 0 ]] || log_info "No hay migraciones pendientes."
    # migrations may have added components (e.g. 002 → zsh) or changed the manifest
    infer_state
}

# =============================================================================
# 3. Packages: only what is missing, never -Syu
# =============================================================================
pkg_present() {
    # installed, or the command already exists (e.g. starship installed by hand in /usr/local/bin)
    pacman -Qq "$1" >/dev/null 2>&1 || command -v "$1" >/dev/null 2>&1
}

step_packages() {
    log_info "3/6 · Paquetes"
    local all missing=() p
    mapfile -t all < <(read_packages "$REPO_DIR/packages/pacman.txt" "${SELECTED_COMPONENTS[@]}")
    for p in "${all[@]}"; do pkg_present "$p" || missing+=("$p"); done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Faltan ${#missing[@]} paquetes de los repositorios: ${missing[*]}"
        if confirm "¿Instalarlos con pacman -S --needed? (no se hace -Syu)"; then
            run sudo pacman -S --needed --noconfirm "${missing[@]}"
            INSTALLED_PKGS+=("${missing[@]}")
        fi
    else
        log_info "Paquetes de los repositorios: todo instalado."
    fi

    local aur_all aur_missing=() helper="" h
    mapfile -t aur_all < <(read_packages "$REPO_DIR/packages/aur.txt" "${SELECTED_COMPONENTS[@]}")
    for p in "${aur_all[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || aur_missing+=("$p"); done
    if [[ ${#aur_missing[@]} -gt 0 ]]; then
        for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }; done
        if [[ -z "$helper" ]]; then
            log_warn "Faltan paquetes de AUR (${aur_missing[*]}) y no hay yay/paru: instálalos a mano."
        elif confirm "Faltan paquetes de AUR: ${aur_missing[*]}. ¿Instalarlos con $helper?"; then
            run "$helper" -S --needed --noconfirm "${aur_missing[@]}"
            INSTALLED_PKGS+=("${aur_missing[@]}")
        fi
    fi
}

# =============================================================================
# 4. Configs
# =============================================================================
# deployed items from the manifest: "<target>\t<source>" (the last record of each target wins)
deployed_items() {
    [[ -f "$MANIFEST" ]] || return 0
    awk -F'\t' '$1 == "deploy" { src[$2] = $3 } END { for (t in src) print t "\t" src[t] }' "$MANIFEST" | sort
}

# sync_copy <source> <target>: copy only the files that changed (backup first). Stale files stay.
sync_copy() {
    local src="$1" dest="$2" rel file changed=0
    if [[ -f "$src" ]]; then
        cmp -s "$src" "$dest" 2>/dev/null && return 0
        backup_copy "$dest"
        run cp -a -- "$src" "$dest"
        CHANGED_FILES+=("$dest")
        return 0
    fi
    while IFS= read -r -d '' file; do
        rel="${file#"$src"/}"
        if ! cmp -s "$file" "$dest/$rel" 2>/dev/null; then
            backup_copy "$dest/$rel"
            run mkdir -p "$(dirname "$dest/$rel")"
            run cp -a -- "$file" "$dest/$rel"
            CHANGED_FILES+=("$dest/$rel")
            changed=1
        fi
    done < <(find "$src" -type f -print0)
    [[ $changed -eq 1 ]] || return 0
}

step_configs() {
    log_info "4/6 · Configuración"
    local target src copies=() links=0
    while IFS=$'\t' read -r target src; do
        [[ -n "$target" && -e "$src" ]] || continue
        if [[ -L "$target" ]]; then
            links=$((links + 1))
            [[ "$(readlink -f "$target")" == "$(readlink -f "$src")" ]] || log_warn "$target apunta a otro sitio (no es el repo)."
        elif [[ -e "$target" ]]; then
            copies+=("$target"$'\t'"$src")
        fi
    done < <(deployed_items)

    log_info "Enlaces simbólicos al repo: $links · copias: ${#copies[@]}"
    if [[ ${#copies[@]} -eq 0 ]]; then
        log_info "Nada que copiar: con symlinks los cambios del repo ya están aplicados."
        return 0
    fi

    if confirm "Hay ${#copies[@]} elementos en modo copia. ¿Pasarlos a symlink (se actualizan solos con git pull)?"; then
        local item
        for item in "${copies[@]}"; do
            IFS=$'\t' read -r target src <<< "$item"
            LINK_MODE="symlink" deploy_item "$src" "$target"
            CHANGED_FILES+=("$target (ahora symlink)")
        done
        LINK_MODE="symlink"
        save_state
        return 0
    fi

    local item
    for item in "${copies[@]}"; do
        IFS=$'\t' read -r target src <<< "$item"
        sync_copy "$src" "$target"
    done
    [[ ${#CHANGED_FILES[@]} -gt 0 ]] && log_info "Redesplegados solo los archivos que cambiaron."
    return 0
}

# =============================================================================
# 5. Optional plugins (hyprglass): hyprpm in the foreground
# =============================================================================
step_plugins() {
    log_info "5/6 · Plugins"
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprpm >/dev/null 2>&1; then
        log_info "Fuera de Hyprland o sin hyprpm: se omiten los plugins."
        return 0
    fi
    if hyprctl plugin list 2>/dev/null | grep -qi "hyprglass"; then
        log_info "hyprglass ya está cargado."
        return 0
    fi
    # --yes never installs new plugins on its own; with the component already chosen it retries
    local want=false
    if has_component glass; then want=true
    elif ! $ASSUME_YES && confirm "Hay un plugin opcional nuevo: hyprglass (efecto cristal). ¿Instalarlo ahora, en primer plano?"; then want=true
    fi
    $want || return 0
    run chmod +x "$REPO_DIR/installer/glass.sh"
    if $DRY_RUN; then
        run "$REPO_DIR/installer/glass.sh"
        return 0
    fi
    "$REPO_DIR/installer/glass.sh" || log_warn "hyprglass no se instaló (¿terminal sin sudo?). Ejecuta installer/glass.sh en kitty."
    if hyprctl plugin list 2>/dev/null | grep -qi "hyprglass" && ! has_component glass; then
        SELECTED_COMPONENTS+=(glass)
        save_state
    fi
}

# =============================================================================
# 6. Live reload (no logout)
# =============================================================================
step_reload() {
    log_info "6/6 · Recarga en vivo"
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log_warn "No hay una sesión de Hyprland: la configuración se aplicará al iniciar sesión."
        return 0
    fi
    if command -v hyprpm >/dev/null 2>&1; then run hyprpm reload -n || log_warn "hyprpm reload -n falló."; fi
    run hyprctl reload
    if command -v qs >/dev/null 2>&1; then
        if $DRY_RUN; then
            echo "[dry-run] qs kill; qs -d"
        else
            qs kill || true
            sleep 1
            qs -d >/dev/null 2>&1 </dev/null
        fi
    fi
    $DRY_RUN || sleep 2
}

step_pull
step_migrations
step_packages
step_configs
step_plugins
step_reload
save_state

# =============================================================================
# Summary
# =============================================================================
ERRORS="(no se pudo comprobar)"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && ! $DRY_RUN; then
    ERRORS="$(hyprctl configerrors 2>&1 | sed '/^[[:space:]]*$/d')"
    [[ -n "$ERRORS" ]] || ERRORS="vacío ✔"
elif $DRY_RUN; then
    ERRORS="(dry-run: no se comprobó)"
fi

join() { local out="" a; for a in "$@"; do out+="${out:+, }$a"; done; echo "$out"; }
[[ -d "$BACKUP_DIR" ]] && BACKUPS+=("$BACKUP_DIR")

lines=(
    ""
    "  • Migraciones aplicadas:  $( ((${#APPLIED_MIGRATIONS[@]})) && join "${APPLIED_MIGRATIONS[@]}" || echo ninguna)"
)
((${#SKIPPED_MIGRATIONS[@]})) && lines+=("  • Migraciones omitidas:   $(join "${SKIPPED_MIGRATIONS[@]}")")
lines+=(
    "  • Paquetes instalados:    $( ((${#INSTALLED_PKGS[@]})) && join "${INSTALLED_PKGS[@]}" || echo ninguno)"
    "  • Archivos cambiados:     $( ((${#CHANGED_FILES[@]})) && join "${CHANGED_FILES[@]}" || echo ninguno)"
    "  • Backups:                $( ((${#BACKUPS[@]})) && join "${BACKUPS[@]}" || echo ninguno)"
    "  • hyprctl configerrors:   $ERRORS"
    "  • Registro:               $LOG"
)
if [[ -s "$RELOGIN_FILE" ]]; then
    lines+=("" "  ⚠ Requiere cerrar sesión y volver a entrar:")
    while IFS= read -r l; do lines+=("      - $l"); done < "$RELOGIN_FILE"
    $DRY_RUN || rm -f "$RELOGIN_FILE"
fi
box "#06c993" "Actualización terminada" "${lines[@]}"
