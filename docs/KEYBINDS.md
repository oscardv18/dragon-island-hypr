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
| `SUPER + W` | Selector de fondos de pantalla (imágenes, GIF y vídeo) |
| `SUPER + SHIFT + W` | Fondo aleatorio |
| `SUPER + SHIFT + R` | Grabar la pantalla (elige la salida; otra vez para parar). La cápsula roja de la barra también para |
| `SUPER + I` | Tienda de apps (pacman + AUR). También: lanzador → `+nombre` |
| `SUPER + SHIFT + A` | Referencia de herdr: atajos (los de fábrica y los que cambiaste), comandos de la CLI y estados de los agentes. Solo lectura |
| `SUPER + A` | Agentes: abre herdr en el escritorio 5 («agentes») o, si ya hay una ventana, la enfoca. Las sesiones sobreviven al cerrar la ventana |
| `SUPER + N` | Calendario + notificaciones + actualizaciones (el popover del reloj) |
| `SUPER + Escape` | Menú de energía |
| `SUPER + L` | Bloquear (`loginctl lock-session` → hyprlock) |
| `Print` | Captura de pantalla completa |
| `SUPER + SHIFT + S` | Captura de una región |
| `SUPER + SHIFT + V` | Historial del portapapeles (panel de Quickshell, cliphist) |
| `SUPER + F1` | Ayuda: panel con todos los atajos de Hyprland |

## Ventanas

| Atajo | Acción |
|---|---|
| `SUPER + Q` | Cerrar ventana |
| `SUPER + F` | Maximizar / restaurar (conserva los huecos) |
| `SUPER + SHIFT + F` | Pantalla completa real |
| `SUPER + V` | Alternar flotante |
| `SUPER + T` | Alternar el modo de mosaico del escritorio: **Dwindle** (árbol, por defecto) ↔ **Scrolling** (columnas en una cinta horizontal, layout nativo de Hyprland 0.56). Cada escritorio recuerda el suyo (`~/.local/state/dragon-island/tiling.json`); también la cápsula `DWINDLE` / `SCROLL` de la barra y `qs ipc call tiling toggle\|set dwindle\|set scrolling\|get` |
| `SUPER + ←↑→↓` | Mover el foco |
| `SUPER + ALT + H/J/K/L` | Mover el foco (estilo Vim) |
| `SUPER + SHIFT + ←↑→↓` · `SUPER + SHIFT + H/J/K/L` | Mover la ventana |
| `SUPER + arrastrar con clic izquierdo` | Mover ventana |
| `SUPER + arrastrar con clic derecho` | Redimensionar ventana |
| Doble clic en la barra de título (hyprbars) | Maximizar / restaurar |

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
| `ALT + SHIFT` | Cambiar de distribución (`grp:alt_shift_toggle`, del propio xkb) |
| `SUPER + ALT + Space` | Cambiar de distribución (`hyprctl switchxkblayout all next`) |
| Clic en la cápsula `US` / `LA` (isla derecha, antes de Wi‑Fi) | Siguiente distribución |

El bloqueo (hyprlock) usa las mismas dos distribuciones: `ALT + SHIFT` también funciona al escribir la contraseña y bajo el campo se ve cuál está activa.

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

## Tienda de apps (SUPER + I)

| Tecla | Acción |
|---|---|
| Escribir | Buscar en repositorios oficiales y AUR (200 ms de espera) / filtrar la pestaña actual |
| `↑ ↓` | Mover por la lista (los detalles del enfocado cargan a los 300 ms) |
| `Tab` (o `Espacio` con el campo vacío) | Marcar / desmarcar y bajar, como fzf |
| `Enter` | Instalar (Buscar), eliminar con confirmación (Instalados), actualizar todo (Actualizaciones) |
| `Esc` | Cerrar el visor / el diálogo; si no hay, cerrar la Tienda |

Desde el lanzador orbital: `+hypr` + Enter abre la Tienda buscando «hypr». Por IPC: `qs ipc call shell toggle store`.

## Fondos de pantalla (SUPER + W)

| Tecla | Acción |
|---|---|
| Escribir | Filtrar por nombre |
| `←↑↓→` | Mover la selección (vista previa grande del seleccionado o del que tiene el cursor encima) |
| `Enter` / clic | Aplicar el fondo |
| `Esc` | Cerrar |

Por IPC: `qs ipc call wallpaper toggle | set <ruta> | random | next | current`.

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
| Botón degradado (izquierda) | Lanzador | Clic derecho: dashboard |
| Píldora de escritorio (con los iconos de sus apps) | Ir a ese escritorio | Rueda: anterior / siguiente · ratón encima: vista previa con miniaturas de sus ventanas (clic en una = enfocarla) |
| Título de la ventana activa | | Ratón encima: acciones — cerrar · flotar · fijar (si flota) · mover a un escritorio |
| Indicador de submap (izquierda) | | Aparece solo con un submap activo |
| Rendimiento (CPU % + RAM en una sola píldora) | Popover Rendimiento (CPU de los últimos 30 s, núcleos, RAM, GPU, temperatura, procesos, perfil de energía) | Nada se expande con el ratón |
| Cápsula `US` / `LA` | Siguiente distribución de teclado | |
| Wi‑Fi · Bluetooth · Batería | Su popover | rueda sobre la batería: brillo ±5 % (la velocidad de bajada / subida está en el popover de Wi‑Fi) |
| Cápsulas contextuales (solo cuando aplican) | Micrófono / cámara / pantalla: lista de apps · grabación: parar · VPN: abre Proton VPN · auriculares: Bluetooth · cafeína y No molestar: alternar · actualizaciones: abre Ghostty con la actualización · red: Rendimiento | Las que no caben se agrupan en `+N` (ratón encima: despliega los iconos) |
| Volumen | Popover Sonido | Rueda: ±5 % · clic derecho o central: silenciar |
| Iconos de la bandeja | Acción principal de la app (o su menú si solo tiene menú) | Derecho: menú · central: acción secundaria · rueda: desplazar |
| Reloj (marcadores: No molestar · sin leer · actualizaciones) | Calendario, notificaciones y actualizaciones en un solo popover | Clic derecho: No molestar |
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
| Lanzador orbital | Escribir filtra (búsqueda difusa; el mejor resultado pasa al frente y el anillo se detiene) · `← →`, `↑ ↓`, `Tab` o la rueda giran el anillo · `Enter` lanza · `Ctrl+F` fija / quita de favoritos la app del frente · `Ctrl+I` sin resultados (o `+nombre`) abre la Tienda con la búsqueda · `=2*(3+4)` calcula (Enter copia) · `>comando` se ejecuta en Ghostty · `Esc` o clic fuera cierra |
| Menú de energía | `← →` o `Tab` · `Enter`/`Espacio` ejecuta · `1–5` atajo directo · `Esc` cierra |
| Referencia de herdr (`SUPER + SHIFT + A`) | Escribir filtra · `Tab` cambia de pestaña (Atajos · Comandos · Conceptos y estados) · `↑ ↓` desplazar · `Esc` cierra |
| Atajos (`SUPER + F1`) | Escribir para filtrar por acción, grupo o tecla · `↑ ↓` desplazar · `Esc` cierra |
| Portapapeles | Escribir para filtrar · `↑ ↓` o `Tab` · `Enter` copia · `Supr` (con la búsqueda vacía) borra la entrada · `Esc` cierra |
| Popover Wi‑Fi | `Enter` en la contraseña conecta · `Esc` cierra |
| Cualquier panel | `Esc` cierra |

## IPC (para scripts y atajos propios)

```sh
qs ipc call shell toggle dashboard   # dashboard, perf, wifi, bt, audio, battery, notifications, calendar,
qs ipc call shell open launcher      # launcher, power, clipboard, keybinds, wallpapers, store
qs ipc call shell close
qs ipc call shell current            # imprime el panel abierto o "none"
qs ipc call debug toggle             # panel de diagnóstico de servicios (desarrollo)
qs ipc call settings motion 0        # sin animaciones (0), normal (1), lentas (2); -1 = seguir a KDE
qs ipc call settings current         # velocidad de animación actual y de dónde sale
```

## Referencia completa de atajos de Hyprland

Generada de la configuración real (`scripts/gen-keybinds.sh --inject`, necesita Hyprland en marcha); es lo mismo que muestra `SUPER + F1`.

<!-- binds:begin (generado por scripts/gen-keybinds.sh desde hyprctl binds -j; no editar a mano) -->
### Agentes

| Atajo | Acción |
|---|---|
| `SUPER + A` | Abrir o enfocar herdr (escritorio 5) |

### Aplicaciones

| Atajo | Acción |
|---|---|
| `SUPER + E` | Archivos (Dolphin) |
| `SUPER + Space` | Lanzador |
| `SUPER + Return` | Terminal (Ghostty) |

### Capturas

| Atajo | Acción |
|---|---|
| `Print` | Pantalla completa |
| `SUPER + SHIFT + S` | Región |

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

### Shell

| Atajo | Acción |
|---|---|
| `SUPER + F1` | Esta ayuda de atajos |
| `SUPER + SHIFT + W` | Fondo aleatorio |
| `SUPER + W` | Fondos de pantalla |
| `SUPER + SHIFT + R` | Grabar pantalla (iniciar / parar) |
| `SUPER + SHIFT + V` | Historial del portapapeles |
| `SUPER + Escape` | Menú de energía |
| `SUPER + D` | Notch (Nook / Tray) |
| `SUPER + N` | Notificaciones |
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
| `SUPER + V` | Alternar flotante |
| `SUPER + Q` | Cerrar |
| `SUPER + F` | Maximizar / restaurar |
| `SUPER + SHIFT + down` · `SUPER + SHIFT + left` · `SUPER + SHIFT + right` · `SUPER + SHIFT + up` | Mover la ventana |
| `SUPER + SHIFT + H` · `SUPER + SHIFT + J` · `SUPER + SHIFT + K` · `SUPER + SHIFT + L` | Mover la ventana (Vim) |
| `SUPER + SHIFT + F` | Pantalla completa |
<!-- binds:end -->
