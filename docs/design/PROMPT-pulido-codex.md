# dragon-island — Fase de pulido (Codex): simulación sin rastro, pruebas de tiempo estables, repo más ligero y registro de actividad

Trabajas en la rama `feat/pulido-herramientas`, creada desde `main`, en su propio worktree. Claude Code trabaja en paralelo en `feat/pulido` sobre `config/`, `sddm/` y `shared/`: **no toques esas carpetas**.

Antes de empezar lee `AGENTS.md`, `.agents/skills/dragon-island/SKILL.md`, `migrations/README.md`, `lib/common.sh` y tus handoffs anteriores (`docs/handoff-fase-3-codex.md`, `docs/handoff-fase-4-codex.md`).

**Reglas:**
- Un commit por punto.
- Migraciones desde la `040` (la `034` a la `039` son de Claude Code).
- En `tests/run-all.sh`, añade tus pasos **justo después** del paso de motores. Claude Code añade los suyos antes del paso «pre-instalation.md ↔ código».
- **No borres ni edites** `docs/handoff-fase-*.md`: Claude Code los une en `HANDOFF.md` en esta misma fase. Tus notas van en el resumen final; Claude Code las pasará al HANDOFF.
- Pruebas con HOME y XDG temporales.

## 1. `update.sh --dry-run` no debe dejar rastro

Hoy `update.sh --dry-run` crea `~/.local/state/dragon-island/migrations.done` con `touch`. En simulación no debe crear, tocar ni borrar nada fuera de su salida por pantalla:
- revisa el resto de `update.sh` (registro, copias de seguridad, directorios de estado) por el mismo problema;
- amplía `tests/migrations-dry-run.sh` (o crea una prueba propia) que ejecute `update.sh --dry-run` en un HOME temporal y falle si aparece o cambia cualquier archivo.

## 2. Prueba de tiempo que falla a veces

`test_cli_modes_under_150ms` dio 151,5 ms dentro de la suite completa (con la máquina cargada) y pasa sola. Hazla estable sin esconder regresiones reales:
1. Dentro de la suite: una pasada de calentamiento, luego 7 ejecuciones por modo, y compara la **mediana** con un límite de 300 ms.
2. Mueve el objetivo real de 150 ms a una medición aparte, `tests/engines/bench.py`, que imprime mediana y p95 por modo y **no** forma parte de `run-all.sh`. Documenta cómo ejecutarla.
3. Ejecuta la suite completa 5 veces seguidas y confirma que no falla ninguna.

## 3. Repo más ligero

`.git` pesa 94 MB. `docs/design/` ocupa 78 MB (PNG de 2732×1536, ~5 MB cada uno) y `docs/screenshots/` 14 MB.

1. **`scripts/optimize-images.sh`:**
   - optimiza sin pérdida con `oxipng` (o `optipng` si falta);
   - con `--resize`, baja las referencias de diseño a 1366 px de ancho;
   - respeta `--dry-run` e informa el peso antes y después;
   - si falta la herramienta, lo dice y sale con un código distinto de 0.
2. Ejecútalo con `--resize` sobre `docs/design/*.png` y sin `--resize` sobre `docs/screenshots/`. Haz commit del resultado, comprobando que las imágenes se siguen viendo bien (abre dos o tres antes y después).
3. **`tests/check-images.sh`:** falla si una imagen de `docs/` pesa más de 1,5 MB, con un mensaje que sugiere el script anterior. Añádelo a `run-all.sh` (en tu sitio).
4. **No reescribas el historial de git.** El peso de las versiones antiguas seguirá en `.git`. Explica en tu resumen cuánto pesaría un clon nuevo y qué haría falta (por ejemplo, `git filter-repo`) si el usuario quisiera reducirlo. Es una decisión suya: no lo hagas.
5. Añade una nota corta en `docs/TESTING.md` o en `README.md`: exportar referencias a 1× y pasar el script antes de subir imágenes.

## 4. `dragon-activity`: registro de actividad para la isla

La isla de mando de Claude Code dibuja una franja de tiempo con las ejecuciones de agentes, los comandos largos y los bloques de enfoque. Tú construyes el registro; Claude Code solo lo llama. **El contrato es fijo**: si necesitas cambiarlo, avisa antes.

- `dragon-activity add --kind agent|command|focus --name "<texto>" --start <epoch> [--end <epoch>] [--status ok|fail|blocked]` imprime el `id` (cadena corta y única).
- `dragon-activity end <id> [--status ok|fail]` cierra una entrada abierta. Un `id` desconocido sale con código 1 y un mensaje.
- `dragon-activity range --from <epoch> --to <epoch> --json` devuelve `{"items":[{"id","kind","name","start","end","status"}]}`, ordenado por `start`; `end` es `null` si sigue abierta. Incluye las que se solapan con el rango, no solo las que empiezan dentro.

Requisitos:
1. Archivo JSONL en `~/.local/state/dragon-island/activity.jsonl`, con escritura bajo bloqueo y sin perder líneas con dos escrituras a la vez.
2. Retención de 30 días: compacta al escribir si el archivo supera 1 MB.
3. **Privacidad:** `--name` se guarda recortado a 80 caracteres y pasando el mismo filtro de secretos que usa `dragon-search cmd` (variables `*_KEY`, `*_TOKEN`, `Bearer`, URLs con credenciales). Si parece un secreto, se guarda solo el primer token (por ejemplo `curl`).
4. Entradas abiertas de más de 12 h se cierran solas con `status: "unknown"` al leer.
5. `range` responde en menos de 50 ms con 30 días de datos.
6. Pruebas en `tests/activity/`: solapes, concurrencia, retención, filtro de secretos, `end` desconocido y entradas abiertas antiguas. Añádelas a `run-all.sh` en tu sitio.
7. Migración `040-activity-install.sh` para desplegarlo, idempotente y con `DRY_RUN`.

## 5. Comprobaciones antes de terminar

1. `update.sh --dry-run` deja el HOME temporal idéntico.
2. La suite completa pasa 5 veces seguidas.
3. `docs/` pesa bastante menos, con la tabla de antes y después en tu resumen.
4. `shellcheck -x` limpio en los scripts nuevos.
5. `dragon-activity` cumple el contrato exacto y sus pruebas pasan.

Termina con un resumen corto: qué hiciste, cuánto se redujo el repo, y qué decisiones necesita el usuario.
