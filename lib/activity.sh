#!/usr/bin/env bash
# Shared by fresh core installs and migration 040; caller supplies common.sh.
activity_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py engine_common.py activity_index.py dragon_activity.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-activity" "$HOME/.local/bin/dragon-activity"
}
