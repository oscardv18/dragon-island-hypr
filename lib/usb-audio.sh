#!/usr/bin/env bash
# =============================================================================
# dragon-island — arreglos de dispositivos de audio USB: config/modprobe.d/dragon-usb-audio.conf en /etc/modprobe.d
# (opciones de snd-usb-audio; hoy, el micrófono de los audífonos Jieli 4c4a:4155). Sourced, never executed.
# DRAGON_MODPROBE_DIR cambia la carpeta de destino (pruebas).
# =============================================================================

# usb_audio_quirks_setup: installs the file with sudo (confirmed) when it is missing or differs, and removes the
# hand-made /etc/modprobe.d/jieli-headset-mic.conf that carried the same options before it reached the installer.
# Returns 1 when sudo is disabled or the person declined (confirm_sudo already printed the manual command).
usb_audio_quirks_setup() {
    local dir="${DRAGON_MODPROBE_DIR:-/etc/modprobe.d}" src="$REPO_DIR/config/modprobe.d/dragon-usb-audio.conf"
    local dest legacy changed=false
    dest="$dir/dragon-usb-audio.conf"
    legacy="$dir/jieli-headset-mic.conf"
    if cmp -s -- "$src" "$dest"; then
        log_info "Audio USB: $dest ya está al día"
    else
        confirm_sudo "Arreglos de audio USB en $dest (micrófono de los audífonos Jieli 4c4a:4155)" \
            install -Dm644 -- "$src" "$dest" || return 1
        changed=true
    fi
    # the old hand-made file: only removed when its options are exactly ours (otherwise it is somebody's own)
    if [[ -f "$legacy" ]] && [[ "$(grep -v '^[[:space:]]*\(#\|$\)' "$legacy")" == "$(grep -v '^[[:space:]]*\(#\|$\)' "$src")" ]]; then
        confirm_sudo "Quitar $legacy (sus opciones ya están en $dest)" rm -f -- "$legacy" || true
    fi
    if $changed; then
        log_info "Audio USB: se aplica al reconectar el dispositivo tras reiniciar (o al recargar snd-usb-audio)."
    fi
    return 0
}
