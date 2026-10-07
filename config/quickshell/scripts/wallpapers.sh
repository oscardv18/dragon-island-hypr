#!/usr/bin/env bash
# =============================================================================
# dragon-island — wallpapers.sh: helper of services/Wallpaper.qml (no native Quickshell API for these)
#   scan <dir>                    list wallpapers: path <TAB> kind <TAB> thumbnail <TAB> mtime
#   thumbs <dir>                  create the missing / outdated thumbnails; prints "ready <TAB> path" for each
#   apply-image <path> [type]     stop mpvpaper, make sure awww-daemon runs, show the image / GIF
#   apply-video <path> <out>...   stop awww and any old mpvpaper, start one mpvpaper per output (IPC socket each).
#                                 A video bigger than the screen (a 4K clip on a 768p laptop) costs a lot of GPU: it plays
#                                 at once, a screen-sized copy is made in the background (cache/video) and swapped in
#   optimize <path>               make that screen-sized H.264 copy (low priority); prints its path
#   running                       prints "video", "image<TAB>path" (what awww shows) or "none"
#   link <path>                   point ~/.cache/dragon-island/current-wallpaper at an image (hyprlock);
#                                 GIFs and videos get an extracted frame
# kinds: static (jpg png webp) · animated (gif) · video (mp4 webm mkv)
# =============================================================================
set -Eeuo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dragon-island"
THUMBS="$CACHE/thumbs"
CURRENT="$CACHE/current-wallpaper"
SOCKET_DIR="${XDG_RUNTIME_DIR:-/tmp}"
VIDEO_CACHE="$CACHE/video"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

kind_of() {
    local lower="${1,,}"
    case "$lower" in
        *.jpg|*.jpeg|*.png|*.webp) echo static ;;
        *.gif)                     echo animated ;;
        *.mp4|*.webm|*.mkv)        echo video ;;
        *)                         echo "" ;;
    esac
}

# thumbnail path: hash of path + mtime + size, so a changed file gets a new thumbnail
thumb_for() {
    local p="$1" m s key
    read -r m s < <(stat -c '%Y %s' -- "$p")
    key="$(printf '%s|%s|%s' "$p" "$m" "$s" | sha1sum | cut -c1-20)"
    printf '%s/%s.jpg' "$THUMBS" "$key"
}

each_wallpaper() {   # each_wallpaper <dir> <callback>
    local dir="$1" cb="$2" f
    [[ -d "$dir" ]] || return 0
    while IFS= read -r -d '' f; do
        [[ -n "$(kind_of "$f")" ]] && "$cb" "$f"
    done < <(find "$dir" -maxdepth 2 -type f -print0 | sort -z)
}

emit_line() {
    printf '%s\t%s\t%s\t%s\n' "$1" "$(kind_of "$1")" "$(thumb_for "$1")" "$(stat -c '%Y' -- "$1")"
}

make_thumb() {
    local f="$1" out tmp
    out="$(thumb_for "$f")"
    [[ -s "$out" ]] && { printf 'ready\t%s\n' "$f"; return 0; }
    tmp="$out.tmp.jpg"
    if [[ "$(kind_of "$f")" == video ]] && command -v ffmpegthumbnailer >/dev/null 2>&1; then
        ffmpegthumbnailer -i "$f" -o "$tmp" -s 640 -t 10% -q 8 >/dev/null 2>&1 || true
    fi
    if [[ ! -s "$tmp" ]]; then
        local ss=()
        [[ "$(kind_of "$f")" == video ]] && ss=(-ss 1)
        ffmpeg -nostdin -loglevel error -y "${ss[@]}" -i "$f" -frames:v 1 \
            -vf "scale=640:360:force_original_aspect_ratio=increase,crop=640:360" "$tmp" >/dev/null 2>&1 || true
    fi
    if [[ -s "$tmp" ]]; then
        mv -f -- "$tmp" "$out"
        printf 'ready\t%s\n' "$f"
    else
        rm -f -- "$tmp"
    fi
}

stop_video() {
    pkill -x mpvpaper 2>/dev/null || true
    rm -f "$SOCKET_DIR"/dragon-island-mpv-*.sock
}

awww_running() { pgrep -x awww-daemon >/dev/null 2>&1; }

ensure_awww() {
    awww_running || setsid -f awww-daemon >/dev/null 2>&1 </dev/null
    for _ in $(seq 1 30); do
        awww query >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "awww-daemon did not answer" >&2
    return 1
}

# ---- video: a clip much bigger than the screen is decoded, scaled and composited at full size every frame ----
screen_height() {
    hyprctl monitors -j 2>/dev/null | python3 -c "import json,sys; print(max(m['height'] for m in json.load(sys.stdin)))" 2>/dev/null || echo 1080
}
optimized_path() {   # optimized_path <video> <height>
    local m s key
    read -r m s < <(stat -c '%Y %s' -- "$1")
    key="$(printf '%s|%s|%s|%s' "$1" "$m" "$s" "$2" | sha1sum | cut -c1-20)"
    printf '%s/%s.mp4' "$VIDEO_CACHE" "$key"
}
video_is_oversized() {   # video_is_oversized <video> <screen height>  (more than 25 % taller than the screen)
    local h
    h="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$1" 2>/dev/null | head -n1)"
    [[ "$h" =~ ^[0-9]+$ ]] && (( h * 100 > $2 * 125 ))
}
optimize_video() {   # optimize_video <video>  → screen-sized H.264 copy, no audio, 30 fps
    local src="$1" h out tmp
    h="$(screen_height)"
    mkdir -p "$VIDEO_CACHE"
    out="$(optimized_path "$src" "$h")"
    if [[ ! -s "$out" ]]; then
        tmp="$out.tmp.mp4"
        if nice -n 15 ffmpeg -nostdin -loglevel error -y -i "$src" -an -vf "scale=-2:$h:flags=bicubic" -r 30 \
            -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -threads 4 -movflags +faststart "$tmp"; then
            mv -f -- "$tmp" "$out"
        else
            rm -f -- "$tmp"
            return 1
        fi
    fi
    printf '%s\n' "$out"
}

link_current() {
    local src="$1" frame
    mkdir -p "$CACHE"
    case "$(kind_of "$src")" in
        static)
            ln -sfn -- "$src" "$CURRENT" ;;
        animated|video)
            frame="$CACHE/current-frame.png"
            local ss=()
            [[ "$(kind_of "$src")" == video ]] && ss=(-ss 1)
            ffmpeg -nostdin -loglevel error -y "${ss[@]}" -i "$src" -frames:v 1 "$frame" >/dev/null 2>&1 || true
            [[ -s "$frame" ]] && ln -sfn -- "$frame" "$CURRENT" ;;
    esac
}

cmd="${1:-}"
shift || true

case "$cmd" in
    scan)
        mkdir -p "$THUMBS"
        each_wallpaper "${1:?dir}" emit_line ;;
    thumbs)
        mkdir -p "$THUMBS"
        each_wallpaper "${1:?dir}" make_thumb ;;
    apply-image)
        path="${1:?path}"
        type="${2:-grow}"
        stop_video
        ensure_awww
        awww img "$path" --transition-type "$type" --transition-pos center \
            --transition-fps 60 --transition-duration 1.2 --transition-step 90
        link_current "$path" ;;
    apply-video)
        path="${1:?path}"; shift
        stop_video
        play="$path"
        h="$(screen_height)"
        if video_is_oversized "$path" "$h"; then
            opt="$(optimized_path "$path" "$h")"
            if [[ -s "$opt" ]]; then
                play="$opt"
            else
                # play the original now; when the screen-sized copy exists, swap it in (if it is still the wallpaper)
                mkdir -p "$CACHE"
                printf '%s\n' "$path" > "$CACHE/current-video"
                outs=("$@")
                # shellcheck disable=SC2016  # the script runs in its own bash: its $1.. must not expand here
                setsid -f bash -c '
                    self="$1"; src="$2"; cache="$3"; shift 3
                    "$self" optimize "$src" >/dev/null 2>>"$cache/video-optimize.log" || exit 0
                    [[ "$(cat "$cache/current-video" 2>/dev/null)" == "$src" ]] && exec "$self" apply-video "$src" "$@"
                ' _ "$SELF" "$path" "$CACHE" "${outs[@]}" >/dev/null 2>&1 </dev/null
            fi
        fi
        for out in "$@"; do
            setsid -f mpvpaper \
                -o "no-audio loop hwdec=auto-safe profile=fast panscan=1.0 input-ipc-server=$SOCKET_DIR/dragon-island-mpv-$out.sock" \
                "$out" "$play" >/dev/null 2>&1 </dev/null
        done
        # awww and mpvpaper must not run together: stop awww once the video is on screen
        sleep 1
        awww_running && awww kill >/dev/null 2>&1 || true
        link_current "$path" ;;
    optimize)
        optimize_video "${1:?path}" ;;
    running)
        if pgrep -x mpvpaper >/dev/null 2>&1; then echo "video"
        elif awww_running && shown="$(awww query 2>/dev/null | grep -m1 -o "image: .*" | cut -c8-)" && [[ -n "$shown" ]]; then echo "image	$shown"
        else echo "none"; fi ;;
    link)
        link_current "${1:?path}" ;;
    *)
        echo "usage: $0 scan|thumbs|apply-image|apply-video|optimize|running|link" >&2
        exit 2 ;;
esac
