#!/usr/bin/env bash
# Shared deployment for fresh installs and migration 070.
files_tools_setup() {
    local file data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines"
    for file in secret_filter.py engine_common.py taller_common.py dragon_git.py dragon_files.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-files" "$HOME/.local/bin/dragon-files"
}
