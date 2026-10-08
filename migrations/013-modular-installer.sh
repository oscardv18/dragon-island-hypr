#!/usr/bin/env bash
# 013 — modular installer: the plugin scripts installer/firstrun.sh and installer/glass.sh became one script,
# scripts/plugins-foreground.sh (plugins.pending marker). Re-points the old links in the state dir, turns a pending
# glass install into a pending plugins install, and translates the old component names (core shell plugins tools
# fonts services glass zsh myapps) to the new modules (core shell theme plugins login keyring keyboard extras).
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"

# 1. state-dir links (installs made with LINK_MODE=symlink point at the removed files)
for old in firstrun.sh glass.sh; do
    if [[ -L "$STATE_DIR/$old" || -e "$STATE_DIR/$old" ]]; then run rm -f -- "$STATE_DIR/$old"; fi
done
run chmod +x "$REPO_DIR/scripts/plugins-foreground.sh"
if [[ -f "$STATE_DIR/components" ]] && grep -qxE 'plugins|glass' "$STATE_DIR/components"; then
    deploy_item "$REPO_DIR/scripts/plugins-foreground.sh" "$STATE_DIR/plugins-foreground.sh"
fi

# 2. a glass install that had not happened yet is now a plugins install (hyprbars/hyprfocus were done by firstrun.done)
if [[ -f "$STATE_DIR/glass.pending" ]]; then
    $DRY_RUN || { touch "$STATE_DIR/plugins.pending"; rm -f "$STATE_DIR/glass.pending"; }
fi

# 3. components → modules (read by update.sh / uninstall.sh)
if [[ -f "$STATE_DIR/components" && ! -f "$STATE_DIR/modules" ]]; then
    if ! $DRY_RUN; then
        {
            echo core
            while read -r c; do
                case "$c" in
                    shell|services) echo core ;;
                    zsh) echo shell ;;
                    fonts) echo theme ;;
                    plugins|glass) echo plugins ;;
                    tools|myapps) echo extras ;;
                esac
            done < "$STATE_DIR/components"
        } | sort -u > "$STATE_DIR/modules"
    fi
    $DRY_RUN || log_info "Módulos: $(tr '\n' ' ' < "$STATE_DIR/modules")"
fi
exit 0
