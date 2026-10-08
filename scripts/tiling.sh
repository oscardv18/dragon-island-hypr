#!/usr/bin/env bash
# =============================================================================
# dragon-island — tiling.sh (installed as ~/.local/bin/dragon-tiling): dwindle <-> scrolling, per workspace
#   tiling.sh get [--json]      mode of the focused workspace ("dwindle" | "scrolling")
#   tiling.sh set <mode>        dwindle | scrolling, for the focused workspace
#   tiling.sh toggle            the other one
#   tiling.sh restore           re-apply every saved mode (hyprland.start / config.reloaded call it)
#   get / set / toggle accept `--workspace NAME` (any workspace, not only the focused one)
# The mode is a Hyprland workspace rule (`hl.workspace_rule({ workspace = "name:N", layout = ... })`, applied with
# `hyprctl eval`); windows are never closed or moved between workspaces. It is saved in
# ~/.local/state/dragon-island/tiling.json  {"workspaces": {"<workspace name>": "scrolling"}}  (dwindle = no entry);
# a missing / corrupt file counts as "all dwindle". Afterwards it asks Quickshell to refresh (best effort).
# =============================================================================
set -Eeuo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
STATE="$STATE_DIR/tiling.json"
MODES=(dwindle scrolling)

die() { echo "tiling: $*" >&2; exit 1; }
valid_mode() { [[ " ${MODES[*]} " == *" $1 "* ]]; }
valid_ws()   { [[ "$1" =~ ^[A-Za-z0-9_.:-]+$ ]]; }

# the workspace to act on (default: the focused one; --workspace NAME picks another): prints "<name>\t<tiledLayout>"
WS_ARG=""
active() {
    if [[ -n "$WS_ARG" ]]; then
        hyprctl -j workspaces | jq -r --arg n "$WS_ARG" '[.[] | select(.name == $n)][0] // empty | [.name, .tiledLayout] | @tsv'
    else
        hyprctl -j activeworkspace | jq -r '[.name, .tiledLayout] | @tsv'
    fi
}

# the saved state as JSON ("{}" when missing or corrupt)
state() {
    if [[ -f "$STATE" ]] && jq -e '.workspaces | type == "object"' "$STATE" >/dev/null 2>&1; then cat -- "$STATE"
    else echo '{"workspaces":{}}'; fi
}

# rule for one workspace; special workspaces are addressed by their own name, the others as "name:<name>"
apply() {
    local ws="$1" mode="$2" target
    valid_ws "$ws" || die "nombre de workspace no válido: $ws"
    valid_mode "$mode" || die "modo no válido: $mode (dwindle | scrolling)"
    if [[ "$ws" == special:* ]]; then target="$ws"; else target="name:$ws"; fi
    hyprctl eval "hl.workspace_rule({ workspace = \"$target\", layout = \"$mode\" })" >/dev/null
}

save() {
    local ws="$1" mode="$2" tmp
    mkdir -p -- "$STATE_DIR"
    tmp="$(mktemp -- "$STATE.XXXXXX")"
    if [[ "$mode" == dwindle ]]; then state | jq --arg ws "$ws" 'del(.workspaces[$ws])' > "$tmp"
    else state | jq --arg ws "$ws" --arg m "$mode" '.workspaces[$ws] = $m' > "$tmp"; fi
    mv -- "$tmp" "$STATE"
}

refresh_shell() { qs ipc call tiling refresh >/dev/null 2>&1 || true; }

args=()
while (($#)); do
    case "$1" in
        --workspace) WS_ARG="${2:-}"; shift 2 || die "--workspace necesita un nombre" ;;
        *) args+=("$1"); shift ;;
    esac
done
set -- "${args[@]+"${args[@]}"}"
cmd="${1:-get}"
case "$cmd" in
    get)
        IFS=$'\t' read -r ws mode < <(active)
        [[ -n "${ws:-}" ]] || die "no hay workspace"
        if [[ "${2:-}" == "--json" ]]; then jq -cn --arg ws "$ws" --arg m "$mode" '{workspace: $ws, mode: $m}'; else echo "$mode"; fi
        ;;
    set|toggle)
        IFS=$'\t' read -r ws mode < <(active)
        [[ -n "${ws:-}" ]] || die "no hay workspace"
        if [[ "$cmd" == toggle ]]; then
            if [[ "$mode" == scrolling ]]; then new=dwindle; else new=scrolling; fi
        else
            new="${2:-}"; valid_mode "$new" || die "uso: tiling.sh set dwindle|scrolling"
        fi
        apply "$ws" "$new"
        save "$ws" "$new"
        refresh_shell
        echo "$new"
        ;;
    restore)
        while IFS=$'\t' read -r ws mode; do
            [[ -n "$ws" ]] || continue
            apply "$ws" "$mode" || true
        done < <(state | jq -r '.workspaces | to_entries[] | [.key, .value] | @tsv')
        refresh_shell
        ;;
    *) die "uso: tiling.sh get [--json] | set dwindle|scrolling | toggle | restore" ;;
esac
