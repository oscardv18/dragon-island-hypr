#!/usr/bin/env bash
# 161 — si el módulo `boot` ya está instalado y el motor del repo cambió, ofrece actualizar la copia de root y reaplicar el tema.
# Toca /boot con sudo, así que NUNCA se hace sin una terminal y una confirmación (ni con ASSUME_YES): sin eso sale con 10 y se
# reintenta en la próxima actualización. DRY_RUN solo muestra lo que haría.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR
# shellcheck source=lib/boot-tools.sh
. "$REPO_DIR/lib/boot-tools.sh"
boot_vars
[[ -f "$BOOT_SYSTEM_DIR/settings.json" ]] || exit 10                 # the module was never applied here
if cmp -s -- "$REPO_DIR/dragon-core/dragon_boot.py" "$BOOT_SYSTEM_DIR/dragon_boot.py"; then exit 10; fi
if $DRY_RUN; then log_info "[dry-run] se actualizaría $BOOT_SYSTEM_DIR/dragon_boot.py y se reaplicaría el tema de arranque."; exit 0; fi
boot_confirm "[sudo] Actualizar el tema de arranque de Dragon OS (motor nuevo en $BOOT_SYSTEM_DIR y reaplicar)" || exit 10
boot_apply_limine_or_grub() { if [[ "$(boot_detect)" == grub ]]; then boot_apply_grub; else boot_apply_limine; fi; }
boot_apply_limine_or_grub
