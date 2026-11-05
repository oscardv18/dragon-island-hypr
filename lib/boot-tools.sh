#!/usr/bin/env bash
# Dragon OS boot theme (module `boot`, docs/BOOT.md). Touches /boot, so every write goes through a visible sudo step, asks even
# with --yes, and never touches EFI variables or boot entries. Test hooks (never set by the installer): BOOT_SUDO="" runs the
# "root" steps as the current user on a fake tree; BOOT_SYSTEM_DIR, BOOT_HOOK_DIR, BOOT_ESP, BOOT_ROOT point at that tree;
# DRAGON_BOOT_ASSUME_YES=1 answers the questions.
boot_vars() {
    BOOT_SUDO_CMD=("${BOOT_SUDO-sudo}")
    [[ -z "${BOOT_SUDO-sudo}" ]] && BOOT_SUDO_CMD=()
    BOOT_SYSTEM_DIR="${BOOT_SYSTEM_DIR:-/usr/local/lib/dragon-os-boot}"
    BOOT_HOOK_DIR="${BOOT_HOOK_DIR:-/etc/boot/hooks/post.d}"
    BOOT_ROOT="${BOOT_ROOT:-/}"
    BOOTLOADER="${BOOTLOADER:-auto}"
}

boot_first() { local f; for f in "$@"; do [[ -e "$f" ]] && { echo "$f"; return 0; }; done; return 1; }
boot_engine() { python3 "$REPO_DIR/dragon-core/dragon_boot.py" "$@"; }
boot_sys_engine() { "${BOOT_SUDO_CMD[@]}" env DRAGON_BOOT_SYSTEM_DIR="$BOOT_SYSTEM_DIR" python3 "$BOOT_SYSTEM_DIR/dragon_boot.py" "$@"; }

# a question about /boot is never answered by --yes. Minimal interface that works in the linear installer too: a plain [s/N] on the
# real terminal (default NO). Without a terminal nothing is asked and nothing is done.
boot_confirm() {
    [[ "${DRAGON_BOOT_ASSUME_YES:-}" == 1 ]] && return 0
    if ! have_tty; then
        log_warn "Arranque: no hay terminal donde preguntar; no se hace nada sin preguntar. Repite desde una terminal: ./install.sh --modules boot"
        return 1
    fi
    ask_plain "$1" no
}

# boot_preview <bootloader>: renders what the menu will look like (no system access) and says where the image is
boot_preview() {
    local out="${STATE_DIR:-$HOME/.local/state/dragon-island}/boot-preview.png"
    if $DRY_RUN; then echo "[dry-run] dragon-boot preview --out $out --bootloader $1"; return 0; fi
    mkdir -p "$(dirname "$out")"
    if boot_engine preview --out "$out" --bootloader "$1" >/dev/null 2>&1; then
        log_info "Vista previa del tema de arranque: $out   (ábrela con tu visor de imágenes antes de confirmar)"
    else
        log_warn "No se pudo generar la vista previa (¿python-pillow?); puedes seguir sin ella."
    fi
}

boot_detect() {   # → bootloader name or empty
    boot_vars
    local args=(detect --bootloader "$BOOTLOADER" --root "$BOOT_ROOT") out
    [[ -n "${BOOT_ESP:-}" ]] && args+=(--esp "$BOOT_ESP")
    out="$(boot_engine "${args[@]}" 2>/dev/null)" || return 1
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("bootloader") or "")' "$out"
}

boot_esp() {
    boot_vars
    [[ -n "${BOOT_ESP:-}" ]] && { echo "$BOOT_ESP"; return; }
    boot_engine detect --bootloader limine --root "$BOOT_ROOT" | python3 -c 'import json,sys; print((json.load(sys.stdin)["limine"]["esp"]) or "")'
}

boot_stage_dir() { mktemp -d "${TMPDIR:-/tmp}/dragon-boot.XXXXXX"; }

# boot_system_install <stage-dir>: root-owned copy of the engine, the settings, the wallpaper source and (Limine) the post hook
boot_system_install() {
    local stage="$1" hook_src="$REPO_DIR/config/boot/90-dragon-boot-theme" src
    boot_engine stage --bootloader limine --out "$stage" --json >/dev/null
    src="$(boot_first "$REPO_DIR"/assets/wallpapers/*.jpg || true)"
    run "${BOOT_SUDO_CMD[@]}" install -d -m 0755 "$BOOT_SYSTEM_DIR"
    run "${BOOT_SUDO_CMD[@]}" install -m 0644 "$REPO_DIR/dragon-core/dragon_boot.py" "$BOOT_SYSTEM_DIR/dragon_boot.py"
    run "${BOOT_SUDO_CMD[@]}" install -m 0644 "$stage/settings.json" "$BOOT_SYSTEM_DIR/settings.json"
    [[ -n "$src" ]] && run "${BOOT_SUDO_CMD[@]}" install -m 0644 "$src" "$BOOT_SYSTEM_DIR/wallpaper-src.${src##*.}"
    if [[ -d "$(dirname "$BOOT_HOOK_DIR")" || -x "${BOOT_ROOT%/}/usr/bin/limine-entry-tool" || -x /usr/bin/limine-entry-tool ]]; then
        run "${BOOT_SUDO_CMD[@]}" install -d -m 0755 "$BOOT_HOOK_DIR"
        run "${BOOT_SUDO_CMD[@]}" install -m 0755 "$hook_src" "$BOOT_HOOK_DIR/90-dragon-boot-theme"
    fi
}

boot_apply_limine() {
    local esp stage
    esp="$(boot_esp)"
    if [[ -z "$esp" ]]; then
        log_warn "No encuentro limine.conf (¿está montada la partición de arranque? ¿lo lee solo root?). Prueba: sudo $REPO_DIR/bin/dragon-boot detect"
        return 0
    fi
    log_info "Limine: $esp"
    boot_preview limine
    stage="$(boot_stage_dir)"
    if $DRY_RUN; then
        echo "[dry-run] se renderiza el papel tapiz, se copian el motor y el gancho con sudo y se aplica el bloque a limine.conf. Diferencia que se aplicaría:"
        boot_engine apply --bootloader limine --esp "$esp" --dry-run | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("diff") or d)' || log_warn "(no se pudo leer limine.conf sin sudo)"
        rm -rf "$stage"
        return 0
    fi
    boot_confirm "[sudo] Instalar el motor del tema en $BOOT_SYSTEM_DIR y el gancho de limine-entry-tool en $BOOT_HOOK_DIR (no toca /boot todavía)" || { rm -rf "$stage"; return 0; }
    boot_system_install "$stage"
    rm -rf "$stage"
    log_info "Simulación (solo lectura): lo que cambiaría en limine.conf"
    boot_sys_engine apply --bootloader limine --esp "$esp" --settings "$BOOT_SYSTEM_DIR/settings.json" --wallpaper "$(boot_first "$BOOT_SYSTEM_DIR"/wallpaper-src.*)" --dry-run \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["diff"] if d.get("ok") else d)' || { log_warn "La simulación falló: no se aplica nada."; return 0; }
    boot_confirm "[sudo] Aplicar el tema a limine.conf (copia de seguridad con fecha al lado; las entradas y Windows no se tocan)" || return 0
    boot_sys_engine apply --bootloader limine --esp "$esp" --settings "$BOOT_SYSTEM_DIR/settings.json" --wallpaper "$(boot_first "$BOOT_SYSTEM_DIR"/wallpaper-src.*)"
    boot_sys_engine verify --bootloader limine --esp "$esp"
    box "#00c1e4" "Tema de Limine aplicado" "Volver atrás: ./install.sh --modules boot --revert-boot   (o desde un USB: docs/BOOT.md §Recuperar)"
}

boot_apply_grub() {
    local stage
    boot_preview grub
    stage="$(boot_stage_dir)"
    if $DRY_RUN; then
        boot_engine apply --bootloader grub --root "$BOOT_ROOT" --dry-run --no-regen | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("diff") or d)' || log_warn "(no se pudo leer /etc/default/grub)"
        rm -rf "$stage"
        return 0
    fi
    boot_confirm "[sudo] Instalar el motor del tema en $BOOT_SYSTEM_DIR" || { rm -rf "$stage"; return 0; }
    run "${BOOT_SUDO_CMD[@]}" install -d -m 0755 "$BOOT_SYSTEM_DIR"
    run "${BOOT_SUDO_CMD[@]}" install -m 0644 "$REPO_DIR/dragon-core/dragon_boot.py" "$BOOT_SYSTEM_DIR/dragon_boot.py"
    rm -rf "$stage"
    boot_sys_engine apply --bootloader grub --root "$BOOT_ROOT" --dry-run --no-regen | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["diff"] if d.get("ok") else d)' || return 0
    boot_confirm "[sudo] Aplicar el tema de GRUB: /boot/grub/themes/dragon-os, bloque en /etc/default/grub y grub-mkconfig (se comprueba con grub-script-check antes de reemplazar grub.cfg; respaldos con fecha)" || return 0
    local extra=()
    [[ "$BOOT_ROOT" != / ]] && extra+=(--no-regen)
    boot_sys_engine apply --bootloader grub --root "$BOOT_ROOT" "${extra[@]}"
}

boot_revert_all() {
    boot_vars
    local bl esp
    bl="$(boot_detect)"
    [[ -z "$bl" ]] && { log_warn "No detecto ni Limine ni GRUB."; return 0; }
    if $DRY_RUN; then echo "[dry-run] dragon-boot revert --bootloader $bl"; return 0; fi
    boot_confirm "[sudo] Quitar el tema de Dragon OS del arranque ($bl): se restaura la configuración con una copia de seguridad nueva" || return 0
    if [[ "$bl" == limine ]]; then esp="$(boot_esp)"; boot_sys_engine revert --bootloader limine --esp "$esp"
    else boot_sys_engine revert --bootloader grub --root "$BOOT_ROOT"; fi
    run "${BOOT_SUDO_CMD[@]}" rm -f "$BOOT_HOOK_DIR/90-dragon-boot-theme"
}
