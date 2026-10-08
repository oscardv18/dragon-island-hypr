#!/usr/bin/env bash
# dragon-island — idempotency: apply the modules twice in a throw-away $HOME and compare the result.
# Safe by construction: HOME and XDG_* point to a temp dir, NO_SUDO=true, and shims on PATH replace everything that
# would reach the real system (sudo, systemctl, gsettings, chsh, localectl, hyprctl, hyprpm). Network-free: the zsh
# plugin directories are pre-created so nothing is cloned. Checks: same file tree + link targets after run 2, exactly
# one marker block in ~/.zshrc, the user's own .zshrc lines intact, a backup created for the pre-existing file.
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TESTHOME="$(mktemp -d)"
SHIMS="$(mktemp -d)"
trap 'rm -rf "$TESTHOME" "$SHIMS"' EXIT

for c in sudo systemctl gsettings chsh localectl hyprctl hyprpm busctl; do
    printf '#!/usr/bin/env bash\necho "[shim:%s] $*" >> "%s/shim.log"\nexit 0\n' "$c" "$SHIMS" > "$SHIMS/$c"
    chmod +x "$SHIMS/$c"
done
printf '#!/usr/bin/env bash\necho "[shim:sudo] $*" >> "%s/shim.log"\nexit 1\n' "$SHIMS" > "$SHIMS/sudo"

# user data that must survive: an existing .zshrc and an existing gtk-4.0 settings.ini
mkdir -p "$TESTHOME/.config/gtk-4.0" "$TESTHOME/.local/share/dragon-island/zsh-plugins"
printf 'export MY_OWN_LINE=1\nalias ll="ls -la"\n' > "$TESTHOME/.zshrc"
printf '[Settings]\ngtk-theme-name=mine\n' > "$TESTHOME/.config/gtk-4.0/settings.ini"
for p in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do mkdir -p "$TESTHOME/.local/share/dragon-island/zsh-plugins/$p"; done

apply_all() {
    # shellcheck disable=SC2016  # the script is deliberately single-quoted: it expands inside the child shell
    env -i HOME="$TESTHOME" PATH="$SHIMS:/usr/bin:/bin" USER="$USER" LANG=C \
        REPO_DIR="$REPO_DIR" DRAGON_EXTRAS=protonvpn,brave DRAGON_KB_LAYOUTS=us,latam,es \
        bash -c '
        set -Eeuo pipefail
        PROJECT=dragon-island
        STATE_DIR="$HOME/.local/state/$PROJECT"; MANIFEST="$STATE_DIR/manifest"; BACKUP_DIR="$STATE_DIR/backups/test"
        LOG=/dev/null; DRY_RUN=false; ASSUME_YES=true; NO_SUDO=true; LINK_MODE=symlink
        mkdir -p "$STATE_DIR"
        . "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/lib/detect.sh"
        for m in "$REPO_DIR"/modules/*.sh; do . "$m"; done
        AUR_HELPER=""
        # ~/.config/hypr is a link to the repo: keep the override file out of it (a running Hyprland would reload it)
        HYPR_LOCAL="$HOME/hypr-local-test.lua"
        for m in core shell theme plugins keyboard keyring extras; do "${m}_apply" >/dev/null 2>&1 || true; done
    '
}

snapshot() {
    ( cd "$TESTHOME" && find . \( -path ./.local/state/dragon-island/backups -o -path ./.local/state/dragon-island/manifest \) -prune -o \
        -printf '%p %y %l\n' | sort
      cd "$TESTHOME" && find . -type f -not -path './.local/state/*' -not -type l -exec md5sum {} + | sort )
}

fails=0
# expect <label> <command...>: ✔ when the command succeeds
expect() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then echo "✔ $label"; else echo "✘ $label"; fails=$((fails + 1)); fi; }

apply_all; snap1="$(snapshot)"
apply_all; snap2="$(snapshot)"
if [[ "$snap1" == "$snap2" ]]; then echo "✔ la segunda ejecución no cambia nada (árbol y enlaces idénticos)"
else echo "✘ la segunda ejecución cambió algo:"; fails=$((fails + 1)); diff <(echo "$snap1") <(echo "$snap2") | head -20; fi

zshrc="$TESTHOME/.zshrc"
expect "el ~/.zshrc tiene exactamente un bloque marcado" test "$(grep -c '>>> dragon-island:zsh' "$zshrc")" = 1
expect "las líneas propias del .zshrc siguen intactas" grep -q 'MY_OWN_LINE=1' "$zshrc"
expect "el alias propio del .zshrc sigue intacto" grep -q 'alias ll=' "$zshrc"
expect "el settings.ini existente se respaldó antes de enlazar" find "$TESTHOME/.local/state/dragon-island/backups" -path '*gtk-4.0/settings.ini'
expect "gtk-4.0/settings.ini ahora es un enlace" test -L "$TESTHOME/.config/gtk-4.0/settings.ini"
expect "local.conf tiene una sola línea KB_LAYOUTS" test "$(grep -c '^KB_LAYOUTS=' "$TESTHOME/.config/dragon-island/local.conf")" = 1
expect "el override de teclado tiene un solo bloque (apertura + cierre)" test "$(grep -c 'dragon-island:keyboard' "$TESTHOME/hypr-local-test.lua")" = 2
expect "nada se escribió en config/hypr del repo" test ! -e "$REPO_DIR/config/hypr/local.lua"
exit "$fails"
