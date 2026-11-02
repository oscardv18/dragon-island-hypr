#!/usr/bin/env bash
# Dragon Portal (fase 6): the Dragon explorer as the file dialog of other apps (docs/PORTAL-API.md, docs/handoff-fase-6-portal.md).
# Shared by modules/core.sh and migrations 100 / 102. Nothing here needs sudo.
#   portal_tools_setup   deploy the engine files and the CLI (does NOT register the backend)
#   portal_selftest      `dragon-portal serve` really owns its bus name in a private session bus
#   portal_enable        register the backend for this user — only when it demonstrably starts (see the warning below)
#   portal_disable       remove the registration (scripts/portal-rollback.sh)
#
# WARNING (probed, PORTAL-API.md §2): if xdg-desktop-portal starts a registered backend and it fails, the whole FileChooser portal
# disappears — there is no fall back to GTK in that case. That is why portal_enable checks every precondition and runs the
# self-test first, and writes nothing when one fails.
portal_paths() {
    PORTAL_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
    PORTAL_FILE="$PORTAL_DATA/xdg-desktop-portal/portals/dragon.portal"
    PORTAL_SERVICE="$PORTAL_DATA/dbus-1/services/org.freedesktop.impl.portal.desktop.dragon.service"
    PORTAL_BIN="$HOME/.local/bin/dragon-portal"
}

portal_tools_setup() {
    local file data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines"
    for file in portal_core.py dragon_portal.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-portal" "$HOME/.local/bin/dragon-portal"
}

portal_selftest() {
    local bin="$1"
    command -v dbus-run-session >/dev/null 2>&1 || return 2
    command -v busctl >/dev/null 2>&1 || return 2
    # shellcheck disable=SC2016  # the script is for the inner bash: $0 / $pid expand there
    DRAGON_PORTAL_IDLE=20 timeout 20 dbus-run-session -- bash -c '
        "$0" serve >/dev/null 2>&1 & pid=$!
        for _ in $(seq 1 40); do
            if busctl --user list --no-legend 2>/dev/null | grep -q "^org.freedesktop.impl.portal.desktop.dragon "; then
                kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; exit 0
            fi
            kill -0 "$pid" 2>/dev/null || exit 1
            sleep 0.25
        done
        kill "$pid" 2>/dev/null; exit 1' "$bin"
}

# the content of the D-Bus activation file: an absolute path (the bus does not expand ~ or $HOME)
portal_service_text() { printf '[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.dragon\nExec=%s serve\n' "$1"; }

# writes `content` to `dest` unless it is already identical; backs up what it replaces. Returns 0 changed, 1 unchanged.
portal_write() {
    local dest="$1" content="$2"
    if [[ -f "$dest" && ! -L "$dest" && "$(cat -- "$dest")" == "$content" ]]; then return 1; fi
    backup_copy "$dest"
    run mkdir -p "$(dirname "$dest")"
    if $DRY_RUN; then echo "[dry-run] escribir $dest"; else printf '%s\n' "$content" > "$dest"; fi
    return 0
}

# → 0 registered (or already was), 10 a precondition fails (nothing written; the explorer is not used as file dialog)
portal_enable() {
    portal_paths
    local py="${PORTAL_PYTHON:-python3}" changed=1
    if ! "$py" -c 'import gi; from gi.repository import Gio' 2>/dev/null; then
        log_warn "Dragon Portal: falta python-gobject (sudo pacman -S python-gobject). Los diálogos de archivos siguen siendo los de GTK."
        return 10
    fi
    if [[ ! -f /usr/share/xdg-desktop-portal/portals/gtk.portal ]]; then
        log_warn "Dragon Portal: falta xdg-desktop-portal-gtk, el respaldo del selector (sudo pacman -S xdg-desktop-portal-gtk). No se registra."
        return 10
    fi
    if ! $DRY_RUN; then
        if [[ ! -x "$PORTAL_BIN" ]]; then log_warn "Dragon Portal: falta $PORTAL_BIN (migración 100)."; return 10; fi
        if ! portal_selftest "$PORTAL_BIN"; then
            log_warn "Dragon Portal: el servicio no arrancó en la prueba con un bus privado; no se registra para no dejar la sesión sin selector de archivos."
            return 10
        fi
    fi
    portal_write "$PORTAL_FILE" "$(cat -- "$REPO_DIR/config/portal/dragon.portal")" && changed=0
    portal_write "$PORTAL_SERVICE" "$(portal_service_text "$PORTAL_BIN")" && changed=0
    # copied installs of hyprland-portals.conf (a repo link already has the line)
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal/hyprland-portals.conf"
    if [[ -f "$conf" && ! -L "$conf" ]] && ! grep -q '^org.freedesktop.impl.portal.FileChooser=' "$conf"; then
        backup_copy "$conf"
        if $DRY_RUN; then echo "[dry-run] añadir FileChooser=dragon;gtk a $conf"
        else
            if grep -q '^\[preferred\]' "$conf"; then sed -i '/^\[preferred\]/a org.freedesktop.impl.portal.FileChooser=dragon;gtk' "$conf"
            else printf '\n[preferred]\norg.freedesktop.impl.portal.FileChooser=dragon;gtk\n' >> "$conf"; fi
        fi
        changed=0
    fi
    if ((changed == 0)); then
        log_info "Dragon Portal registrado. Para estrenarlo sin cerrar sesión: systemctl --user restart xdg-desktop-portal (corta una captura de pantalla en curso)."
        need_relogin "Dragon Portal: reinicia xdg-desktop-portal o cierra sesión para usar el explorador como selector de archivos."
    fi
    return 0
}

portal_disable() {
    portal_paths
    local f
    for f in "$PORTAL_FILE" "$PORTAL_SERVICE"; do
        [[ -e "$f" || -L "$f" ]] || continue
        backup_copy "$f"
        run rm -f -- "$f"
    done
}
