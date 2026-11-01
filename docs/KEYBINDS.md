# dragon-island — Atajos y controles

Modificador principal: **SUPER** (tecla Windows). Los atajos de Hyprland están en [`config/hypr/binds.lua`](../config/hypr/binds.lua); los paneles del shell se abren con `qs ipc call shell toggle <panel>`.

> **`SUPER + F1` muestra esta lista dentro del escritorio.** La lee en vivo de Hyprland (`hyprctl binds -j`) usando la `description` de cada atajo («Grupo · Texto»): si añades o cambias un atajo en `binds.lua` con su descripción, aparece ahí sin tocar nada más.

## Aplicaciones y sistema

| Atajo | Acción |
|---|---|
| `SUPER + Return` | Terminal (Ghostty) |
| `SUPER + Space` | Lanzador de aplicaciones |
| `SUPER + E` | Dolphin |
| `SUPER + D` | Notch: abre / cierra el panel expandido (Nook · Tray). También Esc o clic fuera |
| `SUPER + W` | Selector de fondos orbital (también con clic derecho en el escritorio vacío); su botón «Cuadrícula» abre el selector clásico |
| `SUPER + SHIFT + W` | Fondo aleatorio |
| `SUPER + SHIFT + R` | Grabar la pantalla (elige la salida; otra vez para parar). La cápsula roja de la barra también para |
| `SUPER + I` | Tienda de apps (pacman + AUR). También: lanzador → `+nombre` |
| `SUPER + SHIFT + A` | Referencia de herdr: atajos (los de fábrica y los que cambiaste), comandos de la CLI y estados de los agentes. Solo lectura |
| `SUPER + A` | Agentes: abre herdr en el escritorio 5 («agentes») o, si ya hay una ventana, la enfoca. Las sesiones sobreviven al cerrar la ventana |
| `SUPER + N` | Calendario + notificaciones + actualizaciones (el popover del reloj) |
| `SUPER + Escape` | Menú de energía |
| `SUPER + L` | Bloquear (`loginctl lock-session` → hyprlock) |
| `Print` | Captura de la pantalla completa, directa: se copia y se guarda en Imágenes (aviso en la isla, sin popup) |
| `SUPER + SHIFT + S` / `SHIFT + Print` | Barra de capturas en la isla: Región · Ventana · Pantalla · ● grabar · retraso 3 s |
| ``SUPER + ` `` (grave) | Terminal desplegable bajo la isla (se oculta sin cerrarse) |
| `SUPER + ALT + A` | La isla con los agentes y los comandos largos (pestaña IA) |
| `SUPER + /` | La isla de mando con la línea de mando lista para escribir |
| `SUPER + ALT + F` | Modo enfoque 45 min (No molestar, barra mínima, Telegram silenciado) |
| `SUPER + V` (o `SUPER + SHIFT + V`) | Portapapeles: el anillo del launcher Gravedad (Enter pega en la ventana que tenía el foco). Con «Launcher Gravedad» apagado, el panel de antes |
| `SUPER + Tab` | Vista general de escritorios: cinco tarjetas, arrastra una ventana a otra para moverla |
| `SUPER + F1` | Ayuda: panel con todos los atajos de Hyprland |
| `SUPER + T` | Taller de ingeniería (Agentes · Kanban · Contenedores · Git · Revisión) |
| `SUPER + F2` | Ajustes (estilo de la barra, contenido de la isla, métricas, intensidad del acento) |
| `SUPER + ALT + B` | Cambiar el estilo de la barra (A notch · B isla · C unida · D mínima) |

## Ventanas

| Atajo | Acción |
|---|---|
| `SUPER + Q` | Cerrar ventana |
| `SUPER + F` | Maximizar / restaurar (conserva los huecos) |
| `SUPER + SHIFT + F` | Pantalla completa real |
| `SUPER + SHIFT + Space` | Alternar flotante (antes `SUPER + V`) |
| `ALT + Tab` / `ALT + SHIFT + Tab` | Alt+Tab orbital: siguiente / anterior; al soltar Alt se enfoca la elegida. Un toque rápido cambia a la anterior sin mostrar nada. Se apaga en Ajustes › Launcher (entonces Alt+Tab queda para las apps) |
| `SUPER + CTRL + T` | Alternar el modo de mosaico del escritorio: **Dwindle** (árbol, por defecto) ↔ **Scrolling** (columnas en una cinta horizontal, layout nativo de Hyprland 0.56). Cada escritorio recuerda el suyo (`~/.local/state/dragon-island/tiling.json`); también la cápsula `DWINDLE` / `SCROLL` de la barra y `qs ipc call tiling toggle\|set dwindle\|set scrolling\|get` |
| `SUPER + ←↑→↓` | Mover el foco |
| `SUPER + ALT + H/J/K/L` | Mover el foco (estilo Vim) |
| `SUPER + SHIFT + ←↑→↓` · `SUPER + SHIFT + H/J/K/L` | Mover la ventana |
| `SUPER + arrastrar con clic izquierdo` | Mover ventana |
| `SUPER + arrastrar con clic derecho` | Redimensionar ventana |

> `SUPER + L` es bloquear, por eso la navegación Vim usa `SUPER + ALT`. La spec asigna L a las dos cosas; se priorizó el bloqueo.

## Escritorios

| Atajo | Acción |
|---|---|
| `SUPER + 1…5` | Ir al escritorio 1–5 |
| `SUPER + SHIFT + 1…5` | Mover la ventana al escritorio 1–5 |
| Deslizar 3 dedos en horizontal | Cambiar de escritorio (touchpad) |
| Rueda sobre las píldoras de la barra | Escritorio anterior / siguiente |

## Teclado (distribuciones)

Dos distribuciones: **English (US)** (la primera, la que resuelve los atajos) y **Spanish (Latin American)** para escribir ñ y tildes. Se configuran en [`config/hypr/input.lua`](../config/hypr/input.lua) (`kb_layout = "us,latam"`). Si tu teclado físico es latinoamericano, pon `"latam,us"` ahí.

| Atajo | Acción |
|---|---|
| `SUPER + ALT + Space` | Cambiar de distribución (`hyprctl switchxkblayout all next`) |
| Clic en la cápsula `US` / `LA` (isla derecha, antes de Wi‑Fi) | Siguiente distribución |

El bloqueo usa las mismas dos distribuciones: `SUPER + ALT + Space` también funciona al escribir la contraseña y bajo el campo se ve cuál está activa. `ALT + SHIFT` ya no cambia de distribución (chocaba con `ALT + SHIFT + Tab`, el Alt+Tab orbital hacia atrás).

## herdr (SUPER + A)

Primero `Ctrl+B` (el prefijo) y luego:

| Tecla | Acción |
|---|---|
| `c` | Nueva pestaña |
| `v` · `-` | Dividir en vertical · en horizontal |
| `h j k l` | Mover el foco entre paneles |
| `x` · `z` | Cerrar el panel · zoom (pantalla completa del panel) |
| `Shift+N` · `w` | Nuevo espacio · selector de espacios |
| `q` | Separar (cierra la ventana; la sesión y los agentes siguen) |
| `?` | Ayuda con todas las teclas |

La cápsula de agentes de la barra (robot) solo aparece con agentes: ámbar parpadeante = necesita tu respuesta, cian = trabajando, verde = terminó. Clic abre la lista y otro clic en un agente salta a él. Si un agente se bloquea o termina, el notch lo avisa (clic en el notch = ir a él). Terminal: alias `hd` = `herdr`; actualizar con `herdr update`.

Al volver a abrir herdr después de reiniciar el equipo, recupera espacios, pestañas, divisiones y directorios. Las conversaciones se reanudan si el agente registró su sesión mediante su integración oficial. El instalador configura las de Claude, Codex y OpenCode cuando encuentra el ejecutable y su directorio de configuración; compruébalas con `herdr integration status`. Después de instalar una integración, reabre o reanuda las conversaciones que ya estaban abiertas para que registren su identificador (OpenCode también necesita reiniciar sus servidores compartidos). Para Codex, usa `codex --no-daemon` dentro de herdr si tienes un daemon compartido.

También se conserva el contenido reciente de los terminales (`experimental.pane_history = true`): se escribe en `~/.config/herdr/session-history.json` y puede incluir lo mostrado en pantalla. Reiniciar no vuelve a ejecutar comandos arbitrarios ni continúa una tarea interrumpida automáticamente. Cerrar un panel con `Ctrl+B x` lo elimina de la sesión; para conservarlo, separa el cliente con `Ctrl+B q` o cierra la ventana.

## Tienda de apps (SUPER + I)

| Tecla | Acción |
|---|---|
| Escribir | Buscar en repositorios oficiales y AUR (200 ms de espera) / filtrar la pestaña actual |
| `↑ ↓` | Mover por la lista (los detalles del enfocado cargan a los 300 ms) |
| `Tab` (o `Espacio` con el campo vacío) | Marcar / desmarcar y bajar, como fzf |
| `Enter` | Instalar (Buscar), eliminar con confirmación (Instalados), actualizar todo (Actualizaciones) |
| `Esc` | Cerrar el visor / el diálogo; si no hay, cerrar la Tienda |

Desde el lanzador orbital: `+hypr` + Enter abre la Tienda buscando «hypr». Por IPC: `qs ipc call shell toggle store`.

## Fondos de pantalla orbital (SUPER + W o clic derecho en el escritorio)

| Tecla | Acción |
|---|---|
| `←` `→` | Elegir una miniatura (el anillo gira para mostrarla) |
| `Enter` / clic | Aplicar el fondo (la miniatura cubre la pantalla y se revela con `grow` desde el centro) |
| Rueda | Girar el anillo (con más de 12 fondos) |
| `Esc` / clic fuera del anillo | Cerrar |

## Fondos de pantalla, cuadrícula (botón «Cuadrícula» del orbital)

| Tecla | Acción |
|---|---|
| Escribir | Filtrar por nombre |
| `←↑↓→` | Mover la selección (vista previa grande del seleccionado o del que tiene el cursor encima) |
| `Enter` / clic | Aplicar el fondo |
| `Esc` | Cerrar |

Por IPC: `qs ipc call wallpaper orbital | orbitalAt <x> <y> | toggle` (cuadrícula) `| set <ruta> | random | next | current`.

## Teclas multimedia (funcionan con la pantalla bloqueada)

| Tecla | Acción |
|---|---|
| `XF86AudioRaiseVolume` / `LowerVolume` | Volumen ±5 % (`wpctl`) → OSD en la isla |
| `XF86AudioMute` / `XF86AudioMicMute` | Silenciar salida / micrófono |
| `XF86MonBrightnessUp` / `Down` | Brillo ±5 % (`brightnessctl`) → OSD en la isla |
| `XF86AudioPlay` / `Pause` / `Next` / `Prev` | Control del reproductor (`playerctl`) |

## Barra y notch (ratón)

| Dónde | Clic | Otros |
|---|---|---|
| Botón del núcleo (izquierda) | Lanzador | Clic derecho: dashboard · ratón encima: el núcleo «escucha» |
| Constelación de escritorios (el activo es el planeta) | Ir a ese escritorio | Rueda: anterior / siguiente · ratón encima de un nodo: vista previa con miniaturas de sus ventanas (clic en una = enfocarla) |
| Contexto vivo (app · repo o carpeta · rama / «N sin leer») | | Ratón encima: acciones — cerrar · flotar · fijar (si flota) · mover a un escritorio |
| Borde superior (solo estilo D) | | Acercar el cursor despliega la barra completa (estilo B) |
| Indicador de submap (izquierda) | | Aparece solo con un submap activo |
| Anillos CPU · RAM y línea de red | Popover Rendimiento (CPU de los últimos 30 s, núcleos, RAM, GPU, temperatura, procesos, perfil de energía) | Ratón encima: el detalle como tooltip bajo la isla (la isla no se ensancha) · se ocultan con «Mostrar CPU y RAM» |
| Cápsula `US` / `LA` | Siguiente distribución de teclado | |
| Wi‑Fi · Bluetooth · Batería | Su popover | rueda sobre la batería: brillo ±5 % (la velocidad de bajada / subida está en el popover de Wi‑Fi) |
| Cápsulas contextuales (solo cuando aplican) | Micrófono / cámara / pantalla: lista de apps · grabación: parar · VPN: abre Proton VPN · auriculares: Bluetooth · cafeína y No molestar: alternar · actualizaciones: abre Ghostty con la actualización · red: Rendimiento | Las que no caben se agrupan en `+N` (ratón encima: despliega los iconos) |
| Volumen (icono + barra) | Silenciar | Rueda: ±5 % · clic derecho: popover Sonido |
| Iconos de la bandeja | Acción principal de la app (o su menú si solo tiene menú) | Derecho: menú · central: acción secundaria · rueda: desplazar |
| Reloj orbital (marcadores: No molestar · sin leer · actualizaciones) | Calendario, notificaciones y actualizaciones en un solo popover | Clic derecho: No molestar · ratón encima: la fecha |
| Reloj (cont.) | Calendario | Clic en un día: su agenda (khal) · rueda: cambiar de mes |
| Popup de notificación | Acción por defecto (o cerrar el popup) | Central: descartar · pasar el ratón: no caduca |
| Isla cerrada | Dashboard | Música: clic central = play/pausa |
| Mosaicos del dashboard | Activar / desactivar | Clic derecho en Wi‑Fi, Bluetooth o No molestar: abre su popover |
| Fuera de un panel / `Esc` | Cierra el panel | |

## Dock en arco

| Atajo / gesto | Acción |
|---|---|
| `SUPER + X` | Fijar el dock (siempre visible) o dejarlo en modo automático |
| `SUPER + M` | Minimizar la ventana activa (al escritorio especial `minimized`; sale atenuada en el dock, un clic la restaura) |
| Ratón en el borde inferior (3 px) | El dock emerge; al salir espera 600 ms y se oculta |
| Clic en un icono | Enfocar la app; si ya está enfocada, pasar a su siguiente ventana; abrirla si no está abierta; restaurarla si está minimizada |
| Clic central | Nueva instancia |
| Clic derecho | Menú: fijar / quitar del dock · nueva ventana · cerrar todas · mover a un escritorio (1–5) |
| Clic derecho sobre el cristal del dock | Ajustes del dock: posición (abajo / izquierda / derecha) y siempre visible |
| Rueda del ratón sobre el dock | Si hay más apps que huecos (8), desplaza la banda; el dock no cambia de tamaño |
| Arrastrar un icono fijado | Reordenar las apps fijadas |
| Botón central | Lanzador orbital |
| Carpeta (extremo derecho) | Abanico con las últimas 6 descargas (clic = abrir) |

El icono bajo el ratón se ilumina con el contorno en degradado (sin ampliarse).

El dock se muestra solo cuando el escritorio actual no tiene ventanas en mosaico (vacío, o solo flotantes) y se hunde con una ventana en mosaico o en pantalla completa. Posición y apps fijadas en `~/.local/state/dragon-island/dock.json` (`"position"`: `bottom` · `left` · `right`; `qs ipc call dock position left`).

## Terminal (zsh en Ghostty)

Completar (`Tab` abre el buscador fzf-tab; `Enter` elige, `Esc` cancela). La vista previa cambia según el comando:

| Escribes + `Tab` | Qué pasa |
|---|---|
| `cd`, `z`, `ls`, rutas | Vista previa de la carpeta con eza (con iconos) |
| un archivo (`nvim`, `cat`…) | Vista previa con bat: 200 líneas con números |
| `git add` / `diff` / `restore` | El `git diff` del archivo |
| `git checkout` / `switch` / `merge` | Archivos modificados, ramas y commits, con su `git diff` / `git log` / `git show` |
| `git log` | El historial de la rama en gráfico |
| `kill`, `ps` | Detalles del proceso: usuario, CPU, memoria, tiempo y comando |
| `export`, `unset`, `$VAR` | El valor de la variable |
| `pacman`, `yay`, `paru` | La ficha del paquete (`pacman -Si` / `yay -Si`) |

Dentro del buscador: `/` acepta la carpeta y sigue completando (rutas profundas) · `<` `>` cambian de grupo de resultados.

| Atajo | Acción |
|---|---|
| `Ctrl + R` | Busca en el historial (200 000 comandos compartidos entre terminales); `Enter` lo pega en la línea |
| `Ctrl + T` | Busca archivos (con `fd`, incluye ocultos) y pega la ruta; vista previa con bat / eza |
| `Alt + C` | Busca carpetas y entra en ella; vista previa del árbol con eza |
| `z dir` | Salta a la carpeta más usada que contenga «dir» (zoxide); `cd` sigue siendo el normal |
| `zi` | Elige entre tus carpetas más usadas con fzf y salta |
| `→` o `End` | Acepta la sugerencia gris del historial |
| ` comando` (espacio delante) | No se guarda en el historial |
| `ls` · `ll` · `la` · `lt` | eza: lista con iconos · larga con git · con ocultos · árbol de 2 niveles |
| `cat archivo` | Se muestra con bat (colores, sin paginador) |

## Modo Scrolling (solo en escritorios en modo scroll; en dwindle estas teclas no hacen nada)

`SUPER + izquierda / derecha` cambia de columna y `SUPER + arriba / abajo` de ventana dentro de la columna; `SUPER + SHIFT + flechas` mueve la ventana. Además:

| Teclas | Acción |
|---|---|
| `SUPER + CTRL + izquierda / derecha` | Mover la columna entera |
| `SUPER + coma / punto` | Unir la ventana a la columna anterior / siguiente, o sacarla de su columna si no está sola |
| `SUPER + P` | La ventana pasa a su propia columna |
| `SUPER + R` | Ciclar el ancho de la columna: 1/3, 1/2, 2/3, completo |
| `SUPER + C` | Centrar la columna |

## Teclado dentro de los paneles

| Panel | Teclas |
|---|---|
| Launcher Gravedad (`SUPER + Space`) | En reposo: `← →` gira la selección por su anillo · `↑ ↓` cambia de anillo · `Enter` abre · `Tab` va a su ventana · rueda: desplaza «Todas» · clic abre, clic central o `Esc` cierra. Buscando: `↑ ↓` elige · `Enter` abre · `Tab` recorre las lunas de terminal. Prefijos: `=` calculadora · `>` comando · `?` web · `:` emoji · `@` escritorio · `/` portapapeles |
| Portapapeles orbital (`/` o `SUPER + V`) | Escribir filtra · `← →` recorre · `Enter` pega · `Ctrl+P` fija · `Supr` borra · `Espacio` muestra un secreto · `Retroceso` con el campo vacío vuelve a las apps |
| Alt+Tab orbital | `Tab` / `Shift+Tab` (con Alt) · `← →` · `Q` cierra la ventana elegida · `1–5` solo ese escritorio · soltar Alt o `Enter` enfoca · `Esc` cancela |
| Escritorios (`SUPER + Tab`) | `← →` o `1–5` eligen · `Enter` va · arrastrar una ventana a otra tarjeta la mueve · `Esc` cierra |
| Lanzador orbital anterior (Gravedad apagado) | Escribir filtra (búsqueda difusa; el mejor resultado pasa al frente y el anillo se detiene) · `← →`, `↑ ↓`, `Tab` o la rueda giran el anillo · `Enter` lanza · `Ctrl+F` fija / quita de favoritos la app del frente · `Ctrl+I` sin resultados (o `+nombre`) abre la Tienda con la búsqueda · `=2*(3+4)` calcula (Enter copia) · `>comando` se ejecuta en Ghostty · `Esc` o clic fuera cierra |
| Isla de mando (`SUPER + D`, `SUPER + /`) | Escribir busca con el motor del launcher (prefijos `=` `>` `?` `@`; chip `IA` = preguntar a Claude en la terminal desplegable) · `↑ ↓` elige · `Enter` ejecuta · `Esc` borra la línea (otra vez: cierra) · sin texto: `← →` o la rueda pasan las tarjetas de la pila |
| Menú de energía | `← →` o `Tab` · `Enter`/`Espacio` ejecuta · `1–5` atajo directo · `Esc` cierra |
| Referencia de herdr (`SUPER + SHIFT + A`) | Escribir filtra · `Tab` cambia de pestaña (Atajos · Comandos · Conceptos y estados) · `↑ ↓` desplazar · `Esc` cierra |
| Atajos (`SUPER + F1`) | Escribir para filtrar por acción, grupo o tecla · `↑ ↓` desplazar · `Esc` cierra |
| Ajustes (`SUPER + F2`) | `1–4` estilo de barra A–D (en «Barra superior») · `Tab` / `Shift+Tab` cambian de página · `Esc` o clic fuera cierra |
| Capturas (`SUPER + SHIFT + S`) | `1–3` Región / Ventana / Pantalla · arrastrar dibuja (los tiradores ajustan) · `Espacio` + arrastrar mueve · `Enter` copia · `Esc` cierra |
| Portapapeles anterior (Gravedad apagado) | Escribir para filtrar · `↑ ↓` o `Tab` · `Enter` copia · `Supr` (con la búsqueda vacía) borra la entrada · `Esc` cierra |
| Popover Wi‑Fi | `Enter` en la contraseña conecta · `Esc` cierra |
| Taller (`SUPER + T`) | `Ctrl+Tab` / `Ctrl+Shift+Tab` cambia de pestaña · `↑ ↓` elige agente · `Tab` recorre controles · `Enter` enfoca al agente o activa un control · `Esc` cierra |
| Cualquier panel | `Esc` cierra |

## IPC (para scripts y atajos propios)

```sh
qs ipc call shell toggle dashboard   # dashboard, perf, wifi, bt, audio, battery, notifications, calendar,
qs ipc call shell open launcher      # launcher, power, clipboard, keybinds, wallpapers, store, settings
qs ipc call taller toggle            # open agentes|kanban|contenedores|git|revision · close · current
qs ipc call shell close
qs ipc call launcher clipboard       # el anillo del portapapeles (SUPER + V)
qs ipc call switcher next            # Alt+Tab orbital: next, prev, confirm, cancel
qs ipc call overview toggle          # vista general de escritorios (SUPER + Tab)
qs ipc call shell current            # imprime el panel abierto o "none"
qs ipc call debug toggle             # panel de diagnóstico de servicios (desarrollo)
qs ipc call settings motion 0        # sin animaciones (0), normal (1), lentas (2); -1 = seguir a KDE
qs ipc call settings current         # todos los ajustes (velocidad de animación y de dónde sale, estilo de barra…)
qs ipc call settings barStyle C      # estilo de barra A · B · C · D (cycleBarStyle = el siguiente)
qs ipc call settings islandContent window   # media · window · date
qs ipc call settings accent 0.6      # intensidad del acento 0–1 · metrics true|false · autohide true|false
qs ipc call shell nook ia            # la isla abierta en una pestaña (nook · apps · ia)
qs ipc call capture open region      # barra de capturas · screen = pantalla completa directa · shoot "x,y wxh" copy|save|ocr|annotate|record
qs ipc call focus start 25           # modo enfoque de 25 min · stop · toggle · remaining
qs ipc call idle state               # secuencia de inactividad: aviso activo y qué la inhibe · warn · resume · apply
qs ipc call commands list            # comandos largos en curso y terminados (los avisan los hooks de zsh)
qs ipc call osd preview capslock     # muestra un OSD sin cambiar nada (volume · mic · brightness · capslock · layout)
```

## Referencia completa de atajos de Hyprland

Generada de la configuración real (`scripts/gen-keybinds.sh --inject`, necesita Hyprland en marcha); es lo mismo que muestra `SUPER + F1`.

<!-- binds:begin (generado por scripts/gen-keybinds.sh desde hyprctl binds -j; no editar a mano) -->
### Agentes

| Atajo | Acción |
|---|---|
| `SUPER + A` | Abrir o enfocar herdr (escritorio 5) |
| `SUPER + SHIFT + A` | Atajos y funciones de herdr (referencia) |
| `SUPER + ALT + A` | Ver agentes y comandos en la isla |

### Aplicaciones

| Atajo | Acción |
|---|---|
| `SUPER + E` | Archivos (Dolphin) |
| `SUPER + Space` | Lanzador |
| `SUPER + Return` | Terminal (Ghostty) |
| `SUPER + grave` | Terminal desplegable |

### Capturas

| Atajo | Acción |
|---|---|
| `SHIFT + Print` · `SUPER + SHIFT + S` | Barra de capturas (región, ventana, pantalla) |
| `Print` | Pantalla completa (copiar y guardar) |

### Dock

| Atajo | Acción |
|---|---|
| `SUPER + X` | Fijar / liberar el dock |
| `SUPER + M` | Minimizar la ventana (escritorio especial) |

### Escritorios

| Atajo | Acción |
|---|---|
| `SUPER + SHIFT + 1` · `SUPER + SHIFT + 2` · `SUPER + SHIFT + 3` · `SUPER + SHIFT + 4` · `SUPER + SHIFT + 5` | Enviar la ventana al escritorio |
| `SUPER + 1` · `SUPER + 2` · `SUPER + 3` · `SUPER + 4` · `SUPER + 5` | Ir al escritorio |
| `SUPER + Tab` | Vista general (arrastrar ventanas entre escritorios) |

### Foco

| Atajo | Acción |
|---|---|
| `SUPER + down` · `SUPER + left` · `SUPER + right` · `SUPER + up` | Mover el foco |
| `SUPER + ALT + H` · `SUPER + ALT + J` · `SUPER + ALT + K` · `SUPER + ALT + L` | Mover el foco (Vim) |

### Multimedia

| Atajo | Acción |
|---|---|
| `XF86MonBrightnessDown` | Bajar brillo |
| `XF86AudioLowerVolume` | Bajar volumen |
| `XF86AudioPrev` | Pista anterior |
| `XF86AudioPause` · `XF86AudioPlay` | Reproducir / pausar |
| `XF86AudioNext` | Siguiente pista |
| `XF86AudioMute` | Silenciar |
| `XF86AudioMicMute` | Silenciar micrófono |
| `XF86MonBrightnessUp` | Subir brillo |
| `XF86AudioRaiseVolume` | Subir volumen |

### Ratón

| Atajo | Acción |
|---|---|
| `SUPER + mouse:272` | Arrastrar ventana |
| `SUPER + mouse:273` | Redimensionar ventana |

### Scrolling

| Atajo | Acción |
|---|---|
| `SUPER + R` | Ancho de columna (1/3, 1/2, 2/3, completo) |
| `SUPER + C` | Centrar la columna |
| `SUPER + CTRL + right` | Mover la columna a la derecha |
| `SUPER + CTRL + left` | Mover la columna a la izquierda |
| `SUPER + comma` | Unir la ventana a la columna anterior / sacarla de la columna |
| `SUPER + period` | Unir la ventana a la columna siguiente / sacarla de la columna |
| `SUPER + P` | Ventana a su propia columna |

### Shell

| Atajo | Acción |
|---|---|
| `SUPER + F2` | Ajustes |
| `SUPER + ALT + B` | Cambiar el estilo de la barra |
| `SUPER + F1` | Esta ayuda de atajos |
| `SUPER + SHIFT + W` | Fondo aleatorio |
| `SUPER + W` | Fondos de pantalla (orbital) |
| `SUPER + SHIFT + R` | Grabar pantalla (iniciar / parar) |
| `SUPER + slash` | Línea de mando de la isla |
| `SUPER + Escape` | Menú de energía |
| `SUPER + ALT + F` | Modo enfoque (45 min) |
| `SUPER + D` | Notch (Nook / Tray) |
| `SUPER + N` | Notificaciones |
| `SUPER + SHIFT + V` · `SUPER + V` | Portapapeles (anillo; Enter pega) |
| `SUPER + I` | Tienda de apps (pacman + AUR) |

### Sistema

| Atajo | Acción |
|---|---|
| `SUPER + L` | Bloquear la sesión |

### Teclado

| Atajo | Acción |
|---|---|
| `SUPER + ALT + Space` | Cambiar distribución (US / LA) |

### Ventanas

| Atajo | Acción |
|---|---|
| `ALT + SHIFT + Tab` | Alt+Tab orbital: anterior |
| `ALT + Tab` | Alt+Tab orbital: siguiente |
| `ALT + Alt_L` | Alt+Tab orbital: soltar Alt confirma |
| `SUPER + SHIFT + Space` | Alternar flotante |
| `SUPER + CTRL + T` | Alternar modo Dwindle / Scrolling |
| `SUPER + Q` | Cerrar |
| `SUPER + F` | Maximizar / restaurar |
| `SUPER + SHIFT + down` · `SUPER + SHIFT + left` · `SUPER + SHIFT + right` · `SUPER + SHIFT + up` | Mover la ventana |
| `SUPER + SHIFT + H` · `SUPER + SHIFT + J` · `SUPER + SHIFT + K` · `SUPER + SHIFT + L` | Mover la ventana (Vim) |
| `SUPER + SHIFT + F` | Pantalla completa |
<!-- binds:end -->
