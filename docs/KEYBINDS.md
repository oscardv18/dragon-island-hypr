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
| `SUPER + N` | Calendario + notificaciones + actualizaciones (el popover del reloj) |
| `SUPER + Escape` | Tienda (`SUPER + I`) | Escribir busca en repos y AUR · `↑ ↓` · `Tab` (o `Espacio` con el campo vacío) marca · `Enter` instala / elimina / actualiza según la pestaña · `Esc` cierra el visor o el diálogo y luego la Tienda |
| Fondos de pantalla (`SUPER + W`) | Escribir filtra · `← → ↑ ↓` · `Enter` o clic aplica · `Esc` cierra |
| Menú de energía |
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

## Teclado dentro de los paneles

| Panel | Teclas |
|---|---|
| Lanzador orbital | Escribir filtra (búsqueda difusa; el mejor resultado pasa al frente y el anillo se detiene) · `← →`, `↑ ↓`, `Tab` o la rueda giran el anillo · `Enter` lanza · clic derecho en un icono = favorito · `=2*(3+4)` calcula (Enter copia) · `>comando` se ejecuta en Ghostty · `Esc` o clic fuera cierra |
| Menú de energía | `← →` o `Tab` · `Enter`/`Espacio` ejecuta · `1–5` atajo directo · `Esc` cierra |
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
