#!/usr/bin/env bash
# 029 — the login looked posterised over a real wallpaper and the name sat on the sphere's nodes.
#   - dragon-sddm-sync no longer pre-blurs: it copies a sharp 1920×1080 JPEG (q 92) and the greeter blurs it once, with
#     a grain tile (noise.png, theme.conf `noise`) that breaks the banding; the name sits on a plate under the sphere,
#     and the avatar is the user's photo when the greeter can read one
#   - ~/.local/bin/dragon-sddm-sync is redeployed when it is a copy (a symlink already follows the repo)
#   - only if dragon-core is ALREADY installed in /usr/share/sddm/themes: a full copy of the installed theme is kept
#     next to it (dragon-core.bak-dragon-<date>), the new files are copied in and dragon-sddm-sync runs once, so the
#     old pre-blurred background is replaced. Every sudo step needs an interactive yes: with --yes / no terminal it only
#     says what to run and is retried on the next update (exit 10)
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

# ---- the sync script (a copied install keeps the old, pre-blurring one) ----
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
up_to_date=true
for f in Main.qml theme.conf noise.png components/NeuralCore.qml components/CoreIcon.qml; do
    cmp -s "$SRC/$f" "$DEST/$f" || up_to_date=false
done
# a background synced by the old script: 1280×720 and not the theme's own
old_bg=false
if [[ -f "$DEST/background.jpg" ]] && ! cmp -s "$SRC/background.jpg" "$DEST/background.jpg" \
   && command -v magick >/dev/null 2>&1 \
   && [[ "$(magick identify -format '%wx%h' "$DEST/background.jpg[0]" 2>/dev/null)" == 1280x720 ]]; then
    old_bg=true
fi
if $up_to_date && ! $old_bg; then
    [[ $changed -eq 1 ]] && exit 0
    log_info "El tema de login ya está al día."
    exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
if $DRY_RUN; then
    log_info "[dry-run] Login sin bandas: una actualización real preguntaría antes de usar sudo. Pasos:"
elif $ASSUME_YES || ! has_gum || [[ ! -t 0 ]]; then
    log_info "Login sin bandas: no se instala sin confirmación interactiva. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
elif ! gum confirm --affirmative "Sí" --negative "No" "¿Actualizar el login dragon-core (fondo nítido sin bandas, nombre bajo la esfera, tu foto)? (pide sudo; guarda una copia del actual)"; then
    log_info "Omitido. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
fi

if ! $up_to_date; then
    run sudo cp -a -- "$DEST" "$DEST.bak-dragon-$stamp"
    log_info "Respaldo: $DEST.bak-dragon-$stamp"
    run sudo install -d -m 755 "$DEST/components" "$DEST/fonts"
    run sudo install -m 644 "$SRC"/*.qml "$SRC"/metadata.desktop "$SRC"/theme.conf "$SRC"/preview.png "$SRC"/noise.png "$SRC"/LICENSE "$DEST/"
    run sudo install -m 644 "$SRC"/components/*.qml "$DEST/components/"
    run sudo install -m 644 "$SRC"/fonts/*.ttf "$DEST/fonts/"
fi
# dragon-sddm-sync keeps its own .bak-dragon of background.jpg / accent.conf and honours DRY_RUN
run "$REPO_DIR/bin/dragon-sddm-sync" --yes || log_warn "dragon-sddm-sync no terminó: el login usa el fondo anterior. Reintenta: dragon-sddm-sync"
$DRY_RUN && exit 0
log_info "Login actualizado. Pruébalo sin cerrar sesión: sddm-greeter-qt6 --test-mode --theme $DEST"
exit 0
