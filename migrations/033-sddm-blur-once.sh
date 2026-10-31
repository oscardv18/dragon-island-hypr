#!/usr/bin/env bash
# 033 — the login still showed hard-edged blotches: the greeter's MultiEffect blur (seen in sddm-greeter-qt6
# --test-mode). Now dragon-sddm-sync blurs the wallpaper once (halved, gaussian `background_blur` from theme.conf,
# bicubic back to 1920×1080, fine grain) into background.png, and Main.qml shows it with no effect.
#   - ~/.local/bin/dragon-sddm-sync is redeployed when it is a copy (a symlink already follows the repo)
#   - only if dragon-core is ALREADY installed in /usr/share/sddm/themes and differs from the repo, or has no
#     background.png yet: a full copy of the installed theme is kept next to it (dragon-core.bak-dragon-<date>), the
#     new files are copied in (a `background_blur` already set in the installed theme.conf is kept) and
#     dragon-sddm-sync runs once. Every sudo step needs an interactive yes: with --yes / no terminal it only says what
#     to run and is retried on the next update (exit 10)
# Idempotent; honours DRY_RUN and ASSUME_YES.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
trap 'log_warn "Error en la línea $LINENO. Revisa $LOG"' ERR

SRC="$REPO_DIR/sddm/dragon-core"
DEST="${DRAGON_SDDM_THEME:-/usr/share/sddm/themes/dragon-core}"
BIN="$HOME/.local/bin"
changed=0

# ---- the sync script (a copied install keeps the one that does not blur) ----
if [[ "$LINK_MODE" == copy && -f "$BIN/dragon-sddm-sync" && ! -L "$BIN/dragon-sddm-sync" ]] \
   && ! cmp -s "$REPO_DIR/bin/dragon-sddm-sync" "$BIN/dragon-sddm-sync"; then
    deploy_item "$REPO_DIR/bin/dragon-sddm-sync" "$BIN/dragon-sddm-sync"
    changed=1
fi

# ---- the installed theme ----
if [[ ! -d "$DEST" ]]; then
    log_info "El tema de login dragon-core no está instalado: nada que actualizar (cuando quieras: $REPO_DIR/sddm/install-theme.sh)."
    exit 0
fi
# theme.conf is compared without the user's background_blur line
conf_of() { grep -v '^background_blur=' "$1" 2>/dev/null || true; }
up_to_date=true
for f in Main.qml noise.png components/NeuralCore.qml components/CoreIcon.qml; do
    cmp -s "$SRC/$f" "$DEST/$f" || up_to_date=false
done
[[ "$(conf_of "$SRC/theme.conf")" == "$(conf_of "$DEST/theme.conf")" ]] || up_to_date=false
has_png=false
[[ -f "$DEST/background.png" ]] && has_png=true
if $up_to_date && $has_png; then
    [[ $changed -eq 1 ]] && exit 0
    log_info "El tema de login ya está al día."
    exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
if $DRY_RUN; then
    log_info "[dry-run] Login sin manchas: una actualización real preguntaría antes de usar sudo. Pasos:"
elif $ASSUME_YES || ! has_gum || [[ ! -t 0 ]]; then
    log_info "Login sin manchas: no se instala sin confirmación interactiva. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
elif ! gum confirm --affirmative "Sí" --negative "No" "¿Actualizar el login dragon-core (fondo desenfocado una sola vez, sin manchas)? (pide sudo; guarda una copia del actual)"; then
    log_info "Omitido. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
fi

if ! $up_to_date; then
    blur="$(sed -n 's/^background_blur=//p' "$DEST/theme.conf" 2>/dev/null || true)"
    run sudo cp -a -- "$DEST" "$DEST.bak-dragon-$stamp"
    log_info "Respaldo: $DEST.bak-dragon-$stamp"
    run sudo install -d -m 755 "$DEST/components" "$DEST/fonts"
    run sudo install -m 644 "$SRC"/*.qml "$SRC"/metadata.desktop "$SRC"/theme.conf "$SRC"/preview.png "$SRC"/noise.png "$SRC"/LICENSE "$DEST/"
    run sudo install -m 644 "$SRC"/components/*.qml "$DEST/components/"
    run sudo install -m 644 "$SRC"/fonts/*.ttf "$DEST/fonts/"
    if [[ "$blur" =~ ^[0-9]{1,3}$ ]]; then
        run sudo sed -i "s/^background_blur=.*/background_blur=$blur/" "$DEST/theme.conf"
    fi
fi
# dragon-sddm-sync keeps its own .bak-dragon of background.png / accent.conf and honours DRY_RUN
run "$REPO_DIR/bin/dragon-sddm-sync" --yes || log_warn "dragon-sddm-sync no terminó: el login usa el fondo del tema. Reintenta: dragon-sddm-sync"
$DRY_RUN && exit 0
log_info "Login actualizado. Pruébalo sin cerrar sesión: sddm-greeter-qt6 --test-mode --theme $DEST"
exit 0
