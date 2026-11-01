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
