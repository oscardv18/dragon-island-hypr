#!/usr/bin/env bash
# Keep documentation images small enough to review and fetch comfortably.
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
directory="${1:-$REPO_DIR/docs}"
failed=0
while IFS= read -r -d '' file; do
    bytes="$(stat -c %s -- "$file")"
    if ((bytes > 1500000)); then
        printf '✘ %s: %s bytes (máximo 1,5 MB). Usa scripts/optimize-images.sh; para referencias de diseño, añade --resize.\n' "$file" "$bytes" >&2
        failed=1
    fi
done < <(find "$directory" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' -o -iname '*.svg' \
    -o -iname '*.bmp' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.ico' \) -print0)
exit "$failed"
