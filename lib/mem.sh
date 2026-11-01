#!/usr/bin/env bash
# Shared by core and migration 044. Existing DBs are backed up only before a schema upgrade.
mem_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py taller_common.py mem_schema.sql dragon_mem.py mem_install.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-mem" "$HOME/.local/bin/dragon-mem"
    run python3 -S "$REPO_DIR/dragon-core/mem_install.py"
}
