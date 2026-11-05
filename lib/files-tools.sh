#!/usr/bin/env bash
# Shared deployment for fresh installs and migration 070.
files_tools_setup() {
    local file data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines"
    for file in secret_filter.py engine_common.py taller_common.py dragon_git.py dragon_files.py files_archives.py files_network.py files_share.py files_desktop.py files_filemanager1.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-files" "$HOME/.local/bin/dragon-files"
    deploy_item "$REPO_DIR/config/applications/dragon-files.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/dragon-files.desktop"
    files_filemanager1_setup || true   # 10: no PyGObject yet; migration 195 retries
}

# files_filemanager1_setup: Archivos Dragon answers org.freedesktop.FileManager1 («Mostrar en carpeta» / «Abrir
# carpeta» of Brave, Chromium, Firefox, Telegram…) through D-Bus activation: a user service file, which wins over the
# system ones (Dolphin's, Nautilus's), runs `dragon-files --filemanager1` on demand (it quits after 30 s idle).
# Session-wide, so it also applies in Plasma. A service file that is not Dragon's is left alone; a file manager that
# already holds the name keeps it until it exits (nothing is killed). Needs PyGObject (python-gobject, core package).
# Returns 10 without PyGObject, so migration 195 retries on the next update. Undo: delete the .service file.
files_filemanager1_setup() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services" dest wanted
    dest="$dir/org.freedesktop.FileManager1.service"
    if ! python3 -c 'from gi.repository import Gio' >/dev/null 2>&1; then
        log_warn "FileManager1 de Archivos Dragon pendiente: falta python-gobject (paquete del núcleo)."
        return 10
    fi
    wanted="$(printf '[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=%s --filemanager1\n' "$HOME/.local/bin/dragon-files")"
    if [[ -f "$dest" ]]; then
        if [[ "$(cat -- "$dest")" == "$wanted" ]]; then
            log_info "FileManager1: ya lo atiende Archivos Dragon ($dest)"
            return 0
        fi
        if ! grep -q 'dragon-files' "$dest"; then
            log_info "FileManager1: $dest no es de Dragon; se respeta"
            return 0
        fi
        backup_copy "$dest"
    fi
    run mkdir -p "$dir"
    $DRY_RUN || printf '%s\n' "$wanted" > "$dest"
    log_info "FileManager1: «Mostrar en carpeta» abre Archivos Dragon ($dest)"
    pgrep -x dolphin >/dev/null 2>&1 && log_info "Dolphin sigue abierto: atiende «Mostrar en carpeta» hasta que se cierre."
    return 0
}
