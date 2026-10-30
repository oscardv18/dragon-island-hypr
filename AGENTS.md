# AGENTS.md — dragon-island

Este archivo es para cualquier agente de código (Codex, Claude Code u otro) que trabaje en este repositorio.

## Antes de tocar nada
1. Lee `.agents/skills/dragon-island/SKILL.md`. Son las reglas del proyecto y mandan sobre cualquier costumbre propia.
2. Lee `docs/HANDOFF.md`, al menos las secciones que afecten a lo que vas a tocar.
3. Si trabajas en una fase, lee su prompt en `docs/design/` y respeta el reparto de archivos que indica.

## Reglas que no se rompen
- **La UI nunca ejecuta comandos.** Todo pasa por servicios en `config/quickshell/services/`.
- **`Theme.qml` es la única fuente de colores, tamaños y duraciones.** Nada de valores sueltos en los módulos.
- **Una sola región de blur por ventana**, con máscara alfa. Las ventanas de la barra tienen tamaño constante.
- **En Hyprland con configuración Lua, `hyprctl keyword` no sirve.** Usa `hyprctl eval`.
- **Nunca ejecutes `pkill ghostty`** ni nada que cierre ventanas del usuario.
- Todo cambio que afecte a sistemas ya instalados lleva una migración en `migrations/`, idempotente y con copia de seguridad. Respeta `DRY_RUN` y `ASSUME_YES`.
- Un commit por punto del prompt. Los mensajes dicen qué y por qué.
- Si algo no es viable tal cual, **para y pregunta**. No lo resuelvas por tu cuenta cambiando el diseño.

## Trabajo en paralelo
- Cada agente trabaja en su propia rama y no toca los archivos del otro.
- Rangos de migraciones: el prompt de cada fase indica los números que puede usar cada agente.
- Las notas de cada agente van en `docs/handoff-fase-N-<agente>.md`. `docs/HANDOFF.md` lo actualiza una sola persona al final.

## Comprobar el trabajo
- Scripts de shell con `shellcheck`.
- Pruebas en `tests/`. Si añades lógica, añade su prueba.
- Para la interfaz, di qué debe ver el usuario en pantalla; no des por buena una pantalla que no has podido ver.
