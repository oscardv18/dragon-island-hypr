#!/usr/bin/env bash
# 004 — wallpaper picker: awww (images / GIF) + mpvpaper (video) replace hyprpaper.
# Installs the packages, creates ~/Pictures/Wallpapers with the repo's wallpapers, carries over a custom
# wallpaper from the old ~/.local/share/dragon-island/wallpaper.jpg, and swaps the daemons in the running
# session. The Quickshell restart at the end of update.sh restores the saved wallpaper.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
OLD="$HOME/.local/share/dragon-island/wallpaper.jpg"
STATE_JSON="$STATE_DIR/wallpaper.json"

# ---- packages ----
missing=()
for p in awww ffmpeg ffmpegthumbnailer mpv; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    if confirm "Faltan paquetes para los fondos: ${missing[*]}. ¿Instalarlos con pacman?"; then
        run sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        log_info "Sin los paquetes no se puede aplicar la migración: se reintentará la próxima vez."
        exit 10
    fi
fi
if ! pacman -Qq mpvpaper >/dev/null 2>&1; then
    helper=""
    for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }; done
    if [[ -n "$helper" ]] && confirm "mpvpaper (fondos de vídeo, AUR) no está instalado. ¿Instalarlo con $helper?"; then
        run "$helper" -S --needed --noconfirm mpvpaper
    else
        log_warn "Sin mpvpaper no habrá fondos de vídeo (imágenes y GIF sí). Instálalo con: yay -S mpvpaper"
    fi
fi

# ---- folder with the wallpapers of the repo (never replaces anything) ----
run mkdir -p "$WALLPAPER_DIR"
for wp in "$REPO_DIR"/assets/wallpapers/*; do
    [[ -e "$WALLPAPER_DIR/$(basename "$wp")" ]] || run cp -n -- "$wp" "$WALLPAPER_DIR/"
done

# ---- a wallpaper the user put in the old place (not the repo's) keeps being used ----
if [[ -f "$OLD" && ! -e "$STATE_JSON" ]]; then
    repo_default="$REPO_DIR/assets/wallpapers/dragon-island.jpg"
    if ! cmp -s "$OLD" "$repo_default"; then
        run cp -n -- "$OLD" "$WALLPAPER_DIR/mi-fondo.jpg"
        if ! $DRY_RUN; then
            printf '{\n    "kind": "static",\n    "path": "%s"\n}\n' "$WALLPAPER_DIR/mi-fondo.jpg" > "$STATE_JSON"
        fi
        log_info "Tu fondo personalizado se copió a $WALLPAPER_DIR/mi-fondo.jpg y queda como fondo actual."
    fi
fi

# ---- swap the daemons in the running session ----
if pgrep -x hyprpaper >/dev/null 2>&1; then
    log_info "Deteniendo hyprpaper (lo sustituye awww-daemon)."
    run pkill -x hyprpaper || true
fi
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v awww-daemon >/dev/null 2>&1 && ! pgrep -x awww-daemon >/dev/null 2>&1 && ! pgrep -x mpvpaper >/dev/null 2>&1; then
    if $DRY_RUN; then echo "[dry-run] awww-daemon"; else setsid -f awww-daemon >/dev/null 2>&1 </dev/null; fi
fi

exit 0
