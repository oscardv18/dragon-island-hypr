#!/usr/bin/env bash
# Pinned versions (packages/pins.json) against what is installed. Sourced by doctor.sh and scripts/plugins-foreground.sh
# (the installed copy of the script has pins.sh and pins.json beside it). Read-only.
PINS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PINS_JSON="${PINS_JSON:-$PINS_DIR/../packages/pins.json}"
[[ -f "$PINS_JSON" ]] || PINS_JSON="$PINS_DIR/pins.json"

# pin_get <key> → value ("" when unset or null)
pin_get() {
    python3 -c 'import json,sys
v = json.load(open(sys.argv[1])).get(sys.argv[2])
print("" if v is None else v)' "$PINS_JSON" "$1" 2>/dev/null
}

# hyprland_installed_series → "0.57" (from the running compositor, else the package)
hyprland_installed_series() {
    local v=""
    if command -v hyprctl >/dev/null 2>&1; then
        v="$(hyprctl version -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag",""))' 2>/dev/null || true)"
    fi
    [[ -n "$v" ]] || v="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')"
    v="${v#v}"; v="${v#*:}"
    awk -F. 'NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+/ { sub(/[^0-9].*/, "", $2); print $1 "." $2 }' <<<"$v"
}

# hyprland_pin_check: 0 = matches · 1 = differs (message on stdout) · 2 = cannot tell
hyprland_pin_check() {
    local want have
    want="$(pin_get hyprland)"; have="$(hyprland_installed_series)"
    [[ -n "$want" ]] || { echo "No hay versión fijada (packages/pins.json)."; return 2; }
    [[ -n "$have" ]] || { echo "No se pudo leer la versión de Hyprland instalada."; return 2; }
    if [[ "$want" == "$have" ]]; then echo "Hyprland $have = fijada $want"; return 0; fi
    echo "Hyprland instalado: $have · fijada para los plugins y la configuración: $want"
    return 1
}
