# Nueva identidad de dragon-island — Fase 2: la isla como centro de estado, capturas, grabación, enfoque, terminal desplegable, inactividad y bloqueo

Continúa en la rama `feat/nueva-identidad`, sobre las Fases 0, 1 y 1.1. Las mismas reglas:
- primero la skill `dragon-island` y `docs/HANDOFF.md` (incluidas tus secciones 8a y 8b);
- un commit por punto numerado;
- migración para todo lo que afecte a sistemas instalados;
- nada de colores ni duraciones fuera de `Theme`;
- la UI nunca ejecuta comandos: todo pasa por servicios;
- si algo no es viable tal cual en Quickshell 0.3.1 / Hyprland 0.56.2, **para y pregunta**.

Referencias visuales en `docs/design/` (el usuario las añade ahora):
- `06-bloqueo.png`
- `09-isla.png`
- `13-capturas.png`
- `17-agentes.png`
- `18-nucleo.png`
- `24-desplegable.png`
- `25-grabacion.png`
- `26-inactividad.png`

**Fuera de alcance:** login SDDM (salvo lo que herede del núcleo), fondos orbitales y paleta desde el fondo, Alt+Tab, vista general, módulo ágil, panel de desarrollo (contenedores, logs, GitHub) y los detalles pendientes del dock. No toques los colores de herdr, Ghostty, Starship ni kitty.

---

## 1. Prioridad de estados de la isla

Antes de añadir estados, ordena `services/IslandState.qml`. Hoy tiene `osd · tiling · notification · agent · workspace · media · clock`. Pasa a esta prioridad, de mayor a menor:

1. `capture` · barra de capturas abierta (interactiva)
2. `recording` · grabando (persistente)
3. `osd` · volumen, brillo, Bloq Mayús, teclado (transitorio, 1,6 s)
4. `agentBlocked` · un agente espera tu respuesta (persistente hasta que se resuelva)
5. `notification` · peek de una notificación (transitorio)
6. `idleWarn` · aviso antes de bloquear (persistente mientras dure)
7. `workspace` y `tiling` (transitorios)
8. `agentWorking` · hay agentes trabajando (persistente)
9. `focus` · modo enfoque activo (persistente)
10. `commandDone` · un comando largo terminó (transitorio, 4 s)
11. `media` / el contenido elegido en `Settings.islandContent` (`window`, `date`)

Reglas:
- Un estado persistente de menor prioridad **vuelve** cuando termina uno transitorio de mayor prioridad.
- Documenta la tabla en el bloque de comentarios del archivo.
- Cada estado tiene un **ancho propio**: la isla se deforma con su spring actual entre uno y otro. En el estilo B (flotante) crece hacia los lados y hacia abajo, sin orejas. En A y C crece desde el borde.

## 2. OSD dentro de la isla (`09-isla.png`)

Reestiliza los estados de `Osd` en la isla colapsada, con la altura de la isla de la Fase 1.1 + peek:

- **Volumen:** icono que cambia con el nivel, nombre de la **salida activa** encima de la barra en `textDim` 11 (por ejemplo «UACDemoV1.0»), barra de 5 px (`text` sobre blanco al 15 %) y número en `fontMono` 14 semibold. Ancho ~300.
  - **Nuevo:** la rueda sobre la isla en estado volumen sigue ajustándolo sin abrir el panel.
- **Micrófono:** igual, con la fuente activa.
- **Brillo:** icono de sol en `warn`; si la luz nocturna (`Toggles.nightLight`) está activa, el icono se entibia (`#FCD34D` → `warn`). Ancho ~260.
- **Bloq Mayús (nuevo):** píldora corta con flecha en `warn` y «BLOQ MAYÚS» en `fontMono` 11, espaciado 0,08 em. Al desactivarlo, la misma píldora sin el icono encendido durante 0,8 s.
  - Para detectarlo lee `/sys/class/leds/*::capslock/brightness`. En sysfs no hay eventos: usa un `Timer` de 250 ms **solo** mientras haya un teclado, igual que hace `Brightness` con su lectura de 300 ms. Si no existe el LED, prueba `hyprctl devices -j` (campo `capsLock`) y anota cuál funcionó.
- **Cambio de teclado (nuevo):** «US → ES» (o la distribución que corresponda) en `fontMono`, a partir de `Keyboard.code`. 1 s.

## 3. Agentes y comandos en la isla (`17-agentes.png`)

### 3.1 Estados compactos

- **`agentWorking`:** núcleo mini (`NeuralCore` compacto, `mood: "thinking"`) a la izquierda + «Pensando…» + el nombre del workspace de herdr del agente que más tiempo lleva (`Herdr.longestWorking`). Con 2 o más, «N agentes trabajando».
- **`agentBlocked`:** punto `warn` que late (1,6 s) + «<workspace> espera tu respuesta», con un borde interior `alpha(warn,.5)`. Persistente mientras herdr lo reporte `blocked`. Sustituye al destello actual de `agent`.
- **`commandDone`:** ✓ en `ok` o ✗ en `error` + el comando en `fontMono` (recortado con «…») + la duración en `textDim` («2m14s»; si falló, «salida 1 · 48s»).

### 3.2 Comandos largos (nuevo servicio `services/Commands.qml`)

- En `config/zsh/dragon.zsh`, hooks `preexec` y `precmd`: si un comando duró **≥ 30 s** (umbral en `Settings.longCommandSeconds`), llaman **en segundo plano y sin bloquear el prompt** a:
  `qs ipc call commands finished "<comando>" <código> <segundos> "<cwd>"`
- Opcional: `started` para listar los que están en curso.
- Solo avisa si **la terminal no está enfocada** en ese momento. Usa `Hypr` para saber la ventana activa; el hook pasa el PID de la terminal o la dirección de la ventana si es fácil de obtener. Si no es fiable, avisa siempre y anótalo.
- Cuida el rendimiento del prompt: el hook no puede añadir latencia perceptible. Mídelo con un `time` de 20 prompts antes y después.

### 3.3 Vista expandida de agentes

- Rehaz la pestaña **IA** del Nook (`AiTab` / `AgentRow`) con el aspecto de `17-agentes.png`:
  - **Agente esperando:** tarjeta con fondo `alpha(warn,.08)`, borde `alpha(warn,.35)`, nombre, rama o tarea y la acción que espera (el título del panel, si herdr lo da).
  - **Agente trabajando:** spinner cian y tiempo «observado desde».
  - **Terminado:** ✓ `ok`.
  - **Comandos en curso y terminados recientes** debajo, desde `Commands`.
- **Aprobar / Rechazar.** Revisa `herdr --help` y `herdr agent --help` / `herdr pane --help`:
  - si herdr permite **enviar una respuesta o teclas a un panel**, implementa los botones Aprobar y Rechazar con eso;
  - si no, un solo botón **«Responder»** que enfoca el panel (`Herdr.focusAgent`).
  - No inventes una API: anota lo que encontraste.
- Atajo para abrir el Nook directo en IA: `SUPER + ALT + A` (comprueba que esté libre), con descripción «Agentes · Ver agentes y comandos en la isla».
- **El núcleo del Nook** (si lo hay) y el de la isla pasan a `thinking` mientras haya agentes trabajando.

## 4. Capturas desde la isla (`13-capturas.png`)

Sustituye `grimblast` en `Print` y `SUPER + SHIFT + S` por un flujo propio, sin perder lo que hoy funciona: copiar al portapapeles y guardar en `~/Imágenes`, o en la carpeta XDG de imágenes.

- **`SUPER + SHIFT + S` o `Print`** → estado `capture` de la isla: una barra con Región · Ventana · Pantalla │ grabar ● · retraso «3 s».
  - Teclas: `1–3` cambian de modo y `Esc` cierra.
  - `Print` sin modificador = **pantalla completa directa**, sin barra (como hoy).
- **Región:** una ventana de capa `Overlay` a pantalla completa (namespace `dragon-capture`, sin blur) con la pantalla **congelada** (`ScreencopyView` de la salida, `live: false`), el exterior oscurecido al 62 %, la selección con borde `cyan` de 1,5 px, una rejilla de tercios y tiradores en las esquinas y en el centro de los lados, y la medida «750 × 340» en `fontMono`.
  - Mover la selección con `Espacio` + arrastrar.
  - Después recorta con `grim -g`.
  - Si la pantalla congelada no es viable con el `ScreencopyView` de 0.3.1, usa `slurp` con los colores de la paleta (`-b`, `-c`, `-B`) y anótalo.
- **Ventana:** al pasar el cursor se resalta la ventana bajo él (con las geometrías de `Hypr` / `HyprlandToplevel`) y el clic la captura.
- **Acciones después de seleccionar** (barra bajo la selección):
  - **Copiar** (primaria, en cian), **Guardar**.
  - **Anotar**, solo si hay `satty` o `swappy` instalado; abre la imagen ahí.
  - **Texto**, solo si hay `tesseract`; copia el texto reconocido y avisa en la isla.
  - Los opcionales que falten no aparecen. `doctor.sh` puede sugerirlos.
- **Grabar** (●) usa `Toggles.toggleRecording` con la misma selección, en vez de un segundo `slurp`.
- **Notificaciones agrupadas.** En `Notifs`, agrupa por app las notificaciones del centro: «Capturas ×64» con la última captura apilada encima y botones «Abrir carpeta» / «Ver las N».
  - Las capturas propias **no** generan un popup por cada una: el aviso es el estado de la isla («Copiada · guardada en Imágenes», 2 s).
  - Agrupa también Telegram y cualquier app con 3 o más notificaciones.

## 5. Modo grabación (`25-grabacion.png`)

Nuevo servicio `services/RecordingMode.qml`:

- **Se activa solo** si `Toggles.isRecording`, o si `Privacy.screen` detecta un streaming de pantalla por el portal (así graba OBS en Wayland, y también las llamadas que comparten pantalla).
- `Settings.recordingMode`: `"auto" | "off"`, por defecto `"auto"`.
- Cada regla es un interruptor en **Ajustes › Privacidad** (pestaña nueva):

| Regla | Por defecto |
|---|---|
| Retener notificaciones (`Notifs.hold`: se guardan sin popup ni peek; al terminar, la isla dice «N notificaciones retenidas») | ✔ |
| Ocultar títulos y contexto vivo en la barra («título oculto» con un ojo tachado) | ✔ |
| Pausar el historial del portapapeles (lo copiado no entra; revisa cómo guarda `Clipboard.qml`) | ✔ |
| Marco de grabación: borde `alpha(error,.75)` de 2 px en toda la pantalla, ventana `Overlay` sin máscara de entrada ni blur | ✔ |
| Mostrar atajos en pantalla (un overlay pequeño con las teclas pulsadas, solo si hay una forma limpia de leerlas) | ✘ (si no es viable, omítelo y anótalo) |

- **Estado de la isla `recording`:** punto `error` que late, «REC», tiempo en `fontMono`, un mini ecualizador `ok` si hay audio y, a la derecha, «N retenidas» en `warn` si hay notificaciones retenidas.
  - Con `Toggles.isRecording`, clic en la isla para detener.
  - Con `Privacy.screen` (OBS u otra app), clic muestra qué app captura.
- **Limitación conocida:** sin obs-websocket no se distingue que OBS *capture* de que *grabe*. Con `auto` el modo se activa en cuanto OBS captura la pantalla. Anótalo en el HANDOFF y en el texto de la regla en Ajustes.

## 6. Modo enfoque (`09-isla.png`, última tarjeta)

Nuevo servicio `services/Focus.qml`, con IPC `focus start <minutos> | stop | toggle`:

- **Al empezar:**
  - activa No molestar;
  - pasa la barra al estilo **D** de forma **temporal** (sin tocar `Settings.barStyle`);
  - retiene las notificaciones de las apps de una lista (`Settings.focusMuteApps`, por defecto `["Telegram"]`).
- **Al terminar**, restaura todo, y la isla dice «Enfoque terminado · N notificaciones retenidas».
- **Estado de la isla `focus`:** anillo de cuenta regresiva de 28 px (pista blanca al 14 %, progreso `#5EEAD4`, de arriba en sentido horario), «Enfoque · 24:12» en `fontMono` y debajo, en `textDim` 10, «Telegram silenciado · barra mínima».
- **Para iniciarlo:**
  - un mosaico nuevo «Enfoque» en `NotchToggles`: clic = 45 min, clic derecho = elegir entre 25 / 45 / 90;
  - un atajo libre (propuesta: `SUPER + ALT + F`), con descripción «Shell · Modo enfoque».

## 7. Terminal desplegable desde la isla (`24-desplegable.png`)

- Un workspace especial `special:dropdown` con **una** Ghostty de clase propia (por ejemplo `org.dragonisland.Dropdown`; Ghostty necesita un ID con puntos, ver §7h).
- **Reglas de ventana:**
  - flotante y siempre en `special:dropdown`;
  - ~69 % del ancho de la pantalla y ~55 % del alto, centrada en horizontal;
  - el borde superior justo **bajo la isla expandida**;
  - sin hyprbars, con radio y borde lavanda → cian como las demás;
  - animación `slidevert` con `emergente` al entrar y `salida` al irse.
- **Atajo `SUPER + grave`** (la tecla bajo Esc en US), con descripción «Aplicaciones · Terminal desplegable». Un script `bin/dragon-dropdown`:
  - si no existe la ventana, la lanza;
  - si existe, alterna el workspace especial;
  - revisa el dispatcher correcto de 0.56.2 para alternar un workspace especial en Lua.
- **La isla y la terminal se mueven juntas.** Cuando `special:dropdown` está visible (evento `activespecial`), la isla pasa a un estado `dropdown`: crece en ancho hasta el de la terminal y su borde inferior queda pegado al superior de la terminal, para que parezcan una sola pieza.
  - Ghostty se configura con fondo `islandInk` casi opaco (`background-opacity` ~0,96, en un archivo de configuración solo para esta clase, por ejemplo con `--config-file`).
  - En la isla: el núcleo mini en `listening`, «Terminal» y, a la derecha, «SUPER + `` ` `` ocultar» en `textDim`.
- **Persistencia:** al ocultarla, los procesos siguen corriendo (es un workspace especial, no se cierra).
- **Pestañas por proyecto:** si las pestañas nativas de Ghostty se ven bien con la configuración actual (`gtk-titlebar = false`), úsalas. Si no, omítelas y anótalo; **no** metas tmux ni herdr aquí.
- Las ventanas de esta clase quedan excluidas del dock y de la constelación de escritorios.

## 8. Secuencia de inactividad (`26-inactividad.png`)

Rehaz `config/hypr/hypridle.conf` con estos pasos (tiempos configurables en Ajustes › Energía, pestaña nueva, guardados en `settings.json`; la migración regenera el `.conf` o lo deja leyendo los valores, lo que sea más simple y robusto):

| Paso | Por defecto | Qué hace |
|---|---|---|
| Aviso | 4 min | `qs ipc call idle warn` → estado `idleWarn` en la isla: punto `warn` + «Bloqueo en 60 s · mueve el ratón». Al volver: `qs ipc call idle resume` |
| Atenuar | 4 min | Capa `Overlay` negra a pantalla completa (namespace `dragon-dim`, sin entrada ni blur) que sube a opacidad 0,6 en 900 ms con `estandar`. Funciona con cualquier monitor, sin brillo por DDC. Quita el `brightnessctl -s set 15%` actual |
| Bloquear | 5 min | `loginctl lock-session` → el bloqueo de Quickshell (como hoy) |
| Apagar pantallas | 5,5 min | dpms off (como hoy) |
| Suspender | 20 min | `systemctl suspend` (hoy son 30; el valor nuevo es 20) |

**No avanzar** mientras haya:
- **un agente trabajando:** `IdleInhibitor` activo con `Herdr.counts.working > 0`, igual que hace `Caffeine`. Interruptor en Ajustes, por defecto ✔;
- **el modo grabación activo;**
- **un video en reproducción:** comprueba si Brave y mpv ya inhiben solos; si no, usa `Media` con un reproductor en estado playing y la ventana visible).

Reinicia `hypridle` en la migración, porque solo lee `lock_cmd` al arrancar (§7za).

## 9. Bloqueo con la nueva identidad (`06-bloqueo.png`)

Reestiliza `modules/lock/LockView.qml` sin tocar la lógica de `Lock.qml` (PAM, `WlSessionLock`, IPC):

- **Núcleo detrás del reloj:** `NeuralCore` con `hud: true`, ~440 px, opacidad ~0,72, `mood: "calm"`.
  - `listening` mientras escribes, `verifying` al comprobar, `alert` si la contraseña está mal y `ok` al desbloquear (estos ya existen).
- **Reloj:** 132 px, peso 200, con la fecha debajo en `textSoft` 17.
- **Satélites de notificaciones:** sobre la órbita punteada, los iconos de las apps con notificaciones sin leer (máximo 3), en nodos de cristal circulares de 42 px con el número en una píldora (`Theme.badge` del dock). Y un satélite cian pequeño en movimiento.
- **Usuario y contraseña:**
  - avatar circular de 44 px (`~/.face`, o iniciales si no existe) con un anillo cian suave;
  - nombre y «bloqueado hace N min» en `fontMono` 11;
  - campo de 340 × 46 con radio 23 y el botón → circular de 34 px;
  - debajo: «Enter para desbloquear · Bloq Mayús activado/desactivado» y la etiqueta US/LA, que hoy ya existe.
- **Mini reproductor** abajo a la izquierda (si hay media): portada, título, progreso y pausa.
- Arriba, «DRAGONOS · BLOQUEADO» en `fontMono` con espaciado.
- **Al suspender:** el núcleo se encoge y se apaga en ~900 ms antes de que se apague la pantalla, si `before_sleep_cmd` deja tiempo; si no, omítelo.
- Rendimiento: el bloqueo puede quedarse horas encendido. Mide la GPU con el bloqueo activo, y si sube, baja `pointCount` o los fps del núcleo **solo** en el bloqueo.

## 10. Ajustes, atajos, migración y documentación

- **Ajustes:** pestañas nuevas **Privacidad** (modo grabación) y **Energía** (inactividad, inhibir con agentes). En Barra superior, el umbral de comandos largos.
- **Atajos:** todos con `description`, en `docs/KEYBINDS.md` y, si hay teclas dentro de paneles, en `panelGroups` de `services/Keybinds.qml`:
  - `SUPER + grave`
  - `SUPER + ALT + A`
  - `SUPER + ALT + F`
  - `Print` y `SUPER + SHIFT + S` (cambian de comportamiento)
  - las teclas dentro del modo captura
- **Migración `022-isla-sistema.sh`:**
  - claves nuevas de `settings.json`, solo las que falten;
  - despliega `bin/dragon-dropdown` y la configuración de Ghostty para la terminal desplegable;
  - reinicia `hypridle`;
  - recarga zsh solo con un aviso, sin `exec` forzado;
  - paquetes opcionales (`satty`, `tesseract`, `tesseract-data-spa`) **solo con confirmación**.
  - Idempotente, con `DRY_RUN` / `ASSUME_YES` y salida 10 si no hay nada que hacer.
- **`docs/HANDOFF.md`:** sección «8c. Fase 2 · isla y sistema» con hecho / verificado / no verificado / decisiones.

---

## Verificación

- `qs -p` sin errores, `qs log -f` limpio durante el uso, `hyprctl configerrors` vacío, `luac -p`, `shellcheck -x`, `sync-shared --check` y `tests/run-all.sh`.
- **Isla:** captura de cada estado en los estilos B y C: volumen, brillo, Bloq Mayús, teclado, agente trabajando, agente esperando, comando terminado (OK y fallido), capturas, grabando, enfoque, aviso de inactividad y terminal desplegable. Comprueba la prioridad: por ejemplo, un OSD durante una grabación vuelve a REC al terminar.
- **Comandos largos:** `sleep 35` en una terminal mientras miras otra ventana muestra el aviso. Medición de latencia del prompt antes y después.
- **Capturas:** región, ventana, pantalla y con retraso; copiar y guardar; «Capturas ×N» agrupado; ningún popup por captura.
- **Grabación:** `SUPER + SHIFT + R` activa el modo con sus reglas. Una notificación de prueba (`notify-send`) queda retenida y aparece al terminar. El marco rojo se ve. El portapapeles no guarda nada durante la grabación.
- **Enfoque:** iniciar 1 min de prueba, ver la barra en D y que todo vuelve al terminar.
- **Terminal desplegable:** aparece y se esconde con su atajo, la isla y la terminal quedan pegadas en B y C, y un proceso sigue vivo tras ocultarla.
- **Inactividad:** con tiempos cortos de prueba (aviso a 10 s, atenuar a 15, bloquear a 25), recorre la secuencia y comprueba que un agente trabajando la detiene. **Restaura los tiempos reales al terminar.** Si bloquear la sesión no es seguro durante la prueba, para en el paso de atenuar y dilo.
- **Bloqueo:** con `qs ipc call lock lock`, si el usuario lo autoriza, captura y prueba con una contraseña mala y luego buena. Si no puedes desbloquear de forma segura, no bloquees y verifícalo con un render offscreen de `LockView` (`tests/qml`).
- `gpu_busy_percent` y la CPU de Quickshell en reposo, antes y después.

Al terminar: un resumen corto, qué no pudiste verificar y en qué te apartaste del prompt y por qué.
