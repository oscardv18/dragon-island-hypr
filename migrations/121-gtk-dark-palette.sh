#!/usr/bin/env bash
# 121 — Keep the provisional GTK chooser dark and following dragon-palette.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/gtk.sh
. "$REPO_DIR/lib/gtk.sh"
# Upgrade copied palette libraries/templates too; links already see the change.
GTK_CHANGED=false
source_dir="$REPO_DIR/dragon-core"
data="${XDG_DATA_HOME:-$HOME/.local/share}/dragon-island/palette"
if [[ -L "$data/palette-templates" ]] && [[ "$(readlink -f "$data/palette-templates")" != "$(readlink -f "$source_dir/palette-templates")" ]]; then
    backup_copy "$data/palette-templates"
    run rm -- "$data/palette-templates"
    run cp -a -- "$source_dir/palette-templates" "$data/palette-templates"
    GTK_CHANGED=true
fi
for file in palette_apps.py palette-templates/gtk.css; do
    target="$data/$file"
    [[ -f "$target" ]] && cmp -s "$source_dir/$file" "$target" && continue
    GTK_CHANGED=true
    if [[ -e "$target" || -L "$target" ]]; then backup_copy "$target"; fi
    # Atomic replacement avoids writing through an existing file symlink.
    if $DRY_RUN; then
        log_info "[dry-run] Actualizar $target"
    else
        mkdir -p "$(dirname "$target")"
        temporary="$(mktemp "$(dirname "$target")/.gtk-XXXXXX")"
        cp "$source_dir/$file" "$temporary"
        mv -T "$temporary" "$target"
    fi
done
# An existing linked runner must resolve this revision's library too, including
# verification from a separate worktree before merging into the installed repo.
runner="$HOME/.local/bin/dragon-palette"
if [[ -L "$runner" ]] && [[ "$(readlink -f "$runner")" != "$(readlink -f "$REPO_DIR/bin/dragon-palette")" ]]; then
    deploy_item "$REPO_DIR/bin/dragon-palette" "$runner"
fi
gtk_setup
if $GTK_CHANGED && command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet xdg-desktop-portal-gtk.service; then
    run systemctl --user restart xdg-desktop-portal-gtk.service
fi
if ! pacman -Q adw-gtk-theme >/dev/null 2>&1; then
    log_warn 'Falta adw-gtk-theme: instalar a mano según pre-instalation.md (sin sudo en esta migración).'
fi
