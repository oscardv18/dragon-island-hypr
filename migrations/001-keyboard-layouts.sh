#!/usr/bin/env bash
# 001 — keyboard layouts: English (US) + Spanish (Latin American), SUPER+ALT+Space to switch.
# Symlinked configs already follow the repo; this only patches a *copy* of config/hypr
# (input.lua and binds.lua) that still has the old layout. Custom layouts are left alone.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

HYPR_DIR="$HOME/.config/hypr"
INPUT="$HYPR_DIR/input.lua"
BINDS="$HYPR_DIR/binds.lua"

if [[ ! -e "$INPUT" ]]; then
    log_info "No hay $INPUT: nada que migrar (Hyprland no está desplegado)."
    exit 0
fi

# The deployed directory is a symlink to the repo: the repo version is the one in use
if [[ "$(readlink -f "$HYPR_DIR")" == "$(readlink -f "$REPO_DIR/config/hypr")" ]]; then
    if grep -q 'kb_layout *= *"us,latam"' "$REPO_DIR/config/hypr/input.lua"; then
        log_info "config/hypr es un symlink al repo: la distribución us,latam ya está aplicada."
        exit 0
    fi
    log_warn "El repo no define us,latam en input.lua; nada que hacer."
    exit 0
fi

patched=false
if grep -q 'kb_layout *= *"us,latam"' "$INPUT"; then
    log_info "input.lua ya usa us,latam."
elif grep -qE 'kb_layout *= *"(latam,us|us|latam|)"' "$INPUT"; then
    backup_copy "$INPUT"
    run sed -i -E \
        -e 's/(kb_layout *= *)"[^"]*"/\1"us,latam"/' \
        -e 's/(kb_variant *= *)"[^"]*"/\1","/' \
        -e 's/(kb_options *= *)"[^"]*"/\1"grp:alt_shift_toggle"/' \
        "$INPUT"
    patched=true
    log_info "input.lua: kb_layout = us,latam, kb_variant = ',', Alt+Shift para cambiar."
else
    log_warn "input.lua tiene una distribución personalizada: no se toca. Pon a mano kb_layout = \"us,latam\"."
fi

if [[ -f "$BINDS" ]] && ! grep -q "switchxkblayout" "$BINDS"; then
    backup_copy "$BINDS"
    if ! $DRY_RUN; then
        cat >> "$BINDS" <<'LUA'

-- Keyboard layout: next one in kb_layout (migration 001)
bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), "Teclado · Cambiar distribución (US / LA)")
LUA
    else
        echo "[dry-run] añadir el atajo SUPER+ALT+Space a $BINDS"
    fi
    patched=true
    log_info "binds.lua: añadido SUPER + ALT + Espacio."
fi

$patched && log_info "Se aplicará con la recarga en vivo de update.sh (hyprctl reload)."
exit 0
