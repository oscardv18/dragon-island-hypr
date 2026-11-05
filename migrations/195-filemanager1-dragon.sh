#!/usr/bin/env bash
# 195 — «Mostrar en carpeta» / «Abrir carpeta» (org.freedesktop.FileManager1) abre Archivos Dragon y no Dolphin: Brave
# y otras apps no usan el portal ni la asociación inode/directory para eso, sino ese servicio de D-Bus, que atendía el
# gestor del sistema. Se registra la activación D-Bus de `dragon-files --filemanager1` en ~/.local/share/dbus-1/services
# (un archivo de servicio ajeno se respeta). Sin python-gobject sale con 10 y se reintenta. Idempotente; respeta DRY_RUN.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/files-tools.sh
. "$REPO_DIR/lib/files-tools.sh"
files_filemanager1_setup
