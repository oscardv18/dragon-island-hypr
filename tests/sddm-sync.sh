#!/usr/bin/env bash
# dragon-island — bin/dragon-sddm-sync blurs the login background once, and the greeter does not blur it again.
# For each tool (ImageMagick, then ffmpeg alone on PATH) and for a 4K wallpaper and a small, heavily compressed one:
# background.png must be a PNG (or a JPEG of quality ≥ 90) of 1920×1080; with theme.conf `background_blur=0` as sharp
# as a plain resize of the source, with the default radius clearly softer (the greeter's MultiEffect blur left
# hard-edged blotches, so Main.qml must not use MultiEffect). Without magick and ffmpeg it must refuse with a message.
# The sudo steps go through a shim that runs them as the user into a temporary theme and logs them; with --dry-run or
# DRY_RUN=1 the shim must not run at all and the theme must stay as it was.
set -Euo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "✔ $*"; }
bad() { echo "✘ $*"; fails=$((fails + 1)); }
command -v magick >/dev/null || { echo "- magick no está: se omite (lo necesita la prueba para medir)"; exit 0; }

# wallpapers: a 4K one with detail (sharpness is measurable) and a small, compressed one
magick -size 3840x2160 plasma:fractal -seed 3 -blur 0x1 -quality 95 "$T/wall-4k.jpg" 2>/dev/null \
    || magick -size 3840x2160 xc: +noise Random -blur 0x2 -quality 95 "$T/wall-4k.jpg"
magick "$T/wall-4k.jpg" -resize 640x360 -quality 30 "$T/wall-small.jpg"

# PATH dirs: only what the script uses, with magick, with ffmpeg only, or with neither
mkdir -p "$T/shims"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/sudo.log"\nexec "$@"\n' "$T" > "$T/shims/sudo"
chmod +x "$T/shims/sudo"
for c in bash env readlink dirname mktemp rm cp install python3 grep cut sed date; do
    p="$(command -v "$c")" && ln -s "$p" "$T/shims/$c"
done
for v in magick ffmpeg none; do
    mkdir -p "$T/path-$v"
    cp -a "$T/shims/." "$T/path-$v/"
    [[ "$v" != none ]] && command -v "$v" >/dev/null && ln -s "$(command -v "$v")" "$T/path-$v/$v"
done

sync_with() {   # sync_with <tool dir> <wallpaper> [background_blur] [extra args / env] → theme dir in $T/theme
    rm -rf "${T:?}/home" "${T:?}/theme" "${T:?}/sudo.log"
    mkdir -p "$T/home/.cache/dragon-island" "$T/theme"
    ln -s "$2" "$T/home/.cache/dragon-island/current-wallpaper"
    [[ -n "${3:-}" ]] && printf '[General]\nbackground_blur=%s\n' "$3" > "$T/theme/theme.conf"
    env -i HOME="$T/home" PATH="$T/path-$1" DRAGON_SDDM_THEME="$T/theme" "${@:5}" \
        "$REPO_DIR/bin/dragon-sddm-sync" --yes ${4:+"$4"} > "$T/out.log" 2>&1
}
# PNG 1920×1080 (8-bit, no alpha) or JPEG quality ≥ 90 → "ok", else what is wrong
check_format() {
    local m size q
    read -r m size q < <(magick identify -format '%m %wx%h %Q\n' "$1[0]")
    [[ "$size" == 1920x1080 ]] || { echo "tamaño $size"; return; }
    case "$m" in
        PNG)  [[ "$(magick identify -format '%z %A' "$1")" =~ ^8\ (False|Undefined)$ ]] && echo ok || echo "PNG que no es de 24 bits" ;;
        JPEG) (( q >= 90 )) && echo ok || echo "JPEG de calidad $q (< 90)" ;;
        *)    echo "formato $m" ;;
    esac
}
# mean absolute Laplacian: edge energy; a pre-blurred image has much less than a plain resize
sharpness() { magick "$1" -colorspace Gray -define convolve:scale='!' -morphology Convolve Laplacian:0 -evaluate Abs 0 -format '%[fx:mean*1000]' info:; }

# the same at 480×270: the grain averages out and only the blur is left
coarse() { magick "$1" -resize 480x270 "$T/coarse.png"; sharpness "$T/coarse.png"; }

for tool in magick ffmpeg; do
    command -v "$tool" >/dev/null || { echo "- $tool no está: se omite"; continue; }
    for w in wall-4k wall-small; do
        magick "$T/$w.jpg" -resize 1920x1080^ -gravity center -extent 1920x1080 "$T/ref.png"
        ref="$(coarse "$T/ref.png")"
        # background_blur=0: sharp
        if ! sync_with "$tool" "$T/$w.jpg" 0; then bad "$tool / $w: dragon-sddm-sync falló: $(tr '\n' ' ' < "$T/out.log")"; continue; fi
        out="$T/theme/background.png"
        f="$(check_format "$out")"
        if [[ "$f" == ok ]]; then ok "$tool / $w: 1920×1080, $(magick identify -format '%m' "$out")"; else bad "$tool / $w: $f"; fi
        got="$(coarse "$out")"
        if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) >= 0.6 * float(sys.argv[2]) else 1)' "$got" "$ref"; then
            ok "$tool / $w: background_blur=0 es nítido (nitidez $got frente a $ref)"
        else bad "$tool / $w: background_blur=0 desenfocado (nitidez $got frente a $ref de un redimensionado simple)"; fi
        sharp_coarse="$got"
        # default radius (no theme.conf): blurred once
        if ! sync_with "$tool" "$T/$w.jpg"; then bad "$tool / $w: dragon-sddm-sync falló: $(tr '\n' ' ' < "$T/out.log")"; continue; fi
        f="$(check_format "$out")"
        [[ "$f" == ok ]] || bad "$tool / $w (desenfoque por defecto): $f"
        got="$(coarse "$out")"
        if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) <= 0.6 * float(sys.argv[2]) else 1)' "$got" "$sharp_coarse"; then
            ok "$tool / $w: el radio por defecto desenfoca (nitidez $got frente a $sharp_coarse)"
        else bad "$tool / $w: el radio por defecto no desenfoca (nitidez $got frente a $sharp_coarse)"; fi
    done
done

# dry run: the sudo steps go through run, so nothing is executed and the theme is untouched
for how in flag env; do
    if [[ "$how" == flag ]]; then sync_with magick "$T/wall-small.jpg" 0 --dry-run; else sync_with magick "$T/wall-small.jpg" 0 '' DRY_RUN=1; fi
    if [[ ! -s "$T/sudo.log" && ! -e "$T/theme/background.png" ]] && grep -q '\[dry-run\] sudo install' "$T/out.log"; then
        ok "dry-run ($how): enseña los pasos con sudo y no ejecuta ninguno"
    else bad "dry-run ($how): $(tr '\n' ' ' < "$T/out.log") sudo: $(tr '\n' ' ' 2>/dev/null < "$T/sudo.log")"; fi
done

# the greeter shows the image as is
qml="$REPO_DIR/sddm/dragon-core/Main.qml"
if grep -v '^[[:space:]]*//' "$qml" | grep -q -E 'MultiEffect|QtQuick\.Effects|FastBlur|GaussianBlur'; then
    bad "Main.qml sigue desenfocando el fondo (MultiEffect / blur)"
else ok "Main.qml muestra el fondo sin MultiEffect ni otro desenfoque"; fi

if sync_with none "$T/wall-4k.jpg" 0; then bad "sin magick ni ffmpeg terminó bien"
elif grep -q 'Falta ImageMagick (magick) o ffmpeg' "$T/out.log" && [[ ! -e "$T/theme/background.png" ]]; then ok "sin magick ni ffmpeg avisa y no toca el tema"
else bad "sin magick ni ffmpeg: $(tr '\n' ' ' < "$T/out.log")"; fi

(( fails == 0 )) || { echo "$fails fallo(s)"; exit 1; }
