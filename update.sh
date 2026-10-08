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
COMPONENTS_FILE="$STATE_DIR/components"   # legacy (pre-modules); migration 013 translates it
MODULES_FILE="$STATE_DIR/modules"
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
  --yes, -y       Modo desatendido: respuestas por defecto (los pasos con sudo se confirman igual)
  --no-sudo       Omite los pasos que necesiten sudo
  -h, --help      Muestra esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --yes|-y)  ASSUME_YES=true ;;
        --no-sudo) NO_SUDO=true ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Opción desconocida: $arg" >&2; exit 2 ;;
    esac
done

[[ -t 0 && -t 1 ]] || ASSUME_YES=true

# dry-run must not write anywhere
if ! $DRY_RUN; then
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$LOG") 2>&1
fi
trap 'echo "✗ Error en la línea $LINENO. Revisa el registro en: $LOG" >&2' ERR

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
for m in "$REPO_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    . "$m"
done

# Summary counters
APPLIED_MIGRATIONS=()
SKIPPED_MIGRATIONS=()
INSTALLED_PKGS=()
CHANGED_FILES=()
BACKUPS=()
NOTES=()

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
    if [[ -f "$MODULES_FILE" ]]; then
        mapfile -t SELECTED_COMPONENTS < "$MODULES_FILE"
    else
        # installs made before the modular installer: translate the old component names
        SELECTED_COMPONENTS=(core)
        local c
        if [[ -f "$COMPONENTS_FILE" ]]; then
            while read -r c; do
                case "$c" in
                    zsh) SELECTED_COMPONENTS+=(shell) ;;
                    fonts) SELECTED_COMPONENTS+=(theme) ;;
                    plugins|glass) SELECTED_COMPONENTS+=(plugins) ;;
                    tools|myapps) SELECTED_COMPONENTS+=(extras) ;;
                esac
            done < "$COMPONENTS_FILE"
        fi
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
    printf '%s\n' "${SELECTED_COMPONENTS[@]}" > "$MODULES_FILE"
    printf '%s\n' "$LINK_MODE" > "$STATE_DIR/link-mode"
}

infer_state
log_info "Módulos: ${SELECTED_COMPONENTS[*]} · despliegue: $LINK_MODE"

# =============================================================================
# 1. git pull --ff-only
# =============================================================================
step_pull() {
    log_info "1/6 · Repositorio"
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        log_warn "No es un clon de git: se omite el pull."
        return 0
    fi
    # packages/user-*.txt ("Mis apps") change on their own whenever the Tienda installs something: not a local edit
    if [[ -n "$(git -C "$REPO_DIR" status --porcelain --untracked-files=no -- . ':!packages/user-pacman.txt' ':!packages/user-aur.txt')" ]]; then
        log_warn "Hay cambios locales sin commit en $REPO_DIR. Haz commit o stash y vuelve a ejecutar."
        git -C "$REPO_DIR" status --short --untracked-files=no -- . ':!packages/user-pacman.txt' ':!packages/user-aur.txt'
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
    # offline or no SSH key available (no passphrase prompt in a script): keep going with the local copy
    if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git -C "$REPO_DIR" pull --ff-only; then
        log_warn "No se pudo hacer git pull (¿sin red o sin clave SSH?): se continúa con la copia local."
        return 0
    fi
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
    local m p missing=() aur_missing=() helper
    helper="$(aur_helper)"
    for m in "${SELECTED_COMPONENTS[@]}"; do
        declare -F "${m}_packages" >/dev/null || continue
        while read -r p; do
            if [[ -z "$p" ]] || pkg_installed "$p"; then continue; fi
            if pacman -Si "$p" >/dev/null 2>&1; then missing+=("$p"); else aur_missing+=("$p"); fi
        done < <("${m}_packages")
    done
    # "Mis apps" (the Tienda's lists) belong to the extras module
    if has_component extras; then
        while read -r p; do pkg_installed "$p" || missing+=("$p"); done < <(read_plain_list "$REPO_DIR/packages/user-pacman.txt")
        while read -r p; do pkg_installed "$p" || aur_missing+=("$p"); done < <(read_plain_list "$REPO_DIR/packages/user-aur.txt")
    fi
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u | sed '/^$/d')
    mapfile -t aur_missing < <(printf '%s\n' "${aur_missing[@]}" | sort -u | sed '/^$/d')

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Faltan ${#missing[@]} paquetes de los repositorios: ${missing[*]}"
        if ensure_pacman "${missing[@]}"; then INSTALLED_PKGS+=("${missing[@]}")
        else NOTES+=("Paquetes pendientes: ${missing[*]}"); fi
    else
        log_info "Paquetes de los repositorios: todo instalado."
    fi
    if [[ ${#aur_missing[@]} -gt 0 ]]; then
        AUR_HELPER="$helper"
        if ensure_aur "${aur_missing[@]}"; then INSTALLED_PKGS+=("${aur_missing[@]}"); else NOTES+=("AUR pendientes: ${aur_missing[*]}"); fi
    fi
}

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
    has_component plugins || { log_info "Módulo plugins no instalado: se omite."; return 0; }
    if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprpm >/dev/null 2>&1; then
        log_info "Fuera de Hyprland o sin hyprpm: se omiten los plugins."
        return 0
    fi
    # hyprpm update again only when Hyprland itself changed (plugins are built per Hyprland version), or if some are pending
    local now before=""
    now="$(installed_version hyprland)"
    [[ -f "$STATE_DIR/hyprland-version" ]] && before="$(< "$STATE_DIR/hyprland-version")"
    if [[ "$now" == "$before" && ! -f "$STATE_DIR/plugins.pending" ]] && hyprctl plugin list 2>/dev/null | grep -qi hyprbars; then
        log_info "Hyprland $now sin cambios y plugins cargados: nada que reconstruir."
        return 0
    fi
    log_info "Hyprland ${before:-?} → $now (o plugins pendientes): hay que repetir hyprpm update."
    if $DRY_RUN; then run "$REPO_DIR/scripts/plugins-foreground.sh"; return 0; fi
    if confirm "[sudo] hyprpm va a reinstalar las cabeceras (pide tu contraseña). ¿Reconstruir los plugins ahora, en primer plano?"; then
        run chmod +x "$REPO_DIR/scripts/plugins-foreground.sh"
        if "$REPO_DIR/scripts/plugins-foreground.sh"; then printf '%s\n' "$now" > "$STATE_DIR/hyprland-version"
        else log_warn "Los plugins no se reconstruyeron (¿terminal sin sudo?). Ejecuta scripts/plugins-foreground.sh en una terminal."; fi
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
# the neural core has one source (shared/neural-core); dry-run only checks it
if $DRY_RUN; then "$REPO_DIR/scripts/sync-shared.sh" --check || log_warn "NeuralCore/CoreIcon: copias desincronizadas."
else "$REPO_DIR/scripts/sync-shared.sh"; fi
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
((${#NOTES[@]})) && lines+=("  • Pendiente:              $(join "${NOTES[@]}")")
if [[ -s "$RELOGIN_FILE" ]]; then
    lines+=("" "  ⚠ Requiere cerrar sesión y volver a entrar:")
    while IFS= read -r l; do lines+=("      - $l"); done < "$RELOGIN_FILE"
    $DRY_RUN || rm -f "$RELOGIN_FILE"
fi
box "#06c993" "Actualización terminada" "${lines[@]}"
