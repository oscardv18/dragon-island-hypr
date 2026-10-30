# Nueva identidad de dragon-island — Fase 4 (Claude Code): launcher «Gravedad», Alt+Tab orbital, vista de escritorios y portapapeles orbital

Continúa en `feat/nueva-identidad`, sobre la Fase 3 ya fusionada. Esta fase se reparte:
- **Tú (Claude Code):** toda la interfaz y la integración con Hyprland, descritas abajo.
- **Codex:** los motores de búsqueda y de uso de apps (`bin/dragon-search`, `bin/dragon-usage`, `bin/dragon-clip`). Trabaja en la rama `feat/fase-4-motores`, en su propio worktree. **No toca `config/quickshell/` ni `config/hypr/`.** Tú no tocas `bin/`, `dragon-core/` ni sus pruebas.

Las mismas reglas de siempre:
- primero `AGENTS.md`, la skill `dragon-island` y `docs/HANDOFF.md`;
- un commit por punto numerado;
- nada de colores ni duraciones fuera de `Theme`;
- la UI nunca ejecuta comandos: todo pasa por servicios;
- si algo no es viable tal cual en Quickshell 0.3.1 / Hyprland 0.56.2, **para y pregunta**.

**Migraciones:** tú usas `025` a `029`. Codex usa `032` en adelante.
**Notas:** escríbelas en `docs/handoff-fase-4-claude.md`.

Referencias en `docs/design/`: `02-launcher.png`, `03-busqueda.png`, `10-alttab.png`, `11-escritorios.png`, `12-portapapeles.png`. Si el código y una referencia chocan, manda la referencia.

**Fuera de alcance:** módulo ágil, panel de desarrollo y los detalles pendientes del dock.

---

## El contrato con Codex (léelo antes de empezar)

Los tres comandos viven en `~/.local/bin/` (el `PATH` de Quickshell no los ve: usa la ruta completa). Siempre con `--json`. Tú los llamas desde servicios con `Process`, con retardo de 80 ms al teclear y cancelando la llamada anterior.

**`dragon-search <modo> "<consulta>" [--limit N] --json`**, modos `calc`, `cmd`, `web`, `emoji`:
```json
{
  "mode": "calc",
  "query": "20% de 350",
  "results": [
    {
      "id": "calc:1",
      "title": "70",
      "sub": "20% de 350",
      "icon": "calc",
      "kind": "calc",
      "action": { "type": "copy", "value": "70" },
      "score": 0.98
    }
  ]
}
```
- `action.type` es uno de `copy` (copiar a portapapeles), `open-url` (`value` = URL), `exec` (`argv`: lista; `terminal`: booleano) o `none`.
- Tú ejecutas las acciones desde un servicio; Codex nunca las ejecuta.
- El modo `@` (ir a escritorio) lo resuelves tú con los datos de Hyprland, sin Codex.

**`dragon-usage record <desktop-id>`** anota un lanzamiento. **`dragon-usage stats --json`** devuelve:
```json
{ "apps": [ { "id": "brave-browser", "total": 214, "week": 41, "lastUsed": 1761830000, "frecency": 0.93 } ] }
```
`frecency` va de 0 a 1 y manda en el **tamaño** de cada planeta. Los favoritos los sigues sacando del servicio actual de apps fijadas, no de Codex.

**`dragon-clip classify --json`** (lista de entradas por stdin: `[{ "id", "text", "isImage" }]`) devuelve cada una con `kind` (`text`, `command`, `link`, `path`, `color`, `image`), `label` en español y `preview`. **`dragon-clip pins list|add <id>|remove <id> --json`** guarda los fijados. **`dragon-clip meta <id> --json`** devuelve `{ "app": "ghostty", "time": 1761830000 }` si se anotó al copiar.

**Hasta que Codex termine,** crea tú un `dragon-search` y un `dragon-usage` provisionales que devuelvan datos de prueba con ese esquema. No los subas al repo.

---

## 1. Launcher «Gravedad» (reposo) — `02-launcher.png`

Evoluciona `modules/launcher/LauncherView.qml`. Conserva el planeta del núcleo en el centro.

1. **Tres anillos elípticos** de apps alrededor del núcleo, con rótulo discreto cada uno: `FAVORITOS` (el más cercano), `FRECUENTES` y `TODAS`. Los radios del diseño son 250×82, 410×136 y 575×192 sobre 1366×768: escálalos proporcionalmente a la pantalla.
2. **Profundidad:** cada app tiene un ángulo. Su escala, opacidad y desenfoque dependen del seno del ángulo (más atrás = más pequeña, más tenue, más borrosa). Los iconos de atrás pasan **detrás** del núcleo, como ya se resolvió (sección 7n del HANDOFF).
3. **Tamaño = uso.** El tamaño de cada planeta sale de `frecency` (rango 0,85× a 1,25× del tamaño base del anillo).
4. **Luna = ventana abierta.** Cada ventana abierta de la app es una lunita que orbita su planeta (máximo 3 visibles, y un «+N» si hay más).
5. **Giro lento** continuo de cada anillo, en sentidos alternos. Se detiene mientras el cursor está sobre un planeta. Pausa total cuando el launcher no es visible y respeta una opción «reducir movimiento» (`Settings.reduceMotion`, créala si no existe).
6. **Al pasar el cursor** por un planeta, este pasa al frente, crece un poco y el núcleo muestra su nombre y su línea de detalle («3 ventanas abiertas · usado 41 veces esta semana»). Es la línea de `dragon-usage`.
7. **Etiquetas del pie:** «Luna = ventana abierta», «Tamaño = cuánto la usas», fecha y hora y el recuento de apps.
8. **Clic** abre la app y llama a `dragon-usage record`. **Clic central o ESC** cierra.
9. **Rendimiento:** iconos en caché, sin recalcular la órbita fuera de los fotogramas, máximo 60 planetas dibujados (el resto se agrupa en el anillo `TODAS` con desplazamiento por rueda del ratón).
10. **Interruptor** en Ajustes: «Launcher Gravedad» (`Settings.launcherGravity`, activado por defecto). Apagado, vuelve al launcher actual, que se conserva sin cambios.

## 2. Launcher «Gravedad» (buscando) — `03-busqueda.png`

1. Al teclear, los planetas que no coinciden pasan a **fantasmas** pequeños y borrosos en la periferia (unos 20, translúcidos). Los que coinciden se acercan al núcleo.
2. **Panel de resultados** en lista, con las letras coincidentes resaltadas, un icono y una línea secundaria. Navegación con ↑↓ y Enter para abrir.
3. **Fila de «MODOS»** (chips) que se muestra al escribir un prefijo o al pulsar `?` con el campo vacío:

| Prefijo | Modo | Fuente |
|---|---|---|
| `=` | Calculadora | `dragon-search calc` |
| `>` | Ejecutar comando | `dragon-search cmd` |
| `?` | Buscar en la web | `dragon-search web` |
| `:` | Emoji y símbolos | `dragon-search emoji` |
| `@` | Ir a escritorio | Hyprland (tú) |
| `/` | Portapapeles | sección 5 |

4. **Lunas de terminal:** si la app elegida es una terminal con varias ventanas abiertas, aparece una fila «LUNAS DE TERMINAL · TAB». Tab salta de luna en luna y Enter va a esa ventana (`focuswindow`).
5. **Servicio nuevo `services/Search.qml`:** recibe el texto, decide el modo por el prefijo, llama a Codex (o a Apps / Hyprland) y devuelve una lista unificada de resultados con el mismo formato. Ejecuta las acciones (`copy` con `wl-copy`, `open-url` con `xdg-open`, `exec` directo o dentro de la terminal predeterminada).
6. La barra inferior muestra las teclas: «↑↓ elegir · ENTER abrir · TAB ir a una luna · ESC cerrar».

## 3. Alt+Tab orbital — `10-alttab.png`

1. **Ventana de capa nueva** (`dragon-switcher`) con foco de teclado exclusivo mientras está abierta. Una sola región de blur.
2. Se abre con `Alt + Tab` y avanza con cada Tab; `Shift` retrocede. **Al soltar Alt se confirma** y se enfoca la ventana elegida. `Esc` cancela. Si Hyprland no entrega el Alt al soltarlo, busca el camino con `hl.bind` y la opción de soltar tecla; **si no hay una forma limpia, para y pregunta.**
3. **Orden MRU:** amplía `services/Hypr.qml` con el historial de foco (último usado primero), a partir de los eventos de ventana activa.
4. **Anillo elíptico** (unos 470×110) de tarjetas, con la elegida al frente y grande (unos 440 px), y el resto con la misma profundidad de seno que el launcher. Cada tarjeta lleva una captura **tomada una sola vez al abrir** (`ScreencopyView`; sin captura continua), el título, y bajo la elegida «Ghostty · herdr · SoftArch» y «Escritorio 2 · activa hace 4 min».
5. **Filtros** (chips): `Todas`, `Este escritorio`, `Por app`. Las teclas `1` a `5` filtran por escritorio. `Q` cierra la ventana elegida.
6. Barra de teclas abajo: «ALT+TAB siguiente · ⇧ anterior · Q cerrar ventana · 1–5 filtrar escritorio».
7. Rendimiento: si hay más de 12 ventanas, el anillo muestra 12 y gira con la rueda o con Tab. Un toque rápido de Alt+Tab (soltar antes de que se pinte) cambia a la ventana anterior sin mostrar nada.
8. Ajustes: «Alt+Tab orbital» (`Settings.switcherOrbital`, activado por defecto). Apagado, el atajo no se captura.

## 4. Vista general de escritorios — `11-escritorios.png`

1. Ventana de capa `dragon-overview`, se abre con `SUPER + Tab`.
2. **Cinco tarjetas** (220×124 en el diseño, escaladas) en fila, una por escritorio, con su número, el nombre (la app dominante) y el escritorio actual marcado. La vacía dice «Vacío».
3. Cada tarjeta dibuja las ventanas como rectángulos con sus proporciones reales (usa la geometría de `hyprctl clients`; ya lo hace `services/WorkspacePreview.qml`, amplíalo). Las capturas reales solo para la tarjeta bajo el cursor, en un panel de «VISTA PREVIA» más grande debajo.
4. **Arrastrar una ventana** de una tarjeta a otra la mueve (`movetoworkspacesilent` desde un servicio). La tarjeta de destino se resalta en cian («Soltar aquí»).
5. **Enter** va al escritorio elegido; ←/→ o `1` a `5` eligen; `Esc` cierra.
6. Barra de teclas: «SUPER+TAB abrir · ARRASTRAR mover ventana · ENTER ir al escritorio».
7. `SUPER + Tab` no debe chocar con atajos existentes. Revisa `config/hypr/binds.lua` y `KEYBINDS.md`, y actualiza la lista de atajos.

## 5. Portapapeles orbital — `12-portapapeles.png`

1. Modo `/` del launcher (y `SUPER + V` lo abre directamente en ese modo). Sustituye al panel actual `modules/clipboard/ClipboardPanel.qml`, que se queda como respaldo detrás de `Settings.launcherGravity` apagado.
2. **Anillo de tarjetas** (unos 470×125) con la entrada seleccionada grande (unos 400×170), el tipo (`kind`, con su color de chip), una vista previa, y una línea «Comando · copiado desde Ghostty / hace 2 min · 48 caracteres» (`dragon-clip meta`; si no hay dato, omite «copiado desde»).
3. Filtros por tipo y contador de elementos. Búsqueda con el texto que escribes tras `/`.
4. **Teclas:** Enter pega, Ctrl+P fija o desfija (`dragon-clip pins`), Supr borra (`Clipboard.remove`), ← → recorren.
5. **Pegar:** copia la entrada con `wl-copy`, cierra el launcher y envía Ctrl+V a la ventana que tenía el foco (mira qué opción da Hyprland 0.56.2 con `sendshortcut` o `wtype`; **si no es limpio, para y pregunta**).
6. Las imágenes usan la miniatura que ya da `Clipboard.thumbnail`.
7. **Privacidad:** la vista previa de entradas con aspecto de secreto (cadenas largas sin espacios que empiezan por `sk-`, `ghp_`, `AKIA`, etc.) se muestra enmascarada hasta pulsar Espacio.

## 6. Atajos y migraciones

- `Alt + Tab` → `qs ipc call switcher next`; `Alt + Shift + Tab` → `qs ipc call switcher prev`; `SUPER + Tab` → `qs ipc call overview toggle`; `SUPER + V` → `qs ipc call launcher clipboard`. Regenera la lista con `scripts/gen-keybinds.sh`.
- `025-gravity-launcher-settings.sh`: añade `launcherGravity`, `switcherOrbital` y `reduceMotion` a `settings.json` sin pisar valores del usuario.
- `026-switcher-keybinds.sh`: sustituye los atajos antiguos de Alt+Tab, SUPER+Tab y SUPER+V con copia de seguridad.
- Si Codex entregó `dragon-clip-store`, enlaza el vigilante del portapapeles en `config/hypr/autostart.lua` (migración `027`). Si todavía no existe, deja `wl-paste --watch cliphist store` como está.

## 7. Comprobaciones antes de terminar

1. El launcher en reposo tiene tres anillos, giro lento, tamaño por uso y lunas por ventana abierta.
2. Teclear una letra atrae a los que coinciden, y `=`, `>`, `?`, `:`, `@` y `/` cambian de modo con su chip.
3. `Alt + Tab` abre el anillo y soltar Alt enfoca la ventana elegida. Un toque rápido cambia a la anterior sin parpadeos.
4. `SUPER + Tab` muestra las cinco tarjetas y arrastrar una ventana la cambia de escritorio.
5. `SUPER + V` abre el modo portapapeles; Enter pega en la ventana que tenía el foco.
6. Con `launcherGravity` y `switcherOrbital` apagados, todo vuelve al comportamiento anterior.
7. Sin `dragon-search`, `dragon-usage` o `dragon-clip` instalados, el launcher sigue abriendo apps sin errores en el registro.
8. Consumo de CPU en reposo con el launcher cerrado: 0 % de la animación (no debe haber temporizadores activos).
9. `docs/handoff-fase-4-claude.md` actualizado, con lo que no se pudo hacer tal cual y lo que no pudiste probar (clic, arrastre, soltar Alt).

Termina con un resumen corto: qué hiciste, qué desviaste del diseño y qué necesita ver el usuario en pantalla.
