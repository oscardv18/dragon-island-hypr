#!/usr/bin/env bash
# 024 — phase 3: the new login screen (sddm/dragon-core after 07-login.png) and bin/dragon-sddm-sync.
#   - ~/.local/bin/dragon-sddm-sync (copies your wallpaper and its accent into the theme; run it by hand after a change)
#   - only if dragon-core is ALREADY installed in /usr/share/sddm/themes (the opt-in `login` module): a full copy of the
#     installed theme is kept next to it (dragon-core.bak-dragon-<date>), the new files are copied in, and
#     dragon-sddm-sync runs once. Every sudo step needs an interactive yes: with --yes / no terminal it only says
#     what to run and is retried on the next update (exit 10).
#   - the theme is not installed → nothing to do there (install it with sddm/install-theme.sh)
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

# ---- the sync script ----
if ! [[ -e "$BIN/dragon-sddm-sync" && "$(readlink -f "$BIN/dragon-sddm-sync")" == "$(readlink -f "$REPO_DIR/bin/dragon-sddm-sync")" ]] \
   && ! { [[ "$LINK_MODE" == copy && -f "$BIN/dragon-sddm-sync" ]] && cmp -s "$REPO_DIR/bin/dragon-sddm-sync" "$BIN/dragon-sddm-sync"; }; then
    deploy_item "$REPO_DIR/bin/dragon-sddm-sync" "$BIN/dragon-sddm-sync"
    changed=1
fi

# ---- the installed theme ----
if [[ ! -d "$DEST" ]]; then
    log_info "El tema de login dragon-core no está instalado: nada que actualizar (cuando quieras: $REPO_DIR/sddm/install-theme.sh)."
    exit 0
fi
up_to_date=true
for f in Main.qml theme.conf metadata.desktop components/NeuralCore.qml components/CoreIcon.qml; do
    cmp -s "$SRC/$f" "$DEST/$f" || up_to_date=false
done
if $up_to_date; then
    [[ $changed -eq 1 ]] && exit 0
    log_info "El tema de login ya está al día."
    exit 10
fi

stamp="$(date +%Y%m%d-%H%M%S)"
if $DRY_RUN; then
    log_info "[dry-run] Login nuevo (07-login): una actualización real preguntaría antes de usar sudo. Pasos:"
elif $ASSUME_YES || ! has_gum || [[ ! -t 0 ]]; then
    log_info "Login nuevo (07-login): no se instala sin confirmación interactiva. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
elif ! gum confirm --affirmative "Sí" --negative "No" "¿Actualizar el tema de login dragon-core al diseño nuevo, con tu fondo y su acento? (pide sudo; guarda una copia del actual)"; then
    log_info "Omitido. Cuando quieras: $REPO_DIR/sddm/install-theme.sh y después dragon-sddm-sync"
    exit 10
fi

run sudo cp -a -- "$DEST" "$DEST.bak-dragon-$stamp"
log_info "Respaldo: $DEST.bak-dragon-$stamp"
run sudo install -d -m 755 "$DEST/components" "$DEST/fonts"
run sudo install -m 644 "$SRC"/*.qml "$SRC"/metadata.desktop "$SRC"/theme.conf "$SRC"/preview.png "$SRC"/LICENSE "$DEST/"
run sudo install -m 644 "$SRC"/components/*.qml "$DEST/components/"
run sudo install -m 644 "$SRC"/fonts/*.ttf "$DEST/fonts/"
[[ -f "$DEST/background.jpg" ]] || run sudo install -m 644 "$SRC/background.jpg" "$DEST/"
run "$REPO_DIR/bin/dragon-sddm-sync" --yes || log_warn "dragon-sddm-sync no terminó: el login usa el fondo y el acento por defecto. Reintenta: dragon-sddm-sync"
$DRY_RUN && exit 0
log_info "Login actualizado. Pruébalo sin cerrar sesión: sddm-greeter-qt6 --test-mode --theme $DEST"
exit 0
