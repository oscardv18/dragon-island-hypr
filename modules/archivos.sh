#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module archivos — paquetes de Archivos (volúmenes, miniaturas, compartir en red). Solo paquetes: la
# configuración vive en el módulo core. Los instala la fase «Paquetes».
# =============================================================================
archivos_desc() { echo "Archivos: volúmenes, miniaturas, archivos comprimidos y red local (udisks2, gvfs, 7zip…)"; }
archivos_sudo() { echo "pacman -S (paquetes); sin servicios del sistema"; }
archivos_packages() { pkg_list "$REPO_DIR/packages/pacman-archivos.txt"; }
archivos_check() { pkg_installed udisks2 && pkg_installed gvfs; }
archivos_plan() { echo "  · paquetes: $(archivos_packages | tr '\n' ' ')"; }
archivos_apply() { ensure_via pacman archivos_packages || log_warn "Paquetes de Archivos pendientes."; return 0; }
archivos_revert() { log_info "archivos: los paquetes quedan instalados (otros programas pueden usarlos)."; }
