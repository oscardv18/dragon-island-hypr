#!/usr/bin/env bash
# shellcheck disable=SC2034  # PAUSE_MESSAGE is read by install.sh
# =============================================================================
# dragon-island — system preparation for the one-command installer (sourced by install.sh; needs common.sh, events.sh).
#   prepare_system   missing prerequisites + pacman -Syu in ONE transaction, kernel check, headers, AUR helper
#   progress_*       what the installer already did, so a run interrupted by a reboot continues where it stopped
# Nothing here writes in --dry-run: it only says what it would do.
# =============================================================================
PROGRESS_MAX_AGE=86400        # a recorded update older than this is not trusted: the system is updated again

prereq_q() { PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_DIR/lib/installer_prereq.py" --query "$1"; }

progress_file() { printf '%s/install-progress\n' "$STATE_DIR"; }
progress_get() {   # progress_get <key> → value ("" when unknown)
    local f; f="$(progress_file)"
    [[ -f "$f" ]] || return 0
    awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$f"
}
progress_set() {   # progress_set <key> <value>
    $DRY_RUN && return 0
    local f tmp; f="$(progress_file)"; mkdir -p "$STATE_DIR"
    tmp="$(mktemp "$STATE_DIR/.progress.XXXXXX")"
    { [[ -f "$f" ]] && awk -F= -v k="$1" '$1 != k' "$f"; printf '%s=%s\n' "$1" "$2"; } > "$tmp" || true
    mv -f "$tmp" "$f"
}
progress_clear() { $DRY_RUN || rm -f "$(progress_file)"; }
progress_update_is_fresh() {   # the recorded system update is recent enough to be skipped
    local at; at="$(progress_get updated_at)"
    [[ "$(progress_get stage)" =~ ^(updated|reboot|prepared)$ && "$at" =~ ^[0-9]+$ ]] && (( $(date +%s) - at < PROGRESS_MAX_AGE ))
}

# start_real_log: the first change of the run — from here the log lives in the state directory, not in a temporary file
start_real_log() {
    $DRY_RUN && return 0
    [[ -n "${PRELOG:-}" && -f "$PRELOG" ]] || return 0
    mkdir -p "$STATE_DIR"
    cat "$PRELOG" >> "$STATE_DIR/install.log"; rm -f "$PRELOG"; PRELOG=""
    LOG="$STATE_DIR/install.log"; exec >>"$LOG" 2>&1
}

# sudo_start: ONE password for the whole run (sudo -v + keep-alive). Returns 1 when it cannot be had.
SUDO_KEEPALIVE="${SUDO_KEEPALIVE:-}"
sudo_start() {
    $DRY_RUN && return 0
    $NO_SUDO && return 1
    [[ -n "$SUDO_KEEPALIVE" ]] && return 0
    if ! sudo -n true 2>/dev/null; then       # passwordless or already authenticated: nothing to ask
        have_tty || { ev_warn "sudo pide contraseña y no hay terminal donde escribirla."; return 1; }
        tui_suspend
        # shellcheck disable=SC2024  # the password prompt must use the real terminal
        if ! sudo -v </dev/tty >/dev/tty 2>&1; then tui_resume; return 1; fi
        tui_resume
    fi
    # detached from every pipe (>/dev/null): a captured stdout must not wait for the sleep after the installer ends
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) >/dev/null 2>&1 &
    SUDO_KEEPALIVE=$!
}

# build_aur_helper <aur-package>: git clone + makepkg as the user (never root); sudo is only used by makepkg for pacman
build_aur_helper() {
    local name="$1" dir rc=0
    dir="$(mktemp -d "${TMPDIR:-/tmp}/dragon-aur.XXXXXX")"
    ev_step "Construyendo el ayudante AUR «$name» desde AUR (git clone + makepkg)"
    ev_warn "$name se construye aquí sin revisar su PKGBUILD: es el ayudante AUR oficial de su proyecto. Revísalo si lo prefieres: https://aur.archlinux.org/packages/$name"
    run_streamed git clone --depth 1 "https://aur.archlinux.org/$name.git" "$dir/$name" || rc=$?
    if (( rc == 0 )); then
        if pushd "$dir/$name" >/dev/null; then
            run_streamed makepkg -si --noconfirm --needed || rc=$?
            popd >/dev/null || true
        else rc=1; fi
    fi
    rm -rf "$dir"
    return "$rc"
}

# prepare_system → 0 ready · 10 paused (reboot needed) · 1 failed. Fills PREP_NOTES (what was done) for the report.
prepare_system() {
    local missing helper_action helper_pkg update_needed=true headers_missing
    missing="$(prereq_q missing-base)" || return 1
    helper_action="$(prereq_q helper-action)" || return 1
    helper_pkg="$(prereq_q helper-aur-build)" || return 1
    headers_missing="$(prereq_q headers-missing)" || return 1
    if progress_update_is_fresh; then update_needed=false; fi

    if [[ "$(prereq_q reboot)" == yes ]]; then
        # an earlier update replaced the kernel that is running: nothing else makes sense before the reboot
        progress_set stage reboot
        PAUSE_MESSAGE="El kernel en uso ($(uname -r)) ya no es el instalado ($(prereq_q kernel)). Reinicia y vuelve a ejecutar ./install.sh: continuará donde lo dejó."
        return 10
    fi

    local -a steps=()
    [[ -n "$missing" ]] && steps+=("instalar los prerrequisitos que faltan: $missing")
    [[ "$helper_action" == aur ]] && steps+=("construir el ayudante AUR ($helper_pkg) desde AUR")
    $update_needed && steps+=("actualizar el sistema completo (pacman -Syu): evita actualizaciones parciales")
    [[ "$headers_missing" == yes ]] && steps+=("cabeceras del kernel ($(prereq_q headers)): después de la actualización, solo si el kernel sigue coincidiendo")
    if (( ${#steps[@]} == 0 )); then ev_step "Sistema preparado: prerrequisitos presentes y actualización al día."; return 0; fi

    ev_step "Preparación del sistema (sudo, una contraseña):"
    local s; for s in "${steps[@]}"; do ev_log "  · $s"; done
    if $DRY_RUN; then
        $update_needed && ev_log "[dry-run] sudo pacman -Syu --needed --noconfirm${missing:+ $missing}"
        [[ -z "$missing" ]] || $update_needed || ev_log "[dry-run] sudo pacman -S --needed --noconfirm $missing"
        [[ "$helper_action" == aur ]] && ev_log "[dry-run] git clone https://aur.archlinux.org/$helper_pkg.git && makepkg -si"
        [[ "$headers_missing" == yes ]] && ev_log "[dry-run] sudo pacman -S --needed --noconfirm $(prereq_q headers)"
        return 0
    fi
    if $NO_SUDO; then
        MANUAL_ITEMS+=("Prerrequisitos y actualización (--no-sudo): sudo pacman -Syu --needed ${missing}")
        ev_warn "Sin sudo (--no-sudo): hazlo a mano: sudo pacman -Syu --needed $missing"
        [[ -z "$missing" ]] && return 0
        return 1
    fi
    CONFIRM_YES="Preparar" CONFIRM_NO="Cancelar" CONFIRM_DETAIL="$(printf '  · %s\n' "${steps[@]}")" \
        confirm "¿Preparar el sistema? (una sola contraseña de sudo)" || { PAUSE_MESSAGE="Cancelado: no se cambió nada."; return 11; }
    start_real_log
    sudo_start || { ev_warn "sudo no autorizó la sesión."; return 1; }
    progress_set started_at "$(date +%s)"

    if $update_needed; then
        ev_step "[sudo] pacman -Syu --needed ${missing:+(con $missing)}"
        # one transaction: the prerequisites enter a consistent system, there is never a partial upgrade
        # shellcheck disable=SC2086
        run_streamed sudo pacman -Syu --needed --noconfirm $missing || { ev_warn "pacman -Syu falló: el sistema queda como estaba."; return 1; }
        progress_set stage updated; progress_set updated_at "$(date +%s)"
    elif [[ -n "$missing" ]]; then
        ev_step "[sudo] pacman -S --needed $missing"
        # shellcheck disable=SC2086
        run_streamed sudo pacman -S --needed --noconfirm $missing || { ev_warn "No se pudieron instalar los prerrequisitos."; return 1; }
    fi

    if [[ "$(prereq_q reboot)" == yes ]]; then
        progress_set stage reboot
        PAUSE_MESSAGE="La actualización cambió el kernel (en uso: $(uname -r); instalado: $(prereq_q kernel)). Reinicia y vuelve a ejecutar ./install.sh: continuará donde lo dejó; las cabeceras se instalan después, para el kernel nuevo."
        return 10
    fi
    if [[ "$(prereq_q headers-missing)" == yes ]]; then
        ev_step "[sudo] Cabeceras del kernel en uso: $(prereq_q headers)"
        run_streamed sudo pacman -S --needed --noconfirm "$(prereq_q headers)" || ev_warn "No se pudieron instalar las cabeceras; DKMS no compilará módulos hasta entonces."
    fi
    if [[ "$(prereq_q helper-action)" == aur ]]; then
        build_aur_helper "$helper_pkg" || { ev_warn "No se pudo construir $helper_pkg desde AUR."; return 1; }
    fi
    progress_set stage prepared
    return 0
}
