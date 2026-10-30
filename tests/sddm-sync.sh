#!/usr/bin/env bash
# dragon-island — bin/dragon-sddm-sync prepares the login background without pre-blurring it.
# For each tool (ImageMagick, then ffmpeg alone on PATH) and for a 4K wallpaper and a small, heavily compressed one:
# background.jpg must be 1920×1080, JPEG quality ≥ 90 and as sharp as a plain resize of the source (the old script
# blurred it 0x16 before the greeter blurred it again: that double blur over a compressed JPEG made the bands).
# Without magick and ffmpeg it must refuse with a message. The sudo steps go through a shim that runs them as the user
# into a temporary theme, so nothing outside the temp dir is touched.
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
printf '#!/usr/bin/env bash\nexec "$@"\n' > "$T/shims/sudo"
chmod +x "$T/shims/sudo"
for c in bash env readlink dirname mktemp rm cp install python3 grep cut sed date; do
    p="$(command -v "$c")" && ln -s "$p" "$T/shims/$c"
done
for v in magick ffmpeg none; do
    mkdir -p "$T/path-$v"
    cp -a "$T/shims/." "$T/path-$v/"
    [[ "$v" != none ]] && command -v "$v" >/dev/null && ln -s "$(command -v "$v")" "$T/path-$v/$v"
done

sync_with() {   # sync_with <tool dir> <wallpaper> → theme dir in $T/theme
    rm -rf "${T:?}/home" "${T:?}/theme"
    mkdir -p "$T/home/.cache/dragon-island" "$T/theme"
    ln -s "$2" "$T/home/.cache/dragon-island/current-wallpaper"
    env -i HOME="$T/home" PATH="$T/path-$1" DRAGON_SDDM_THEME="$T/theme" \
        "$REPO_DIR/bin/dragon-sddm-sync" --yes > "$T/out.log" 2>&1
}
# mean absolute Laplacian: edge energy; a pre-blurred image has much less than a plain resize
sharpness() { magick "$1" -colorspace Gray -define convolve:scale='!' -morphology Convolve Laplacian:0 -evaluate Abs 0 -format '%[fx:mean*1000]' info:; }

for tool in magick ffmpeg; do
    command -v "$tool" >/dev/null || { echo "- $tool no está: se omite"; continue; }
    for w in wall-4k wall-small; do
        if ! sync_with "$tool" "$T/$w.jpg"; then bad "$tool / $w: dragon-sddm-sync falló: $(tr '\n' ' ' < "$T/out.log")"; continue; fi
        out="$T/theme/background.jpg"
        size="$(magick identify -format '%wx%h' "$out")"
        q="$(magick identify -format '%Q' "$out")"
        magick "$T/$w.jpg" -resize 1920x1080^ -gravity center -extent 1920x1080 "$T/ref.png"
        got="$(sharpness "$out")"; ref="$(sharpness "$T/ref.png")"
        if [[ "$size" == 1920x1080 ]]; then ok "$tool / $w: 1920×1080"; else bad "$tool / $w: tamaño $size"; fi
        if (( q >= 90 )); then ok "$tool / $w: calidad JPEG $q"; else bad "$tool / $w: calidad JPEG $q (< 90)"; fi
        if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) >= 0.6 * float(sys.argv[2]) else 1)' "$got" "$ref"; then
            ok "$tool / $w: sin desenfoque previo (nitidez $got frente a $ref)"
        else bad "$tool / $w: desenfocado (nitidez $got frente a $ref de un redimensionado simple)"; fi
    done
done

if sync_with none "$T/wall-4k.jpg"; then bad "sin magick ni ffmpeg terminó bien"
elif grep -q 'Falta ImageMagick (magick) o ffmpeg' "$T/out.log" && [[ ! -e "$T/theme/background.jpg" ]]; then ok "sin magick ni ffmpeg avisa y no toca el tema"
else bad "sin magick ni ffmpeg: $(tr '\n' ' ' < "$T/out.log")"; fi

(( fails == 0 )) || { echo "$fails fallo(s)"; exit 1; }
