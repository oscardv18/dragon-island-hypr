#!/usr/bin/env bash
# Shared adapter deployment; does not start or stop the user's herdr server.
herdr_bridge_setup() {
    local data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/engines" file
    for file in secret_filter.py taller_common.py mem_schema.sql dragon_mem.py dragon_herdr.py; do
        deploy_item "$REPO_DIR/dragon-core/$file" "$data/$file"
    done
    deploy_item "$REPO_DIR/bin/dragon-herdr" "$HOME/.local/bin/dragon-herdr"
}

# herdr_app_setup: the Herdr desktop app (~/.config/herdr-app) looks like Dragon's Ghostty: the dragon-ghostty theme
# (Ghostty's background, text and ANSI colors) and Ghostty's font. settings.json belongs to the app and the person
# (zoom, sounds, their own font): only the keys of config/herdr-app/dragon-settings.json that are missing are added,
# never overwritten. Window transparency and blur come from Hyprland (opacity-herdr-app in config/hypr/rules.lua):
# the app's own window has no alpha. Returns 10 when the app has never run here (no ~/.config/herdr-app).
herdr_app_setup() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app" settings missing
    [[ -d "$dir" ]] || { log_info "herdr-app: la app de escritorio no se ha abierto aquí; nada que ajustar"; return 10; }
    deploy_item "$REPO_DIR/config/herdr-app/themes/dragon-ghostty.json" "$dir/themes/dragon-ghostty.json"
    settings="$dir/settings.json"
    missing="$(python3 -I - "$REPO_DIR/config/herdr-app/dragon-settings.json" "$settings" <<'PY'
import json, os, sys
ours = json.load(open(sys.argv[1], encoding="utf-8"))
mine = json.load(open(sys.argv[2], encoding="utf-8")) if os.path.exists(sys.argv[2]) else {}
print(" ".join(k for k in ours if k not in mine))
PY
)"
    if [[ -z "$missing" ]]; then
        log_info "herdr-app: settings.json ya tiene tema y fuente"
        return 0
    fi
    backup_copy "$settings"
    if ! $DRY_RUN; then
        python3 -I - "$REPO_DIR/config/herdr-app/dragon-settings.json" "$settings" <<'PY'
import json, os, sys
ours = json.load(open(sys.argv[1], encoding="utf-8"))
path = sys.argv[2]
mine = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
for key, value in ours.items():
    mine.setdefault(key, value)
tmp = path + ".dragon-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(mine, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
PY
    fi
    log_info "herdr-app: añadido a settings.json: $missing"
}
