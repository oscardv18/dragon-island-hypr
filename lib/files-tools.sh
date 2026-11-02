#!/usr/bin/env bash
# Shared deployment for fresh installs and migration 070.
files_tools_setup() {
    local file data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines"
    for file in secret_filter.py engine_common.py taller_common.py dragon_git.py dragon_files.py files_archives.py files_network.py files_share.py files_desktop.py files_filemanager1.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-files" "$HOME/.local/bin/dragon-files"
    deploy_item "$REPO_DIR/config/applications/dragon-files.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/dragon-files.desktop"
}
