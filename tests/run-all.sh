#!/usr/bin/env bash
# dragon-island — every check that needs no root and no real installation. Usage: tests/run-all.sh [--no-qml]
#   lint of every script (the shellcheck tool + bash -n) · Lua syntax · qmllint · pre-instalation.md coherence · shared/ in sync ·
#   idempotency in a temp $HOME · `install.sh --dry-run` leaves no trace.
# The container test (needs docker + sudo) is tests/container.sh.
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
fails=0
step() { printf '\n== %s ==\n' "$1"; }
pass() { echo "✔ $*"; }
fail() { echo "✘ $*"; fails=$((fails + 1)); }

step "shellcheck -x + bash -n"
mapfile -t SH < <({ git ls-files '*.sh' 'bin/*'; ls tests/*.sh; } | sort -u)
if command -v shellcheck >/dev/null; then
    if shellcheck -x "${SH[@]}"; then pass "shellcheck limpio en ${#SH[@]} scripts"; else fail "shellcheck encontró avisos"; fi
else fail "shellcheck no está instalado (sudo pacman -S shellcheck)"; fi
bad=0; for f in "${SH[@]}"; do bash -n "$f" || { echo "bash -n: $f"; bad=1; }; done
if (( bad == 0 )); then pass "bash -n correcto"; else fail "bash -n falla"; fi

step "Lua (sintaxis)"
if command -v luac >/dev/null; then
    bad=0; for f in config/hypr/*.lua; do luac -p "$f" || bad=1; done
    if (( bad == 0 )); then pass "luac -p en config/hypr/*.lua"; else fail "error de sintaxis Lua"; fi
else echo "- luac no está: se omite"; fi

if [[ "${1:-}" != "--no-qml" ]]; then
    step "qmllint (archivos del lanzador, núcleo y bloqueo)"
    if command -v qmllint >/dev/null; then
        mapfile -t QML < <(ls config/quickshell/modules/launcher/*.qml config/quickshell/components/NeuralCore.qml config/quickshell/components/CoreIcon.qml config/quickshell/modules/lock/*.qml 2>/dev/null)
        errs="$(qmllint -I config/quickshell "${QML[@]}" 2>&1 | grep -ci '^Error' || true)"
        if [[ "$errs" == 0 ]]; then pass "qmllint sin errores en ${#QML[@]} archivos"; else fail "qmllint: $errs errores (qmllint -I config/quickshell <archivo>)"; fi
    else echo "- qmllint no está: se omite"; fi
fi

step "pre-instalation.md ↔ código"
if tests/check-docs.sh; then pass "documentación coherente"; else fail "check-docs.sh falló"; fi

step "shared/ sincronizado"
if scripts/sync-shared.sh --check; then pass "NeuralCore/CoreIcon idénticos en Quickshell y SDDM"; else fail "copias desincronizadas (scripts/sync-shared.sh)"; fi

step "idempotencia en un \$HOME temporal"
if tests/idempotency.sh; then pass "idempotente"; else fail "idempotency.sh falló"; fi

step "install.sh --dry-run no deja rastro"
before="$(git status --porcelain)"
marker="$(mktemp)"; sleep 1
if ./install.sh --dry-run --yes --modules core,shell,theme,plugins,keyboard,extras,keyring,login --extras brave,protonvpn,herdr >/dev/null 2>&1; then pass "el dry-run completo termina bien"; else fail "el dry-run falló"; fi
after="$(git status --porcelain)"
touched="$(find "$HOME/.config/hypr" "$HOME/.config/dragon-island" "$HOME/.local/state/dragon-island" "$HOME/.zshrc" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" -newer "$marker" -type f 2>/dev/null | grep -v '\.log$\|launcher.json\|dock.json\|wallpaper.json\|pkg-status.json\|pkg.log' || true)"
rm -f "$marker"
if [[ "$before" == "$after" && -z "$touched" ]]; then pass "git status idéntico y ningún archivo de configuración tocado"; else fail "el dry-run dejó rastro: ${touched:-$(diff <(echo "$before") <(echo "$after"))}"; fi

echo
if (( fails == 0 )); then echo "TODO EN VERDE"; else echo "$fails bloque(s) fallan"; fi
exit "$fails"
