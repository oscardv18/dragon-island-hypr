#!/usr/bin/env bash
# Shared by core/shell installation and migration 030. Caller has common.sh.
# shellcheck disable=SC2034
palette_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/palette" file target
    deploy_item "$REPO_DIR/bin/dragon-palette" "$HOME/.local/bin/dragon-palette"
    deploy_item "$REPO_DIR/bin/dragon-fastfetch" "$HOME/.local/bin/dragon-fastfetch"
    for file in palette.py palette_apps.py palette_runtime.py palette_fastfetch.py palette-templates; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" wrapper
    for wrapper in "$cfg/dragon-island/zsh/dragon.zsh" "$cfg/dragon-island/zsh/fastfetch.zsh" "$cfg/dragon-island/fastfetch.zsh"; do
        [[ -f "$wrapper" ]] || continue
        file="$REPO_DIR/config/zsh/$(basename "$wrapper")"
        [[ "$(readlink -f "$wrapper")" == "$(readlink -f "$file")" ]] && continue
        deploy_item "$file" "$wrapper"
    done
    # Plan first: a malformed Starship file must abort before any app edit.
    local backups
    backups="$(mktemp)"
    if ! python3 "$REPO_DIR/scripts/palette-setup.py" --backups > "$backups"; then
        rm -f "$backups"
        return 1
    fi
    while IFS= read -r -d '' target; do backup_copy "$target"; done < "$backups"
    rm -f "$backups"
    if $DRY_RUN; then
        python3 "$REPO_DIR/scripts/palette-setup.py" --dry-run
    else
        python3 "$REPO_DIR/scripts/palette-setup.py"
    fi
}

# Once converted, keep the user's main config (its only addition was an include).
# Other shipped files, such as Ghostty's dropdown config, continue to update.
palette_terminal_deploy() {
    local terminal="$1" cfg="${XDG_CONFIG_HOME:-$HOME/.config}" main file
    main="$cfg/$terminal/config"
    [[ "$terminal" == kitty ]] && main="$cfg/kitty/kitty.conf"
    [[ "$terminal" == ghostty && -f "$cfg/ghostty/config.ghostty" ]] && main="$cfg/ghostty/config.ghostty"
    if [[ -f "$main" ]] && grep -qF "$cfg/dragon-island/palette/" "$main"; then
        for file in "$REPO_DIR/config/$terminal/"*; do
            [[ "$(basename "$file")" == config || "$(basename "$file")" == kitty.conf ]] && continue
            cmp -s -- "$file" "$cfg/$terminal/$(basename "$file")" && continue
            deploy_item "$file" "$cfg/$terminal/$(basename "$file")"
        done
    else
        deploy_item "$REPO_DIR/config/$terminal" "$cfg/$terminal"
    fi
}

# update.sh must not replace these detached user files/directories with a fresh
# repo link: that would erase the one-line includes or the active Starship block.
palette_config_managed() {
    local target="$1" cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$target" in
        "$cfg/ghostty") grep -qF "$cfg/dragon-island/palette/ghostty.conf" "$target/config" "$target/config.ghostty" 2>/dev/null ;;
        "$cfg/kitty") grep -qF "$cfg/dragon-island/palette/dragon-dynamic.conf" "$target/kitty.conf" 2>/dev/null ;;
        "${STARSHIP_CONFIG:-$cfg/starship.toml}") grep -qF '# >>> dragon-palette' "$target" 2>/dev/null ;;
        *) return 1 ;;
    esac
}
