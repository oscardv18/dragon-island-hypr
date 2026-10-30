#!/usr/bin/env bash
# Deployment shared by fresh installations and migration 032. Caller supplies common.sh.
engines_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    # Libraries first: an existing symlinked watcher may start as soon as its wrapper changes.
    for file in engine_common.py dragon_search.py search_calc.py search_cmd.py search_web.py search_emoji.py \
        dragon_usage.py dragon_clip.py dragon_clip_store.py search-data; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    for file in dragon-search dragon-usage dragon-clip dragon-clip-store; do
        deploy_item "$REPO_DIR/bin/$file" "$HOME/.local/bin/$file"
    done
}
