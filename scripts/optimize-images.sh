#!/usr/bin/env bash
# Lossless PNG compression; optional downscale for design references exported at 2x.
set -Eeuo pipefail
trap 'echo "Error al optimizar imágenes (línea $LINENO)." >&2' ERR
resize=false; dry_run=false
inputs=()
for arg in "$@"; do
    case "$arg" in
        --resize) resize=true ;;
        --dry-run) dry_run=true ;;
        -h|--help)
            echo "Uso: $0 [--resize] [--dry-run] <archivo.png|directorio>..."
            echo "--resize: reduce a un máximo de 1366 px de ancho; sin él, compresión sin pérdida."
            exit 0 ;;
        --*) echo "Opción desconocida: $arg" >&2; exit 2 ;;
        *) inputs+=("$arg") ;;
    esac
done
((${#inputs[@]})) || { echo "Indica archivos PNG o directorios (ver --help)." >&2; exit 2; }
if command -v oxipng >/dev/null 2>&1; then
    optimizer=(oxipng -o 2 --quiet)
elif command -v optipng >/dev/null 2>&1; then
    optimizer=(optipng -o2 -quiet)
else
    echo "Falta oxipng u optipng. Instala uno antes de ejecutar este script." >&2
    exit 1
fi
if $resize && ! command -v magick >/dev/null 2>&1; then
    echo "--resize necesita ImageMagick (magick)." >&2
    exit 1
fi
# Validate every input before changing anything; directories are searched recursively.
for input in "${inputs[@]}"; do
    [[ -d "$input" || ( -f "$input" && "${input,,}" == *.png ) ]] || {
        echo "No es un PNG o directorio: $input" >&2; exit 2;
    }
done
mapfile -d '' -t files < <(find "${inputs[@]}" -type f -iname '*.png' -print0 | sort -zu)
((${#files[@]})) || { echo "No se encontraron imágenes PNG." >&2; exit 2; }
total_before=0; total_after=0
temporary=""
trap '[[ -z "$temporary" ]] || rm -rf -- "$temporary"' EXIT
for file in "${files[@]}"; do
    before="$(stat -c %s -- "$file")"
    total_before=$((total_before + before))
    if $dry_run; then
        printf '[dry-run] %s: antes %s bytes → después pendiente (%s; resize=%s)\n' "$file" "$before" "${optimizer[0]}" "$resize"
        continue
    fi
    temporary="$(mktemp -d)"
    resized=false
    if $resize && (( $(magick identify -format '%w' "$file") > 1366 )); then
        magick "$file" -resize '1366x>' "$temporary/image.png"
        resized=true
    else
        cp -- "$file" "$temporary/image.png"
    fi
    "${optimizer[@]}" "$temporary/image.png"
    after="$(stat -c %s -- "$temporary/image.png")"
    if $resized || ((after < before)); then
        cat "$temporary/image.png" > "$file"
    else
        after="$before"
    fi
    total_after=$((total_after + after))
    printf '%s: %s → %s bytes\n' "$file" "$before" "$after"
    rm -rf -- "$temporary"
    temporary=""
done
if $dry_run; then
    printf 'Total antes: %s bytes; después: pendiente (simulación, sin escrituras).\n' "$total_before"
else
    printf 'Total: %s → %s bytes; ahorro: %s bytes.\n' "$total_before" "$total_after" "$((total_before - total_after))"
fi
