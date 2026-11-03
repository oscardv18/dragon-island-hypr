#!/usr/bin/env bash
# shellcheck disable=SC2154  # C_* colours come from lib/tui.sh, sourced before this file
# =============================================================================
# dragon-island — the PLAN screen text (sourced by install.sh; uses lib/tui.sh geometry helpers).
# It is what the user reads before the single «Instalar todo»: package table, size, every incident with
# WHICH package, WHY and WHAT the installer will do, and the steps that need sudo. Pure text: it runs nothing.
# Inputs: PLAN_PKGS (name<TAB>state<TAB>detail<TAB>source<TAB>engine), PLAN_ISSUES (action<TAB>subject<TAB>why<TAB>does),
#         SIZE_BYTES, DEPS_COUNT, SELECTED, and the sudo steps in PLAN_SUDO_STEPS.
# =============================================================================
declare -a PLAN_ISSUES=()
declare -a PLAN_SUDO_STEPS=()
DEPS_COUNT=0

plan_action_label() {
    case "$1" in
        bloquear) printf '%sBLOQUEA%s' "${C_red}" "${C_reset}" ;;
        sustituir) printf '%sSUSTITUYE%s' "${C_amber}" "${C_reset}" ;;
        omitir) printf '%sOMITE%s' "${C_cyan}" "${C_reset}" ;;
        compilar) printf '%sCOMPILA%s' "${C_violet}" "${C_reset}" ;;
        conservar) printf '%sCONSERVA%s' "${C_dim}" "${C_reset}" ;;
        nota) printf '%sNOTA%s' "${C_cyan}" "${C_reset}" ;;
        *) printf '%sAVISO%s' "${C_amber}" "${C_reset}" ;;
    esac
}

plan_text() {
    tui_size
    local W=$((TUI_W_TERM - 4)); (( W > 100 )) && W=100; (( W < 56 )) && W=56
    local row name state detail _s _e line n_have=0 n_new=0 n_aur=0 n_bad=0
    local -a have=() cells=() bad=()
    for row in "${PLAN_PKGS[@]}"; do
        IFS=$'\t' read -r name state detail _s _e <<<"$row"
        case "$state" in
            installed) n_have=$((n_have + 1)); have+=("$name") ;;
            install) n_new=$((n_new + 1)); cells+=("${C_cyan}↓${C_reset} $name") ;;
            aur) n_aur=$((n_aur + 1)); cells+=("${C_violet}◆${C_reset} $name") ;;
            conflict|failed) n_bad=$((n_bad + 1)); bad+=("${C_red}✖${C_reset} $name — $detail") ;;
        esac
    done
    printf '%s%sPlan de instalación%s\n' "${C_bold}" "${C_magenta}" "${C_reset}"
    printf '%s\n' "$(tui_rule "Paquetes  (↓ oficial · ◆ AUR · ✖ conflicto)" "$W")"
    # a compact grid: one row per package would scroll the confirmation off a small terminal
    local cols=$(( W / 27 )) cellw i=0 text
    (( cols < 1 )) && cols=1
    cellw=$(( (W - 2) / cols ))
    if (( ${#cells[@]} )); then
        local lineout=""
        for text in "${cells[@]}"; do
            local plain="${text//$'\e'\[*([0-9;])m/}"
            lineout+="$text$(tui_rep ' ' $(( cellw - ${#plain} < 1 ? 1 : cellw - ${#plain} )))"
            i=$((i + 1))
            if (( i % cols == 0 )); then printf '  %s\n' "$lineout"; lineout=""; fi
        done
        [[ -z "$lineout" ]] || printf '  %s\n' "$lineout"
    else printf '  %s(nada nuevo que instalar)%s\n' "${C_dim}" "${C_reset}"; fi
    for text in "${bad[@]}"; do
        while IFS= read -r line; do printf '  %s\n' "$line"; done < <(tui_wrap $((W - 2)) "$text")
    done
    if (( n_have )); then
        printf '  %s✔ Ya instalados (%d):%s\n' "${C_dim}" "$n_have" "${C_reset}"
        while IFS= read -r line; do printf '    %s%s%s\n' "${C_dim}" "$line" "${C_reset}"; done < <(tui_wrap $((W - 4)) "${have[*]}")
    fi
    printf '\n  %s%d a instalar · %d AUR · %d ya instalados · %d con conflicto%s\n' "${C_text}" "$n_new" "$n_aur" "$n_have" "$n_bad" "${C_reset}"
    printf '  %sDescarga ≈ %s%s' "${C_text}" "$(human_size "$SIZE_BYTES")" "${C_reset}"
    (( DEPS_COUNT > 0 )) && printf '%s (+ %d dependencias que añade pacman)%s' "${C_dim}" "$DEPS_COUNT" "${C_reset}"
    printf '\n\n%s\n' "$(tui_rule "Incidencias (${#PLAN_ISSUES[@]}): qué paquete, por qué y qué hará el instalador" "$W")"
    if (( ${#PLAN_ISSUES[@]} == 0 )); then printf '  %sNinguna: todo se resuelve solo.%s\n' "${C_green}" "${C_reset}"; fi
    local action subject why does
    for row in "${PLAN_ISSUES[@]}"; do
        IFS=$'\t' read -r action subject why does <<<"$row"
        printf '  %s  %s%s%s\n' "$(plan_action_label "$action")" "${C_bold}" "$subject" "${C_reset}"
        while IFS= read -r line; do printf '      %s\n' "$line"; done < <(tui_wrap $((W - 6)) "Por qué: $why")
        while IFS= read -r line; do printf '      %s\n' "$line"; done < <(tui_wrap $((W - 6)) "Qué hará: $does")
    done
    printf '\n%s\n' "$(tui_rule "Pasos con sudo (una sola contraseña)" "$W")"
    if (( ${#PLAN_SUDO_STEPS[@]} )); then
        for line in "${PLAN_SUDO_STEPS[@]}"; do
            while IFS= read -r row; do printf '  %s\n' "$row"; done < <(tui_wrap $((W - 2)) "· $line")
        done
    else printf '  %s(ninguno)%s\n' "${C_dim}" "${C_reset}"; fi
    printf '\n  Módulos: %s · despliegue: %s\n' "${SELECTED[*]}" "$LINK_MODE"
}
