#!/usr/bin/env bash
# 007 — orbital launcher: launch counts and favourites now live in ~/.local/state/dragon-island/launcher.json
# ({ "usage": { id: count }, "favorites": [id] }). Carries over the old Quickshell app-usage.json once.
# Everything else (QML, scripts/icon-paths.sh) comes with the repo; the live reload applies it.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=installer/migration-env.sh
. "$REPO_DIR/installer/migration-env.sh"

NEW="$STATE_DIR/launcher.json"
if [[ -e "$NEW" ]]; then
    log_info "launcher.json ya existe: nada que migrar."
    exit 0
fi
OLD="$(find "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell" -name app-usage.json 2>/dev/null | head -n1)"
if [[ -z "$OLD" ]]; then
    log_info "Sin historial del lanzador antiguo: empieza vacío."
    exit 0
fi
if $DRY_RUN; then
    echo "[dry-run] $OLD -> $NEW"
else
    python3 -I - "$OLD" "$NEW" <<'PY'
import json, sys
usage = json.load(open(sys.argv[1]))
json.dump({"usage": usage, "favorites": []}, open(sys.argv[2], "w"))
PY
    log_info "Historial del lanzador copiado a $NEW"
fi
exit 0
