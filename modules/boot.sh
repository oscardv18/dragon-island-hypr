#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module boot — Dragon OS theme for the boot manager (opt-in; docs/BOOT.md). Limine first, GRUB as the alternative
# (--bootloader grub|limine|auto). It touches /boot with sudo steps you see and confirm one by one (even with --yes),
# never EFI entries nor boot entries (Windows included), and backs up every file it replaces.
# =============================================================================
# shellcheck source=lib/boot-tools.sh
. "$REPO_DIR/lib/boot-tools.sh"

boot_desc() { echo "Tema de Dragon OS para el gestor de arranque: Limine (o GRUB con --bootloader grub). Toca /boot"; }
boot_sudo() { echo "instala el motor en /usr/local/lib/dragon-os-boot, el gancho de limine-entry-tool y reescribe solo el bloque global de limine.conf (o el tema de GRUB); pregunta antes de cada paso"; }
boot_packages() { :; }

boot_check() { [[ -f "${BOOT_SYSTEM_DIR:-/usr/local/lib/dragon-os-boot}/settings.json" ]]; }

boot_plan() {
    boot_vars
    local bl
    bl="$(boot_detect 2>/dev/null || true)"
    echo "  · gestor detectado: ${bl:-ninguno legible sin sudo (se vuelve a buscar con sudo)} (elige con --bootloader grub|limine)"
    echo "  · papel tapiz de assets/wallpapers a la resolución de la pantalla (sin deformar), paleta de Theme.qml, marca «Dragon OS», cuenta atrás de 3 s"
    echo "  · respaldo con fecha de limine.conf / /etc/default/grub; las entradas (Windows incluido) y las variables EFI no se tocan"
    echo "  · vista previa sin tocar nada: bin/dragon-boot preview --out /tmp/arranque.png"
}

boot_apply() {
    boot_vars
    local bl
    bl="$(boot_detect 2>/dev/null || true)"
    [[ -z "$bl" ]] && bl="$BOOTLOADER"
    case "$bl" in
        limine) boot_apply_limine ;;
        grub) boot_apply_grub ;;
        *) log_warn "No detecto Limine ni GRUB (pueden estar en una partición que solo lee root). Indica uno: ./install.sh --modules boot --bootloader limine|grub" ;;
    esac
    return 0
}

boot_revert() { boot_revert_all; }
