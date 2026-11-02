# Fase 5c · Ajustes › Taller (UI)

Rama `feat/fase5c-ajustes-ui`, desde `feat/fase5c-pantallas`. 2026-11-01. Punto 10 del plan.
Solo Quickshell: no se tocó ningún `dragon-*` ni `migrations/`.

## Qué hay

- **Página «Taller»** en Ajustes (`SUPER + F2`, o `qs ipc call settings page taller`):
  - **Prompts**:
    - «Ámbar desde» y «Rojo desde», en pasos de 250 y con la escala resultante debajo.
    - «Guardar historial de prompts», apagado por defecto.
  - **Proyecto**, el mismo seleccionado en el Taller (‹ › lo cambia en los dos sitios):
    - «Límite WIP» (1–20, por defecto 3).
    - «Comando de pruebas» (Enter guarda).
    - «Contexto para agentes» → «Exportar ahora».
- **Servicios**:
  - `Settings`: `tokenWarnAt`/`tokenHighAt` (siempre rojo ≥ ámbar + 250), `setTokenThresholds` y `promptHistory`.
  - `Prompts.warnAt/highAt` se enlazan con esos umbrales.
  - `Mem.setProject` y `Mem.exportContext`: los errores van solo a quien llama, para que un valor rechazado no deje el Taller en error.
  - Cada envío (también en «Iniciar») pasa ahora `--project`, `--card` y `--template`, para que el `prompt_run` quede atribuido.
- `fix(revision)`: un refresco antiguo ya no deshace la marca de «visto». La prueba `ReviewFlow` fallaba 1 de cada 5 veces.

## Contratos usados (ya existen)

- `settings.json` → `promptHistory` (lo lee `dragon-prompt`). Los umbrales también van en `settings.json`, pero solo los usa la UI.
- `dragon-mem project set <slug> --wip-limit N --test-cmd …` y `dragon-mem export --project <slug>` → `{path, bytes}`.
- `dragon-prompt send … [--project] [--card] [--template]`, de la rama de herramientas.

## Decisiones

- **«WIP por defecto» es el WIP de cada proyecto.** `dragon-mem` no tiene un WIP global, y `project add` siempre crea el proyecto con 3.
- **Exportar es solo manual.** La exportación automática al cambiar de tarjeta o de decisión es el punto 8 y sigue pendiente.
- **Sin presupuesto diario de tokens (§5.6).** No se pidió; cabe en esta misma página.

## Verificación

- `tests/fase5c/` pasa entera (13 pruebas, tres veces seguidas):
  - `test_settings.py` usa Quickshell real, `dragon-mem` real y HOME aislado:
    - umbrales y historial en `settings.json`;
    - WIP inválido rechazado sin cambiar `Mem.status`;
    - WIP y comando guardados;
    - `CONTEXT.md` con modo 600 y menos de 4 KB;
    - un envío con los tres argumentos de atribución;
    - la página dentro del `SettingsPanel` real, que no lee `dragon-mem` hasta que se muestra.
  - `test_views.py` incluye el mock `settings_taller_mock.qml`.
- `tests/taller/test_settings_log.py` en verde y qmllint sin errores en los archivos tocados.
- **Wayland real**: abrí una instancia temporal de `qs` desde esta rama, con HOME aislado y dos proyectos de prueba, que se cerró sola. No se tocaron el Quickshell del usuario, sus datos ni ninguna terminal; no se usó vin.py.
  - Captura: `docs/screenshots/fase5c/ajustes-taller-wayland.png`.
  - Al encoger la tarjeta, el campo de comando ahora cede espacio al título.
- Renders con datos de muestra: `ajustes-taller.png`, `-editado.png` y `-vacio.png`.

## Qué debe ver el usuario

1. Ajustes → «Taller» en la barra lateral, con el icono del robot.
2. Al cambiar «Ámbar desde» se mueve la marca en la escala, y el contador del compositor (`P` en el Taller) cambia de color con los nuevos umbrales.
3. «Guardar historial de prompts» viene apagado y su texto dice que solo se guardan tokens, fecha, destino y huella.
4. Con un proyecto: WIP y comando guardados al momento. Pasado el nuevo WIP, el Kanban pide confirmación. «Exportar ahora» muestra `.dragon/CONTEXT.md · N KB · hora`.
5. Sin proyectos aparece un aviso que remite al selector del Taller.

## Pendiente

- La migración que despliegue `TallerSettingsPage.qml` y los cambios de servicios. Va con la migración de 5c para instalaciones por copia (rango 057–060).
- Probar contra el `dragon-prompt` real al fusionar `feat/fase5c-herramientas`. Su `send` ya declara `--project`, `--card` y `--template` (visto en el código), pero aquí solo se ejecutó el falso.
