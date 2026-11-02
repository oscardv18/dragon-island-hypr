#!/usr/bin/env bash
# dragon-island — every check that needs no root and no real installation. Usage: tests/run-all.sh [--no-qml]
#   lint of every script (the shellcheck tool + bash -n) · Lua syntax · qmllint · pre-instalation.md coherence · shared/ in sync ·
#   idempotency in a temp $HOME · every migration with DRY_RUN=1 leaves no trace · `install.sh --dry-run` leaves no trace.
# The container test (needs docker + sudo) is tests/container.sh.
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
fails=0
step() { printf '\n== %s ==\n' "$1"; }
pass() { echo "✔ $*"; }
fail() {
  echo "✘ $*"
  fails=$((fails + 1))
}

step "shellcheck -x + bash -n"
mapfile -t SH < <({
  git ls-files '*.sh' 'bin/*'
  ls tests/*.sh
} | sort -u)
if command -v shellcheck >/dev/null; then
  if shellcheck -x "${SH[@]}"; then pass "shellcheck limpio en ${#SH[@]} scripts"; else fail "shellcheck encontró avisos"; fi
else fail "shellcheck no está instalado (sudo pacman -S shellcheck)"; fi
bad=0
for f in "${SH[@]}"; do bash -n "$f" || {
  echo "bash -n: $f"
  bad=1
}; done
if ((bad == 0)); then pass "bash -n correcto"; else fail "bash -n falla"; fi

step "Lua (sintaxis)"
if command -v luac >/dev/null; then
  bad=0
  for f in config/hypr/*.lua; do luac -p "$f" || bad=1; done
  if ((bad == 0)); then pass "luac -p en config/hypr/*.lua"; else fail "error de sintaxis Lua"; fi
else echo "- luac no está: se omite"; fi

if [[ "${1:-}" != "--no-qml" ]]; then
  step "qmllint (archivos del lanzador, núcleo y bloqueo)"
  if command -v qmllint >/dev/null; then
    mapfile -t QML < <(ls config/quickshell/modules/launcher/*.qml config/quickshell/components/NeuralCore.qml config/quickshell/components/CoreIcon.qml config/quickshell/modules/lock/*.qml 2>/dev/null)
    errs="$(qmllint -I config/quickshell "${QML[@]}" 2>&1 | grep -ci '^Error' || true)"
    if [[ "$errs" == 0 ]]; then pass "qmllint sin errores en ${#QML[@]} archivos"; else fail "qmllint: $errs errores (qmllint -I config/quickshell <archivo>)"; fi
  else echo "- qmllint no está: se omite"; fi
fi

step "paleta: extracción, plantillas, apps y migraciones (HOME temporal)"
if python3 -m unittest discover -s tests/palette -v; then pass "pruebas de paleta"; else fail "pruebas de paleta fallaron"; fi

step "migraciones de la fase 4 (HOME temporal)"
if bash tests/migrations-fase4.sh; then pass "migraciones 025, 026, 027 y 028"; else fail "migraciones 025 / 026 / 027 / 028"; fi

step "migraciones del ajuste de ventanas (HOME temporal)"
if bash tests/migrations-ventanas.sh; then pass "migraciones del ajuste de ventanas"; else fail "migraciones del ajuste de ventanas"; fi

step "contorno de ventanas: framewatch.lua, borde nativo y tokens (sin sesión)"
if bash tests/window-frame.sh; then pass "contorno de ventanas"; else fail "contorno de ventanas"; fi

step "migraciones en simulación: DRY_RUN=1 y DRY_RUN=true no cambian nada (HOME temporal)"
if bash tests/migrations-dry-run.sh; then pass "todas las migraciones, dragon-sddm-sync y dragon-palette"; else fail "alguna migración escribe en dry-run"; fi

step "dragon-sddm-sync: fondo 1920×1080 desenfocado una vez con magick o ffmpeg (tema temporal)"
if bash tests/sddm-sync.sh; then pass "fondo del login desenfocado una sola vez y sin MultiEffect"; else fail "dragon-sddm-sync prepara mal el fondo"; fi

# fase5c: tools
step "compositor determinista con destinos simulados (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/prompt -v; then pass "dragon-prompt"; else fail "dragon-prompt"; fi
step "puertas de pruebas: límites, cancelación y eventos (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/gate -v; then pass "dragon-gate"; else fail "dragon-gate"; fi
step "consumo diario con registros sintéticos (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/tokens -v; then pass "dragon-tokens"; else fail "dragon-tokens"; fi
# /fase5c: tools

# fase5c: adjustments
step "ajustes de 5c: migración de pantallas y aislamiento de dry-run"
if python3 -m unittest discover -s tests/fase5c_ajustes -v; then pass "ajustes de 5c"; else fail "ajustes de 5c"; fi
# /fase5c: adjustments

# fase5b: engines
step "Docker con socket Unix falso"
if python3 -m unittest discover -s tests/docker -v; then pass "dragon-docker"; else fail "dragon-docker"; fi
step "Git con repositorios temporales"
if python3 -m unittest discover -s tests/git -v; then pass "dragon-git"; else fail "dragon-git"; fi
step "servicios Docker y Git con Quickshell real y HOME temporal"
if python3 -m unittest discover -s tests/fase5b -v; then pass "servicios de 5b"; else fail "servicios de 5b"; fi
if python3 tests/fase5b/bench.py --limit-ms 300; then pass "lecturas frías <300 ms"; else fail "latencia de 5b"; fi
# /fase5b: engines

# fase5c: pantallas
step "Taller 5c: servicios Prompts/Gate y vistas con herramientas simuladas (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/fase5c -v; then pass "pantallas y servicios de 5c"; else fail "pantallas y servicios de 5c"; fi
# /fase5c: pantallas

# fase5e: pulido
step "Taller 5e: CONTEXT.md se exporta solo al cambiar de tarjeta (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/fase5e -v; then pass "exportación automática de contexto"; else fail "exportación automática de contexto"; fi
# /fase5e: pulido

# fase5a: shared secrets
step "secretos compartidos"
if python3 -m unittest discover -s tests/secrets -v; then pass "filtro compartido"; else fail "filtro compartido"; fi
# /fase5a: shared secrets

# fase5a: memory
step "memoria SQLite del Taller (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/mem -v; then pass "dragon-mem"; else fail "dragon-mem"; fi
# /fase5a: memory

# fase5a: herdr
step "puente de herdr con socket falso (HOME/XDG temporales)"
if python3 -m unittest discover -s tests/herdr -v; then pass "dragon-herdr"; else fail "dragon-herdr"; fi
# /fase5a: herdr

# fase5a: services and UI
step "servicios del Taller con Quickshell real y HOME temporal"
if python3 -m unittest discover -s tests/taller -v; then pass "servicios del Taller"; else fail "servicios del Taller"; fi
# /fase5a: services and UI

step "motores: búsqueda, uso y portapapeles (HOME/XDG temporales)"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/engines -v; then pass "pruebas de motores"; else fail "pruebas de motores fallaron"; fi

step "imágenes de docs: máximo 1,5 MB y herramientas (HOME/XDG temporales)"
if bash tests/check-images.sh && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/images -v; then pass "imágenes y herramientas"; else fail "imágenes o herramientas fallaron"; fi

step "actividad: solapes, concurrencia, privacidad, retención y migración (HOME/XDG temporales)"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/activity -v; then pass "registro de actividad"; else fail "pruebas de actividad fallaron"; fi

step "sesión Hyprland: terminal antigua, plugins y recarga (HOME temporal)"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/session -v; then pass "sesión Hyprland y actualización"; else fail "sesión Hyprland y actualización"; fi

step "mosaico: selectores numéricos, con nombre y especiales (HOME temporal)"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/tiling -v; then pass "modos de mosaico"; else fail "modos de mosaico"; fi

step "pre-instalation.md ↔ código"
if tests/check-docs.sh; then pass "documentación coherente"; else fail "check-docs.sh falló"; fi

step "shared/ sincronizado"
if scripts/sync-shared.sh --check; then pass "NeuralCore/CoreIcon idénticos en Quickshell y SDDM"; else fail "copias desincronizadas (scripts/sync-shared.sh)"; fi

step "idempotencia en un \$HOME temporal"
if tests/idempotency.sh; then pass "idempotente"; else fail "idempotency.sh falló"; fi

step "install.sh --dry-run no deja rastro (HOME/XDG temporales)"
if python3 tests/install-dry-run.py; then pass "instalador sin escrituras en HOME/XDG ni cambios en git"; else fail "el dry-run dejó rastro o falló"; fi

echo
if ((fails == 0)); then echo "TODO EN VERDE"; else echo "$fails bloque(s) fallan"; fi
exit "$fails"
