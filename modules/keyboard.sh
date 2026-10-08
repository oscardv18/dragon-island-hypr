#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module keyboard — Hyprland layouts (default us,latam; us ALWAYS first: shortcuts resolve against the first one).
# Anything different from the default goes to ~/.config/hypr/local.lua; the login keymap (localectl) is opt-in.
# =============================================================================
KB_DEFAULT="us,latam"

keyboard_desc() { echo "Distribuciones de teclado (us,latam por defecto; us siempre primera)"; }
keyboard_sudo() { echo "solo localectl set-x11-keymap (opcional, confirmado)"; }
keyboard_packages() { :; }

keyboard_check() { [[ "$(local_conf_get KB_LAYOUTS)" != "" ]] || grep -qs 'kb_layout *= *"us,latam"' "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/input.lua"; }

keyboard_plan() {
    echo "  · pregunta las distribuciones (por defecto $KB_DEFAULT) y las escribe en ~/.config/hypr/local.lua si difieren"
    echo "  · opcional (sudo): localectl set-x11-keymap para que el login arranque en us"
}

keyboard_apply() {
    local layouts="${DRAGON_KB_LAYOUTS:-$(local_conf_get KB_LAYOUTS)}"
    layouts="${layouts:-$KB_DEFAULT}"
    if ! $ASSUME_YES && has_gum && [[ -z "${DRAGON_KB_LAYOUTS:-}" ]]; then
        layouts="$(gum input --header "Distribuciones separadas por coma (us primero):" --value "$layouts")" || layouts="$KB_DEFAULT"
    fi
    layouts="${layouts// /}"; [[ -n "$layouts" ]] || layouts="$KB_DEFAULT"
    # us always first
    case ",$layouts," in
        ,us,*) ;;
        *) layouts="us,${layouts//,us/}"; layouts="${layouts%,}" ;;
    esac
    if [[ ! "$layouts" =~ ^[a-z]{2,3}(,[a-z]{2,3})*$ ]]; then log_warn "Distribuciones no válidas («$layouts»): se usa $KB_DEFAULT."; layouts="$KB_DEFAULT"; fi

    if $DRY_RUN; then echo "[dry-run] KB_LAYOUTS=$layouts en $LOCAL_CONF"
    else mkdir -p "$(dirname "$LOCAL_CONF")"; grep -v '^KB_LAYOUTS=' "$LOCAL_CONF" 2>/dev/null > "$LOCAL_CONF.tmp" || true
         printf 'KB_LAYOUTS=%s\n' "$layouts" >> "$LOCAL_CONF.tmp"; mv "$LOCAL_CONF.tmp" "$LOCAL_CONF"; fi

    if [[ "$layouts" == "$KB_DEFAULT" ]]; then
        marker_unset "$HYPR_LOCAL" keyboard "--"
    else
        local variants; variants="$(printf '%s' "$layouts" | tr -c ',' ' ' | tr ' ' '\n' | paste -sd, -)"
        marker_set "$HYPR_LOCAL" keyboard "--" "hl.config({ input = { kb_layout = \"$layouts\", kb_variant = \"${variants//[^,]/}\", kb_options = \"grp:alt_shift_toggle\" } })"
    fi

    if command -v localectl >/dev/null 2>&1 && [[ "$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/ {print $2}')" != "$layouts" ]]; then
        confirm "¿Fijar también el teclado del login a «$layouts»? (sudo localectl set-x11-keymap)" \
            && { confirm_sudo "Teclado del login (SDDM / TTY): $layouts" localectl set-x11-keymap "$layouts" || true; }
    fi
    return 0
}

keyboard_revert() {
    marker_unset "$HYPR_LOCAL" keyboard "--"
    log_info "keyboard: vuelve el valor por defecto de input.lua ($KB_DEFAULT). El keymap del login (localectl) no se toca."
}
