#!/usr/bin/env bash
# =============================================================================
# dragon-island — doctor (read-only). Prints ✔/✘ with the fix for every failure.
#   ./doctor.sh          health of the installed desktop
#   ./doctor.sh --pre    ONLY the prerequisites of pre-instalation.md; every ✘ names the step to repeat
# Exit code: number of failures (0 = all good).
# =============================================================================
set -Euo pipefail
shopt -s nullglob

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=true          # nothing here writes; the flag keeps shared helpers from doing so
ASSUME_YES=true
PRE=false
for a in "$@"; do
    case "$a" in
        --pre) PRE=true ;;
        -h|--help) echo "Uso: $0 [--pre]   (solo lectura; --pre = requisitos previos de pre-instalation.md)"; exit 0 ;;
        *) echo "Opción desconocida: $a" >&2; exit 2 ;;
    esac
done

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
# shellcheck source=lib/checks.sh
. "$REPO_DIR/lib/checks.sh"

FAILS=0
good() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      ↳ %s\n' "$2"; FAILS=$((FAILS + 1)); }

# ck <label> <hint> <command...>: ✔ when the command succeeds, ✘ (with the hint) otherwise
ck() { local label="$1" hint="$2"; shift 2; if "$@" >/dev/null 2>&1; then good "$label"; else bad "$label" "$hint"; fi; }
pre() {   # pre <check-id> <label>
    local id="$1" label="$2" out
    if out="$("check_$id" 2>&1)"; then good "$label"; [[ -n "$out" ]] && printf '      %s\n' "${out//$'\n'/$'\n      '}"; return 0; fi
    bad "$label"; printf '%s\n' "$out" | sed 's/^/      /'
}

if $PRE; then
    echo "Requisitos previos (pre-instalation.md)"
    detect_distro; detect_gpu
    pre root    "No eres root"
    pre distro  "Distro soportada ($DISTRO_NAME)"
    pre sudo    "sudo disponible y usuario en wheel"
    pre base    "Herramientas base: git, curl, unzip, gum, base-devel"
    pre aur     "Ayudante de AUR (yay/paru)"
    pre network "Red: archlinux.org alcanzable"
    pre time    "Hora sincronizada (NTP)"
    pre gpu     "Driver de video cargado (${GPU_VENDOR:-?}: ${GPU_NAME:-?})"
    pre dm      "Display manager activo ($(display_manager))"
    pre keymap  "Teclado del login empieza por us"
    pre versions "Hyprland ≥ 0.55 y Quickshell ≥ 0.3 (instalados o disponibles en el repo)"
    pre disk    "Espacio libre ≥ 5 GB en \$HOME"
    echo
    if (( FAILS == 0 )); then echo "Todo listo: ./install.sh --dry-run"; else echo "$FAILS requisito(s) sin cumplir: repite el paso indicado de pre-instalation.md."; fi
    exit "$FAILS"
fi

echo "dragon-island — doctor"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
has() { grep -qiE "$1" <<<"$2"; }

echo "Sesión y configuración"
if in_hyprland && command -v hyprctl >/dev/null 2>&1; then
    errs="$(hyprctl configerrors 2>&1 | sed '/^[[:space:]]*$/d' || true)"
    ck "hyprctl configerrors vacío" "revisa: hyprctl configerrors (docs/TROUBLESHOOTING.md)" test -z "${errs//ok/}"
    layout="$(hyprctl getoption input:kb_layout 2>/dev/null | awk -F': ' '/str/ {print $2}')"
    ck "Teclado de Hyprland: ${layout:-?} (us primero)" "debe empezar por us: ./install.sh --modules keyboard" test "${layout#us}" != "${layout}"
    pl="$(hyprctl plugin list 2>/dev/null || true)"
    for p in hyprbars hyprfocus hyprglass; do
        ck "Plugin $p cargado" "ejecuta scripts/plugins-foreground.sh en una terminal dentro de Hyprland (docs/TROUBLESHOOTING.md)" has "$p" "$pl"
    done
else
    printf '  - fuera de Hyprland: se omiten configerrors, teclado y plugins\n'
fi

if command -v qs >/dev/null 2>&1; then
    if [[ -n "$(qs list 2>/dev/null)" ]]; then
        good "Quickshell en marcha"
        ipc="$(qs ipc show 2>&1 || true)"
        for t in shell lock; do ck "IPC «$t» disponible" "reinicia la shell: qs kill; qs -d" has "target $t" "$ipc"; done
        log="$(qs log 2>/dev/null | tail -n 400 || true)"
        if has "Failed to load configuration|is not a type" "$log"; then bad "Quickshell registró errores de carga" "qs log | less ; docs/TROUBLESHOOTING.md"
        else good "Quickshell sin errores de carga en el registro"; fi
    else
        bad "Quickshell no está en marcha" "qs -d (o cierra sesión y vuelve a entrar)"
    fi
else bad "No existe qs (quickshell)" "sudo pacman -S quickshell"; fi

echo "Tema y fuentes"
fonts="$(fc-list 2>/dev/null || true)"
ck "Fuente Outfit" "yay -S ttf-outfit (módulo theme)" has "outfit" "$fonts"
ck "JetBrains Mono Nerd" "sudo pacman -S ttf-jetbrains-mono-nerd" has "JetBrainsMono Nerd|JetBrains Mono Nerd" "$fonts"
ck "Tema de iconos Sweet-Purple" "yay -S candy-icons-git sweet-folders-icons-git" test -d /usr/share/icons/Sweet-Purple

echo "Login"
dm="$(display_manager)"
if [[ "$dm" == sddm ]]; then
    ck "Tema SDDM dragon-core activo (opcional)" "./install.sh --modules login" grep -qs "dragon-core" /etc/sddm.conf.d/10-dragon-core.conf
else printf '  - display manager «%s»: el tema de login es solo para SDDM\n' "$dm"; fi

echo "Llavero y servicios"
if command -v busctl >/dev/null 2>&1 && busctl --user list 2>/dev/null | grep -q org.freedesktop.secrets; then
    locked="$(busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked 2>/dev/null || true)"
    ck "Llavero «login» desbloqueado" "su contraseña debe ser la de tu usuario (Seahorse); módulo keyring" test "$locked" = "b false"
else bad "Nadie ofrece org.freedesktop.secrets" "./install.sh --modules keyring (gnome-keyring)"; fi
for s in NetworkManager bluetooth power-profiles-daemon; do
    ck "Servicio $s activo" "sudo systemctl enable --now $s" systemctl is-active --quiet "$s"
done
for s in pipewire wireplumber; do
    ck "Servicio de usuario $s activo" "systemctl --user enable --now $s" systemctl --user is-active --quiet "$s"
done

echo "Repositorio"
ck "NeuralCore/CoreIcon sincronizados (scripts/sync-shared.sh --check)" "ejecuta scripts/sync-shared.sh" "$REPO_DIR/scripts/sync-shared.sh" --check
ck "$CFG/hypr desplegado" "./install.sh --modules core" test -e "$CFG/hypr/hyprland.lua"

echo
if (( FAILS == 0 )); then echo "Todo en orden ✔"; else echo "$FAILS comprobación(es) fallan: sigue las indicaciones ↳"; fi
exit "$FAILS"
