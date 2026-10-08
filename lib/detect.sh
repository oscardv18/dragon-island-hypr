#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables shared with the scripts that source this file
# =============================================================================
# dragon-island — detection helpers (sourced): distro, GPU, display manager, versions, AUR helper.
# Add a distro by extending detect_distro and providing its package map in packages/ (nothing else is guessed).
# =============================================================================

# detect_distro → sets DISTRO_ID, DISTRO_NAME, DISTRO_SUPPORTED (true for Arch, EndeavourOS, CachyOS and Arch derivatives)
detect_distro() {
    DISTRO_ID="unknown"; DISTRO_NAME="desconocida"; DISTRO_SUPPORTED=false
    [[ -f /etc/os-release ]] || return 0
    local ID="" ID_LIKE="" PRETTY_NAME=""
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="$ID"; DISTRO_NAME="${PRETTY_NAME:-$ID}"
    case "$ID" in
        arch|endeavouros|cachyos) DISTRO_SUPPORTED=true ;;
        *) [[ " ${ID_LIKE:-} " == *" arch "* ]] && DISTRO_SUPPORTED=true ;;
    esac
    return 0
}

# detect_gpu → GPU_VENDOR (amd|intel|nvidia|unknown), GPU_NAME, GPU_DRIVER_LOADED (kernel driver bound: true/false)
detect_gpu() {
    GPU_VENDOR="unknown"; GPU_NAME=""; GPU_DRIVER_LOADED=false
    command -v lspci >/dev/null 2>&1 || return 0
    local line
    line="$(lspci -nnk 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /(vga|3d|display)/ {print; getline; print; getline; print; getline; print; exit}' || true)"
    GPU_NAME="$(head -n1 <<<"$line" | sed -E 's/^[^ ]+ [^:]+: //')"
    case "${line,,}" in
        *nvidia*)                GPU_VENDOR="nvidia" ;;
        *"[amd"*|*"ati "*|*amd*) GPU_VENDOR="amd" ;;
        *intel*)                 GPU_VENDOR="intel" ;;
    esac
    grep -qiE 'driver in use: (amdgpu|radeon|i915|xe|nvidia|nouveau)' <<<"$line" && GPU_DRIVER_LOADED=true
    return 0
}

# display_manager → sddm | plasmalogin | none | <unit>
display_manager() {
    local unit
    unit="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    case "$unit" in
        *sddm*) echo sddm ;;
        *plasmalogin*|*plasma-login*) echo plasmalogin ;;
        "") echo none ;;
        *) basename "$unit" .service ;;
    esac
}

aur_helper() {
    local h
    for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { echo "$h"; return 0; }; done
    return 0
}

# ver_ge <have> <want>  → 0 when have >= want (dotted numbers; epochs and pkgrel are ignored)
ver_ge() {
    local have="${1#*:}" want="$2"
    have="${have%%-*}"
    [[ "$(printf '%s\n%s\n' "$want" "$have" | sort -V | head -n1)" == "$want" ]]
}

# installed_version <pkg> → version without epoch / pkgrel, or "" when not installed
installed_version() { local v; v="$(pacman -Q "$1" 2>/dev/null | awk '{print $2}')"; v="${v#*:}"; echo "${v%%-*}"; }

# repo_version <pkg> → version in the synced repos ("" when unknown)
repo_version() { local v; v="$(pacman -Si "$1" 2>/dev/null | awk -F': *' '/^(Version|Versión)/ {print $2; exit}')"; v="${v#*:}"; echo "${v%%-*}"; }

in_hyprland() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; }
