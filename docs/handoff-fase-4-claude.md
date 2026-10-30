# Fase 4 · Claude Code: launcher «Gravedad», Alt+Tab orbital, escritorios y portapapeles orbital

Rama `feat/nueva-identidad`. Prompt: `docs/design/PROMPT-identidad-fase-4-claude.md`. Referencias: `docs/design/02-launcher.png`, `03-busqueda.png`, `10-alttab.png`, `11-escritorios.png`, `12-portapapeles.png` (no estaban en el repo al empezar; el usuario las copió y van en `fa7c92b`). Capturas: `docs/screenshots/identidad/gravedad-*.png`.

## Hecho

| Punto | Commit | Qué |
|---|---|---|
| — | `fa7c92b` | Referencias y prompts de la fase |
| 1 | `b9c2204` | Launcher Gravedad en reposo (`GravityView`, `GravityPlanet`, `services/Usage.qml`, Ajustes › Launcher) |
| 2 | `0c85d77` | Búsqueda: atracción, fantasmas, MODOS, RESULTADOS, lunas de terminal (`services/Search.qml`, `GravityModes`, `GravityResults`) |
| 3 | `a86a7cf` | Alt+Tab orbital (`modules/switcher/`, `services/Switcher.qml`, MRU en `Hypr`) |
| 4 | `e5ab982` | Vista general de escritorios, SUPER+Tab (`modules/overview/`, `services/Overview.qml`, `WorkspacePreview.layout`) |
| 5 | `b69afa4` | Portapapeles orbital, modo `/` y SUPER+V (`ClipOrbit`, `ClipCard`, `Clipboard` ampliado) |
| 6 | `7c9cd9d` | Migraciones 025 y 026, `KEYBINDS.md`, `panelGroups`, tabla de la skill |
| — | `15d24de` | `tests/migrations-fase4.sh` (dentro de `tests/run-all.sh`) |

**Contrato con Codex.** Los servicios llaman a `~/.local/bin/dragon-search`, `dragon-usage` y `dragon-clip` por ruta completa, con `--json`, y comprueban `[ -x ]` antes: si falta el comando no sale nada en el registro.
- `dragon-search`: 80 ms tras la última tecla; `Process.exec()` sustituye la llamada en curso y se descarta la respuesta de una consulta vieja. Sin el comando, `=` usa `Apps.calc` y los demás modos muestran «Falta dragon-search».
- `dragon-usage stats`: al abrir el launcher. `record`: al lanzar.
- `dragon-clip classify`: las 200 entradas más recientes, pasadas por stdin. `pins list|add|remove`, `meta <id>`.
- Sin `dragon-clip`, `Clipboard.qml` clasifica por su cuenta con los mismos `kind` y enmascara igual.
- `dragon-usage` y `dragon-search` provisionales (datos de prueba con el esquema): están en `~/.local/bin`, **fuera del repo**. La migración 032 de Codex los sustituye.
- `dragon-clip-store`: Codex aún no lo entregó, así que **no hay migración 027**. `autostart.lua` sigue con el `dragon-clip-store` de la fase 2 (pausa del modo grabación). Cuando llegue el de Codex debe conservar esa pausa o la línea del vigilante tendrá que encadenar los dos.

## Comprobaciones del §7 (sesión real, 1366 × 768)

1. **Reposo:** tres anillos, giro lento, tamaño por `frecency` y lunas en las apps abiertas, en captura. ← → lleva la elegida al frente, ↓ cambia de anillo (registro temporal + capturas).
2. **Búsqueda:** «te» y «term» atraen las coincidencias y el resto pasa a fantasmas. `=`, `>`, `?`, `:`, `@` y `/` encienden su chip y su panel. Enter en `=2+3` copió «5» y cerró (la entrada se borró del historial después).
3. **Alt+Tab** por IPC: el anillo se abre, `next` gira y `cancel` cierra. Toque rápido (`next` + `confirm` seguidos): cambió a la ventana anterior **sin mapear** `dragon-switcher`. `switcherOrbital` apagado deja 0 atajos de Alt+Tab; encendido, 3.
4. **SUPER+Tab:** cinco tarjetas con ventanas en proporción, la actual marcada, ← elige, vista previa con capturas reales de otro escritorio, Esc cierra.
5. **SUPER+V:** se abre el anillo. Enter **pegó de verdad**: un kitty de prueba con `cat` recibió el texto (Ctrl+Shift+V por ser terminal). Ventana cerrada e historial limpio después.
6. **Interruptores apagados:** `launcherGravity false` → el launcher orbital anterior, intacto; SUPER+V → el `ClipboardPanel` anterior; `switcherOrbital false` → Alt+Tab libre.
7. **Sin `dragon-search`, `dragon-usage` ni `dragon-clip`** (renombrados): el launcher abre, busca apps y calcula sin una línea en el registro.
8. **CPU de Quickshell en reposo:** 12,2 %, igual que antes de la fase. Cerrado no queda ningún temporizador de la fase (el giro es un `Timer` que solo corre con la vista abierta).
   Abierto: 78 %, frente al 92 % del launcher anterior; el núcleo de 553 px a 60 Hz era casi todo el coste. Ahora el núcleo y el giro van juntos a 30 fps (`Theme.gravityFps`).
9. `tests/run-all.sh` en verde: shellcheck, luac, qmllint, idempotencia, migraciones nuevas. `hyprctl configerrors` vacío.

## No verificado (necesita teclado o ratón físicos)

- **Soltar Alt de verdad.** El atajo `ALT + Alt_L` con `release = true, transparent = true` está cargado (`hyprctl binds` lo lista con `release=true`). La ventana también confirma con su propio `Keys.onReleased`. Pero `send_shortcut` no genera la liberación de un modificador, así que no pude probar la secuencia real Alt↓ Tab Tab Alt↑.
- **Arrastrar** una ventana entre tarjetas de escritorios (no hay ratón virtual). `Hypr.moveWindowSilent` usa el dispatcher documentado (`window.move{window, workspace, follow = false}`), pero no se ejecutó.
- **Clics y rueda:** clic en planetas, chips, tarjetas y filas; clic central; rueda sobre «Todas» y los anillos. Son las mismas funciones que se probaron por teclado e IPC.
- Lunas de terminal con dos ventanas de Ghostty reales (solo había una); `Ctrl+P` (fijar) y `Supr` (borrar) en el portapapeles; un segundo monitor.

## Desviaciones y decisiones

- **SUPER+V:** antes alternaba la ventana flotante. Por decisión del usuario, flotante pasa a **SUPER+SHIFT+Space** y SUPER+SHIFT+V queda como alias del portapapeles.
- **Favoritos:** los del launcher (`Apps.favorites`, vacío aquí) más los fijados del dock (`Dock.pinnedIds`).
- **MODOS** se ve siempre que hay texto, como en `03-busqueda.png`, no solo con un prefijo. `?` con el campo vacío es a la vez el prefijo web y la forma de ver los modos.
- **Coincidencias:** solo cuentan las reales (texto dentro del nombre o del nombre genérico, o palabra clave que empieza así). Las difusas quedan de reserva: «te» daba «60 de 79».
- **Números de RESULTADOS** (2, 3…): solo indican la posición, no son un atajo.
- **Giro a 30 fps** con un `Timer` compartido con el núcleo, en vez de `FrameAnimation`: a 60 Hz el launcher gastaba un 119 % de CPU.
- **Portapapeles en anillo:** 8 tarjetas a la vez (con 12 se amontonaban); el resto gira con ← →. El recuento de caracteres sale de la vista previa de `cliphist list`, que corta en unos 100.
- **Alt+Tab:** «activa hace X» solo existe para ventanas enfocadas desde que arrancó Quickshell (antes solo hay `focusHistoryID`, sin hora). «Por app» = la ventana más reciente de cada app.
- **Conflicto conocido:** `kb_options` cambia de distribución con **Alt+Shift**, así que **Alt+Shift+Tab** (anterior) también cambia de US a LA. No hay solución limpia sin tocar `kb_options`; lo decide el usuario.
- Capturas de Alt+Tab, escritorios y portapapeles **no subidas**: muestran ventanas e historial reales del usuario.

## Trampas

- Una propiedad del delegado con el mismo nombre que el `id` del padre (`view: view`, `orbit: orbit`, `win: …`) se resuelve a sí misma y da `undefined`. Las propiedades se llaman `host`, `ring` e `item`.
- En `onShownChanged`, una propiedad enlazada a `shown` (`entries` vía `active`) aún tiene el valor viejo: `reset()` va con `Qt.callLater`.
- `console` no vale como nombre de propiedad en un singleton (`Icons.terminal`).
- `CoreIcon` no tiene «search» (el launcher anterior tampoco pintaba la lupa): se usa `Glyph` con `Icons.search`.
- `send_shortcut` con `key = "asterisk"` no teclea `*`; para `@`, `?`, `:` y `>` hay que mandar la tecla con `SHIFT`.

## Revertir

`git revert` de los commits de la tabla. Con `launcherGravity` y `switcherOrbital` a `false` en Ajustes vuelve el comportamiento anterior sin revertir nada, salvo SUPER+V y la tecla de flotante.
