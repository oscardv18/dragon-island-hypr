#!/usr/bin/env bash
# Shared adapter deployment; does not start or stop the user's herdr server.
herdr_bridge_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py taller_common.py mem_schema.sql dragon_mem.py dragon_herdr.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-herdr" "$HOME/.local/bin/dragon-herdr"
}
