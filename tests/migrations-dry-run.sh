#!/usr/bin/env bash
# dragon-island — every migration in simulation mode (DRY_RUN=1 and DRY_RUN=true) in a temporary HOME that has work
# pending for them (a COPIED install: stale hypr/quickshell, settings.json with missing keys, an installed SDDM theme
# out of date…). Nothing may change: same file tree, contents, permissions and times in the HOME and the fake theme,
# same `git status` in the repo, no sudo / package / session command run, no «command not found». Also checks
# bin/dragon-sddm-sync and bin/dragon-palette with DRY_RUN=1.
# Safe by construction: env -i, HOME and XDG_* in a temp dir, shims on PATH log the commands that reach the system.
set -Euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
H="$T/home"; SHIMS="$T/shims"; THEME="$T/sddm-theme"; OUT="$T/out"
mkdir -p "$H" "$SHIMS" "$THEME" "$OUT"
fails=0
ok()  { echo "✔ $*"; }
bad() { echo "✘ $*"; fails=$((fails + 1)); }

# commands that change the system or the session: in a dry-run they may only be printed by run(), never executed
for c in sudo yay paru systemctl gsettings hyprctl hyprpm pkill setsid chsh localectl busctl curl qs quickshell \
    notify-send awww awww-daemon mpvpaper hypridle kbuildsycoca6 fc-cache; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s/calls.log"\nexit 1\n' "$c" "$SHIMS" > "$SHIMS/$c"
    chmod +x "$SHIMS/$c"
done

# read-only questions a migration may ask outside run() (calls.log keeps them out of the report)
READ_ONLY='^(qs list|hyprctl (version|-j .*)|systemctl --user is-(active|enabled) .*|gsettings get .*)$'

# ---- a copied install with something to do for each migration ----
C="$H/.config"
mkdir -p "$C/dragon-island" "$H/.local/state/dragon-island" "$H/.local/bin"
cp -r "$REPO_DIR/config/hypr" "$C/hypr"
cp -r "$REPO_DIR/config/quickshell" "$C/quickshell"
# shellcheck disable=SC2016  # $HOME is literal text inside autostart.lua
sed -i 's|--watch $HOME/.local/bin/dragon-clip-store|--watch cliphist store|' "$C/hypr/autostart.lua"   # 028
sed -i 's/qs ipc call switcher next/OLD/' "$C/hypr/binds.lua"                                              # 026
sed -i -E 's/(kb_options = ")/\1grp:alt_shift_toggle,/' "$C/hypr/input.lua"                               # 027
printf '%s\n' '-- >>> dragon-island:keyboard' 'hl.config({ input = { kb_options = "grp:alt_shift_toggle" } })' \
    '-- <<< dragon-island:keyboard' > "$C/hypr/local.lua"
echo '{"barStyle":"C"}' > "$C/dragon-island/settings.json"                                                # 020 023 025
printf 'export MY_OWN_LINE=1\n' > "$H/.zshrc"
printf '%s\n' core shell theme zsh > "$H/.local/state/dragon-island/components"
printf 'deploy\t%s\t%s\n' "$C/hypr" "$REPO_DIR/config/hypr" > "$H/.local/state/dragon-island/manifest"
cp -a "$REPO_DIR/sddm/dragon-core/." "$THEME/"                                                            # 024
echo '// old' > "$THEME/Main.qml"
mkdir -p "$H/.cache/dragon-island" "$H/.local/state/quickshell/launcher"
echo '{"org.kde.dolphin": 3}' > "$H/.local/state/quickshell/launcher/app-usage.json"                    # 007
# a palette from a wallpaper: dragon-palette apply has something to write
env -i HOME="$H" PATH=/usr/bin:/bin python3 -B "$REPO_DIR/dragon-core/palette.py" --quiet generate "$REPO_DIR/sddm/dragon-core/background.jpg" > /dev/null 2>&1 \
    || echo "- sin Pillow: dragon-palette apply se prueba sin paleta"

snapshot() {
    ( cd "$T" && find home sddm-theme -printf '%p %y %m %s %T@ %l\n' | sort
      cd "$T" && find home sddm-theme -type f -exec md5sum {} + | sort )
}
dry() {  # dry <DRY_RUN value> <command>...
    local v="$1"; shift
    env -i HOME="$H" USER="${USER:-test}" LANG=C PATH="$SHIMS:/usr/bin:/bin" PYTHONDONTWRITEBYTECODE=1 \
        REPO_DIR="$REPO_DIR" LINK_MODE=copy DRY_RUN="$v" ASSUME_YES=1 DRAGON_SDDM_THEME="$THEME" "$@"
}
# check_run <label> <log> <exit code> <allowed codes…>
check_run() {
    local label="$1" log="$2" code="$3"; shift 3
    local c allowed=false
    for c in "$@"; do [[ "$code" == "$c" ]] && allowed=true; done
    $allowed || bad "$label: código $code ($(tail -n 3 "$log" | tr '\n' ' '))"
    if grep -qiE 'command not found|orden no encontrada' "$log"; then bad "$label: $(grep -iE 'command not found|orden no encontrada' "$log" | head -n 1)"; fi
    if [[ -s "$SHIMS/calls.log" ]] && grep -vqE "$READ_ONLY" "$SHIMS/calls.log"; then
        bad "$label ejecutó de verdad: $(grep -vE "$READ_ONLY" "$SHIMS/calls.log" | tr '\n' ';')"
    fi
    : > "$SHIMS/calls.log"
}

before="$(snapshot)"
git_before="$(git -C "$REPO_DIR" status --porcelain)"
sleep 1   # a write in the same second would keep %T@ only if it also kept size and content: the md5 covers that

for v in 1 true; do
    n=0
    for m in "$REPO_DIR"/migrations/[0-9]*.sh; do
        id="$(basename "$m" .sh)"; log="$OUT/$id-$v.log"
        dry "$v" bash "$m" > "$log" 2>&1 < /dev/null; code=$?
        check_run "$id (DRY_RUN=$v)" "$log" "$code" 0 10
        n=$((n + 1))
    done
    after="$(snapshot)"
    if [[ "$before" == "$after" ]]; then ok "DRY_RUN=$v: $n migraciones sin cambiar nada en el HOME ni en el tema"
    else bad "DRY_RUN=$v cambió archivos:"; diff <(echo "$before") <(echo "$after") | head -n 20; fi
done

dry 1 "$REPO_DIR/bin/dragon-sddm-sync" > "$OUT/sync.log" 2>&1 < /dev/null; code=$?
check_run "dragon-sddm-sync (DRY_RUN=1)" "$OUT/sync.log" "$code" 0
if grep -q '^\[dry-run\] sudo install' "$OUT/sync.log"; then ok "dragon-sddm-sync muestra los pasos con sudo sin ejecutarlos"
else bad "dragon-sddm-sync no muestra sus pasos: $(tr '\n' ' ' < "$OUT/sync.log")"; fi
for sub in apply reset; do
    dry 1 "$REPO_DIR/bin/dragon-palette" "$sub" > "$OUT/palette-$sub.log" 2>&1 < /dev/null; code=$?
    check_run "dragon-palette $sub (DRY_RUN=1)" "$OUT/palette-$sub.log" "$code" 0
done
if grep -q '\[dry-run\]' "$OUT/palette-reset.log"; then ok "dragon-palette pasa a --dry-run con DRY_RUN=1"
else bad "dragon-palette no simuló: $(tr '\n' ' ' < "$OUT/palette-apply.log")"; fi

after="$(snapshot)"
if [[ "$before" == "$after" ]]; then ok "dragon-sddm-sync y dragon-palette no cambiaron nada"
else bad "dragon-sddm-sync / dragon-palette cambiaron archivos:"; diff <(echo "$before") <(echo "$after") | head -n 20; fi
if [[ "$git_before" == "$(git -C "$REPO_DIR" status --porcelain)" ]]; then ok "el repositorio sigue igual (git status)"
else bad "el dry-run cambió el repositorio"; fi

exit $(( fails > 0 ))
