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
ASK=auto           # «¿Instalar ahora?» at the end of a standalone run (install.sh calls doctor.sh with --no-ask)
for a in "$@"; do
    case "$a" in
        --pre) PRE=true ;;
        --no-ask) ASK=no ;;
        -h|--help) echo "Uso: $0 [--pre] [--no-ask]   (solo lectura; --pre = requisitos previos; al final pregunta «¿Instalar ahora?» si Dragon no está instalado)"; exit 0 ;;
        *) echo "Opción desconocida: $a" >&2; exit 2 ;;
    esac
done

# shellcheck source=lib/common.sh
. "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/detect.sh
. "$REPO_DIR/lib/detect.sh"
# shellcheck source=lib/checks.sh
. "$REPO_DIR/lib/checks.sh"

# Dragon not installed yet (no state written by install.sh): the full health check would only list what is missing by design,
# so a bare ./doctor.sh checks the prerequisites and offers to install.
if ! $PRE && [[ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/modules" ]] && ! command -v Hyprland >/dev/null 2>&1; then
    PRE=true
fi

FAILS=0
good() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✘\033[0m %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      ↳ %s\n' "$2"; FAILS=$((FAILS + 1)); }

# ck <label> <hint> <command...>: ✔ when the command succeeds, ✘ (with the hint) otherwise
ck() { local label="$1" hint="$2"; shift 2; if "$@" >/dev/null 2>&1; then good "$label"; else bad "$label" "$hint"; fi; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$1"; }
pre() {   # pre <check-id> <label>: ✔ ok · ⚠ warning (the check returned 2: not counted) · ✘ failure
    local id="$1" label="$2" out rc=0
    out="$("check_$id" 2>&1)" || rc=$?
    case "$rc" in
        0) good "$label"; [[ -n "$out" ]] && printf '      %s\n' "${out//$'\n'/$'\n      '}"; return 0 ;;
        2) warn "$label"; printf '%s\n' "$out" | sed 's/^/      /'; return 0 ;;
        *) bad "$label"; printf '%s\n' "$out" | sed 's/^/      /' ;;
    esac
}

# ask_install: a standalone ./doctor.sh ends by offering the one command. Only on a terminal, only when Dragon is not installed yet
# (or with --pre), never when install.sh itself runs the doctor (--no-ask).
ask_install() {
    [[ "$ASK" == no ]] && return 0
    [[ -t 0 && -t 1 ]] || return 0
    if ! $PRE && [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/modules" ]]; then return 0; fi
    local ans
    read -r -p "¿Instalar ahora? [S/n] " ans || return 0
    [[ "$ans" =~ ^[nN] ]] && return 0
    exec "$REPO_DIR/install.sh"
}

if $PRE; then
    PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_prereq.py" || FAILS=$((FAILS + 1))
    echo "Requisitos previos (pre-instalation.md)"
    detect_distro; detect_gpu
    pre root    "No eres root"
    pre distro  "Distro soportada ($DISTRO_NAME)"
    pre sudo    "sudo disponible y usuario en wheel"
    pre base    "Herramientas base: git, curl, unzip, gum, base-devel"
    pre aur     "Ayudante de AUR (yay/paru)"
    pre network "Red: archlinux.org alcanzable"
    pre time    "Hora sincronizada (NTP)"
    pre gpu     "GPU y driver de video (${GPU_VENDOR:-?}: ${GPU_NAME:-?})"
    pre dm      "Gestor de acceso (display manager): $(display_manager)"
    pre keymap  "Teclado del login empieza por us"
    pre versions "Hyprland ≥ 0.55 y Quickshell ≥ 0.3 (instalados o disponibles en el repo)"
    pre disk    "Espacio libre ≥ 5 GB en \$HOME"
    echo
    if (( FAILS == 0 )); then echo "Todo listo."; else echo "$FAILS requisito(s) sin cumplir: ./install.sh instala los que puede; para el resto, el paso de pre-instalation.md."; fi
    ask_install
    exit "$FAILS"
fi

echo "dragon-island — doctor"
ck "Python + Pillow para dragon-palette" "sudo pacman -S --needed python python-pillow" python3 -c 'from PIL import Image'
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
# the hints name the AUR helper that is really installed (paru on CachyOS), not always yay
AURH="$(aur_helper)"; AURH="${AURH:-paru}"
has() { grep -qiE "$1" <<<"$2"; }

# a graphic session: Hyprland (or any Wayland/X11 session) — the keyring and the desktop services only exist there
graphic_session() { in_hyprland || [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; }
SYSFS="${DRAGON_SYSFS:-/sys}"     # tests point it at a fake tree

# shellcheck source=lib/pins.sh
. "$REPO_DIR/lib/pins.sh"
echo "Compilación de plugins (hyprpm)"
pin_msg="$(hyprland_pin_check)"; pin_rc=$?
case "$pin_rc" in
    0) good "Versión de Hyprland = fijada ($pin_msg)" ;;
    1) bad "Versión de Hyprland distinta de la fijada: $pin_msg" "git pull && ./update.sh (el repo puede traer ya la serie nueva); si ya estás al día, los plugins pueden no cargar: alinea Hyprland (sudo pacman -Syu) o revisa packages/pins.json y docs/TESTED-VERSIONS.md" ;;
    *) warn "Versión de Hyprland: $pin_msg" ;;
esac
for p in hyprpm cmake meson ninja cpio pkgconf git gcc; do
    ck "Paquete $p (prerrequisito de hyprpm)" "sudo pacman -S --needed $p" pacman -T "$p"
done

echo "Sesión y configuración"
if in_hyprland && command -v hyprctl >/dev/null 2>&1; then
    errs="$(hyprctl configerrors 2>&1 | sed '/^[[:space:]]*$/d' || true)"
    ck "hyprctl configerrors vacío" "revisa: hyprctl configerrors (docs/TROUBLESHOOTING.md)" test -z "${errs//ok/}"
    layout="$(hyprctl getoption input:kb_layout 2>/dev/null | awk -F': ' '/str/ {print $2}')"
    ck "Teclado de Hyprland: ${layout:-?} (us primero)" "debe empezar por us: ./install.sh --modules keyboard" test "${layout#us}" != "${layout}"
    pl="$(hyprctl plugin list 2>/dev/null || true)"
    for p in hyprfocus hyprglass; do
        ck "Plugin $p cargado" "ejecuta scripts/plugins-foreground.sh en una terminal dentro de Hyprland (docs/TROUBLESHOOTING.md)" has "$p" "$pl"
    done
    ck "Sin barras de título (hyprbars no cargado)" "hyprpm disable hyprbars && hyprpm reload -n (o ./update.sh: migración 037)" test -z "$(grep -i 'hyprbars' <<<"$pl" || true)"
else
    printf '  - fuera de Hyprland: se omiten configerrors, teclado y plugins\n'
fi

if ! command -v qs >/dev/null 2>&1; then bad "No existe qs (quickshell)" "sudo pacman -S quickshell"
elif ! in_hyprland; then
    # Quickshell is started by Hyprland's autostart: outside a Hyprland session it is not expected to run (and the installer never starts it)
    printf '  - fuera de Hyprland: Quickshell y sus IPC (shell, lock) se comprueban dentro de la sesión; cierra sesión y entra en Hyprland\n'
elif [[ -n "$(qs list 2>/dev/null)" ]]; then
    good "Quickshell en marcha"
    ipc="$(qs ipc show 2>&1 || true)"
    for t in shell lock; do ck "IPC «$t» disponible" "reinicia la shell: qs kill; qs -d" has "target $t" "$ipc"; done
    log="$(qs log 2>/dev/null | tail -n 400 || true)"
    if has "Failed to load configuration|is not a type" "$log"; then bad "Quickshell registró errores de carga" "qs log | less ; docs/TROUBLESHOOTING.md"
    else good "Quickshell sin errores de carga en el registro"; fi
else
    bad "Quickshell no está en marcha" "qs -d (o cierra sesión y vuelve a entrar)"
fi

echo "Dashboard del notch: apps en segundo plano · IA (herdr)"
bi="$CFG/dragon-island/background-apps.json"
if [[ -f "$bi" ]]; then
    ck "JSON válido: $bi" "corrige la sintaxis (la shell conserva los valores anteriores); defaults en config/dragon-island/background-apps.json" python3 -m json.tool "$bi"
else bad "Falta $bi" "./update.sh (migración 014) o cp config/dragon-island/background-apps.json $bi"; fi
if [[ -f "$CFG/dragon-island/background-apps.local.json" ]]; then
    ck "JSON válido: background-apps.local.json" "corrige la sintaxis del archivo local" python3 -m json.tool "$CFG/dragon-island/background-apps.local.json"
fi
if command -v herdr >/dev/null 2>&1; then
    if herdr status server 2>/dev/null | grep -q 'status: running'; then
        ck "herdr: servidor alcanzable (la pestaña IA muestra datos)" "herdr status server" herdr agent list
    else printf '  - herdr no está en marcha: la pestaña IA muestra «herdr sin conexión» (correcto, sin errores)\n'; fi
else printf '  - herdr no instalado: la pestaña IA muestra «herdr sin conexión»\n'; fi

echo "Modos de tiling (dwindle ↔ scrolling)"
if in_hyprland && command -v hyprctl >/dev/null 2>&1; then
    hv="$(hyprctl version -j 2>/dev/null | jq -r '.tag // empty' 2>/dev/null || true)"
    # shellcheck disable=SC2016
    ck "Hyprland ≥ 0.56 (${hv:-?})" "actualiza Hyprland: el layout scrolling nativo llegó en 0.56" bash -c '[[ "$(printf "%s\nv0.56.0\n" "$1" | sort -V | head -n1)" == v0.56.0 ]]' _ "${hv:-v0}"
    ck "El layout «scrolling» existe en esta versión" "hyprctl getoption scrolling:column_width debería responder" has "float" "$(hyprctl getoption scrolling:column_width 2>&1)"
fi
ck "dragon-tiling instalado en \$HOME/.local/bin" "./install.sh --modules core" test -x "$HOME/.local/bin/dragon-tiling"
ts="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/tiling.json"
if [[ -f "$ts" ]]; then ck "Estado del tiling: JSON válido ($ts)" "bórralo: se vuelve a dwindle sin errores" jq -e '.workspaces | type == "object"' "$ts"
else printf '  - sin estado guardado: todos los escritorios en dwindle (correcto)\n'; fi

echo "Tema y fuentes"
fonts="$(fc-list 2>/dev/null || true)"
ck "Fuente Outfit" "$AURH -S ttf-outfit (módulo theme)" has "outfit" "$fonts"
ck "JetBrains Mono Nerd" "sudo pacman -S ttf-jetbrains-mono-nerd" has "JetBrainsMono Nerd|JetBrains Mono Nerd" "$fonts"
ck "Tema de iconos Sweet-Purple" "$AURH -S candy-icons-git sweet-folders-icons-git" test -d /usr/share/icons/Sweet-Purple
ck "Iconos MacTahoe-purple-dark (base de Dragon-Core)" "$AURH -S mactahoe-icon-theme-git" test -d /usr/share/icons/MacTahoe-purple-dark
ck "Iconos WhiteSur-dark (respaldo de Dragon-Core)" "$AURH -S whitesur-icon-theme" test -d /usr/share/icons/WhiteSur-dark
ck "Tema de iconos del shell Dragon-Core" "./update.sh (migración 021)" test -f "$HOME/.local/share/icons/Dragon-Core/index.theme"

if grep -qsx shell "${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/modules" || grep -qs ">>> dragon-island:zsh" "$HOME/.zshrc"; then
    echo "Terminal (zsh)"
    # shellcheck source=lib/zsh-setup.sh
    . "$REPO_DIR/lib/zsh-setup.sh"
    login_shell="$(getent passwd "$USER" | cut -d: -f7)"
    ck "Shell por defecto: zsh (${login_shell:-?})" "chsh -s /usr/bin/zsh   (y abre una terminal nueva)" test "$(basename "${login_shell:-none}")" = zsh
    # shellcheck disable=SC2329  # called through ck
    zshrc_loads_dragon() { zsh_block_ok || [[ "$(readlink -f "$HOME/.zshrc")" == "$(readlink -f "$REPO_DIR/config/zsh/.zshrc")" ]]; }
    ck "~/.zshrc carga Dragon (bloque dragon-island:zsh)" "$REPO_DIR/install.sh --modules shell   (añade UNA línea a ~/.zshrc, con copia)" zshrc_loads_dragon
    st="$(starship_config_path)"
    ck "starship.toml de Dragon ($st)" "$REPO_DIR/install.sh --modules shell   (guarda el tuyo en las copias y pone el de Dragon)" starship_is_dragon "$st"
    probe="$(zsh_probe)"
    pv() { sed -n "s/^$1=//p" <<< "$probe"; }
    case "$(pv prompt)" in
        starship) good "Prompt activo: Starship de Dragon" ;;
        p10k) bad "Prompt activo: Powerlevel10k (gana a Starship)" "$REPO_DIR/update.sh   (dragon.zsh desactiva p10k); si sigue: $REPO_DIR/install.sh --modules shell" ;;
        *) bad "Prompt activo: ni Starship ni p10k ($(pv prompt))" "$REPO_DIR/install.sh --modules shell   y abre una terminal nueva" ;;
    esac
    pdir="$(zsh_plugin_dir)"
    for pl in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
        case "$pl" in
            zsh-autosuggestions) key=autosuggestions; fix="sudo pacman -S --needed zsh-autosuggestions" ;;
            zsh-syntax-highlighting) key=syntax; fix="sudo pacman -S --needed zsh-syntax-highlighting" ;;
            fzf-tab) key=fzftab; fix="git clone --depth 1 https://github.com/Aloxaf/fzf-tab.git '$pdir/fzf-tab'" ;;
        esac
        if ! file="$(zsh_plugin_file "$pl")"; then bad "Plugin $pl: no está instalado" "$fix"
        elif [[ "$(pv "$key")" == 1 ]]; then good "Plugin $pl cargado ($file)"
        else bad "Plugin $pl instalado pero no se carga ($file)" "comprueba que ~/.zshrc carga Dragon y abre una terminal nueva: zsh -i"; fi
    done
    if [[ "$(pv stderr)" == 0 ]]; then good "zsh -i arranca sin errores"
    else bad "zsh -i escribe $(pv stderr) línea(s) de error: $(pv error)" "zsh -i   (y revisa ~/.zshrc / ~/.zshrc.local)"; fi
fi

echo "Login"
dm="$(display_manager)"
if [[ "$dm" == sddm ]]; then
    ck "Tema SDDM dragon-core activo (opcional)" "./install.sh --modules login" grep -qs "dragon-core" /etc/sddm.conf.d/10-dragon-core.conf
else printf '  - display manager «%s»: el tema de login es solo para SDDM\n' "$dm"; fi

echo "Llavero y servicios"
if ! graphic_session; then
    printf '  - sin sesión gráfica: el llavero se crea y desbloquea al iniciar sesión en Hyprland (no se exige aquí)\n'
elif command -v busctl >/dev/null 2>&1 && busctl --user list 2>/dev/null | grep -q org.freedesktop.secrets; then
    locked="$(busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked 2>/dev/null || true)"
    ck "Llavero «login» desbloqueado" "su contraseña debe ser la de tu usuario (Seahorse); módulo keyring" test "$locked" = "b false"
else bad "Nadie ofrece org.freedesktop.secrets" "./install.sh --modules keyring (gnome-keyring)"; fi
for s in NetworkManager bluetooth power-profiles-daemon; do
    if [[ "$s" == bluetooth && -z "$(ls -A "$SYSFS/class/bluetooth" 2>/dev/null)" ]]; then
        printf '  - bluetooth activo: no aplica (sin adaptador bluetooth en %s/class/bluetooth)\n' "$SYSFS"; continue
    fi
    ck "Servicio $s activo" "sudo systemctl enable --now $s" systemctl is-active --quiet "$s"
done
# user services start with the user session: outside it «habilitado» is what can be asked
# shellcheck disable=SC2329  # called through ck
user_unit_ok() { systemctl --user is-active --quiet "$1" || systemctl --user is-enabled --quiet "$1" || systemctl --user is-enabled --quiet "$1.socket"; }
for s in pipewire wireplumber; do
    ck "Servicio de usuario $s activo o habilitado" "systemctl --user enable --now $s" user_unit_ok "$s"
done

echo "Repositorio"
ck "NeuralCore/CoreIcon sincronizados (scripts/sync-shared.sh --check)" "ejecuta scripts/sync-shared.sh" "$REPO_DIR/scripts/sync-shared.sh" --check
ck "$CFG/hypr desplegado" "./install.sh --modules core" test -e "$CFG/hypr/hyprland.lua"

echo
if (( FAILS == 0 )); then echo "Todo en orden ✔"; else echo "$FAILS comprobación(es) fallan: sigue las indicaciones ↳"; fi
exit "$FAILS"
