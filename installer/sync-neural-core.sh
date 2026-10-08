#!/usr/bin/env bash
# dragon-island — single source for the neural core: shared/neural-core/*.qml is copied to the two places that
# need it (Quickshell lock screen and the SDDM theme) so they never drift apart.
#   sync-neural-core.sh          copy the shared files over both destinations
#   sync-neural-core.sh --check  only compare (exit 1 on drift); safe for dry-run / CI
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$REPO_DIR/shared/neural-core"
DESTS=("$REPO_DIR/config/quickshell/components" "$REPO_DIR/sddm/dragon-core/components")

drift=0
for f in "$SRC"/*.qml; do
    for d in "${DESTS[@]}"; do
        if [[ "${1:-}" == "--check" ]]; then
            diff -q -- "$f" "$d/$(basename "$f")" >/dev/null 2>&1 || { echo "drift: $d/$(basename "$f")"; drift=1; }
        else
            cmp -s -- "$f" "$d/$(basename "$f")" 2>/dev/null || install -D -m 0644 -- "$f" "$d/$(basename "$f")"
        fi
    done
done
exit $drift
