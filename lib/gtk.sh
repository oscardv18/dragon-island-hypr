#!/usr/bin/env bash
# User settings only; caller supplies common.sh and REPO_DIR.
gtk_setup() {
    GTK_CHANGED="${GTK_CHANGED:-false}"
    [[ -z "$(python3 "$REPO_DIR/scripts/gtk-setup.py" --dry-run)" ]] || GTK_CHANGED=true
    local targets target
    targets="$(mktemp)"
    if ! python3 "$REPO_DIR/scripts/gtk-setup.py" --backups > "$targets"; then
        rm -f "$targets"
        return 1
    fi
    while IFS= read -r -d '' target; do backup_copy "$target"; done < "$targets"
    rm -f "$targets"
    if $DRY_RUN; then
        python3 "$REPO_DIR/scripts/gtk-setup.py" --dry-run
    else
        python3 "$REPO_DIR/scripts/gtk-setup.py"
    fi
    if command -v gsettings >/dev/null 2>&1; then
        local key value old
        for key in color-scheme gtk-theme; do
            value=prefer-dark
            [[ "$key" == gtk-theme ]] && value=adw-gtk3-dark
            # Even a dconf read can create $XDG_RUNTIME_DIR/dconf/user.
            if $DRY_RUN; then
                run gsettings set org.gnome.desktop.interface "$key" "$value"
                continue
            fi
            if ! old="$(gsettings get org.gnome.desktop.interface "$key")"; then
                log_warn "No se puede leer dconf ($key); aplicar desde la sesión gráfica."
                continue
            fi
            [[ "$old" == "'$value'" ]] && continue
            GTK_CHANGED=true
            target="${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island/gtk-before-$key"
            if [[ ! -e "$target" ]]; then
                run mkdir -p "$(dirname "$target")"
                if ! $DRY_RUN; then printf '%s\n' "$old" > "$target"; fi
            fi
            run gsettings set org.gnome.desktop.interface "$key" "$value"
        done
    fi
}
