#!/usr/bin/env bash
# Shared deployment for fresh installs and migration 055. No daemon/group/config changes.
taller_tools_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py taller_common.py dragon_docker.py dragon_git.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    for file in dragon-docker dragon-git; do
        deploy_item "$REPO_DIR/bin/$file" "$HOME/.local/bin/$file"
    done
}

# fase5c: CLI only; keep Quickshell deployment in the UI branch.
prompt_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py taller_common.py dragon_prompt.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-prompt" "$HOME/.local/bin/dragon-prompt"
    for file in "$REPO_DIR"/config/dragon-prompt/templates/*.json; do
        deploy_item "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/dragon-prompt/templates/${file##*/}"
    done
}
