#!/usr/bin/env bash
# Caller provides common.sh, REPO_DIR and migration/install flags.
telegram_portal_setup() {
    [[ -f /usr/share/applications/org.telegram.desktop.desktop || -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.telegram.desktop.desktop" ]] || return 0
    local runner paths target temporary changed=false
    runner="$HOME/.local/bin/dragon-telegram"
    # Keep the tiny runner as a copy so it does not depend on the worktree's lifetime.
    if [[ ! -f "$runner" ]] || ! cmp -s "$REPO_DIR/scripts/telegram-portal.sh" "$runner"; then
        changed=true
        backup_copy "$runner"
        run mkdir -p "$(dirname "$runner")"
        if $DRY_RUN; then
            log_info "[dry-run] Instalar $runner"
        else
            temporary="$(mktemp "$(dirname "$runner")/.telegram-XXXXXX")"
            cp "$REPO_DIR/scripts/telegram-portal.sh" "$temporary"
            chmod 755 "$temporary"
            mv -T "$temporary" "$runner"
        fi
    fi
    [[ -z "$(python3 "$REPO_DIR/scripts/telegram-portal-setup.py" --dry-run)" ]] || changed=true
    paths="$(mktemp)"
    python3 "$REPO_DIR/scripts/telegram-portal-setup.py" --backups > "$paths"
    while IFS= read -r -d '' target; do backup_copy "$target"; done < "$paths"
    rm -f "$paths"
    if $DRY_RUN; then
        python3 "$REPO_DIR/scripts/telegram-portal-setup.py" --dry-run
    else
        python3 "$REPO_DIR/scripts/telegram-portal-setup.py"
    fi
    if $changed && command -v update-desktop-database >/dev/null 2>&1; then
        run update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    fi
}
