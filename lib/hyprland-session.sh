#!/usr/bin/env bash
# Sourced by update.sh and plugins-foreground.sh (also deployed beside its installed copy).
# Recover a stale terminal environment only when exactly one instance matches its Wayland display.
# Read-only: no commands are sent to other sessions, no environment files are changed.
hyprland_session() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl version >/dev/null 2>&1; then
        return 0
    fi
    [[ -n "${WAYLAND_DISPLAY:-}" ]] || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    local instances signature
    instances="$(hyprctl -j instances 2>/dev/null)" || return 1
    signature="$(python3 -c '
import json, os, sys
try:
    display = os.path.basename(sys.argv[1])
    matches = [row["instance"] for row in json.load(sys.stdin)
               if row.get("wl_socket") == display]
    if len(matches) != 1 or not isinstance(matches[0], str) or not matches[0]:
        sys.exit(1)
    print(matches[0])
except (ValueError, KeyError, TypeError, AttributeError):
    sys.exit(1)
' "$WAYLAND_DISPLAY" <<< "$instances")" || return 1
    HYPRLAND_INSTANCE_SIGNATURE="$signature" hyprctl version >/dev/null 2>&1 || return 1
    export HYPRLAND_INSTANCE_SIGNATURE="$signature"
    echo "Hyprland: conexión recuperada con la sesión de $WAYLAND_DISPLAY ($signature)." >&2
}
