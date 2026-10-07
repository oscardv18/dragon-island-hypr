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
| `SUPER + N` | Centro de notificaciones |
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
| Píldora de escritorio | Ir a ese escritorio | Rueda: anterior / siguiente |
| CPU / RAM | Popover Rendimiento | |
| Cápsula `US` / `LA` | Siguiente distribución de teclado | |
| Wi‑Fi · Bluetooth · Batería | Su popover | |
| Volumen | Popover Sonido | Rueda: ±5 % · clic derecho o central: silenciar |
| Iconos de la bandeja | Acción principal de la app (o su menú si solo tiene menú) | Derecho: menú · central: acción secundaria · rueda: desplazar |
| Campana (punto = no leídas) | Centro de notificaciones | Clic derecho: No molestar |
| Reloj | Calendario | Clic en un día: su agenda (khal) · rueda: cambiar de mes |
| Popup de notificación | Acción por defecto (o cerrar el popup) | Central: descartar · pasar el ratón: no caduca |
| Isla cerrada | Dashboard | Música: clic central = play/pausa |
| Mosaicos del dashboard | Activar / desactivar | Clic derecho en Wi‑Fi, Bluetooth o No molestar: abre su popover |
| Fuera de un panel / `Esc` | Cierra el panel | |

## Teclado dentro de los paneles

| Panel | Teclas |
|---|---|
| Lanzador | Escribir para filtrar (búsqueda difusa) · `↑ ↓` o `Tab` para moverse · `Enter` abre · `Esc` cierra |
| Menú de energía | `← →` o `Tab` · `Enter`/`Espacio` ejecuta · `1–5` atajo directo · `Esc` cierra |
| Atajos (`SUPER + F1`) | Escribir para filtrar por acción, grupo o tecla · `↑ ↓` desplazar · `Esc` cierra |
| Portapapeles | Escribir para filtrar · `↑ ↓` o `Tab` · `Enter` copia · `Supr` (con la búsqueda vacía) borra la entrada · `Esc` cierra |
| Popover Wi‑Fi | `Enter` en la contraseña conecta · `Esc` cierra |
| Cualquier panel | `Esc` cierra |

## IPC (para scripts y atajos propios)

```sh
qs ipc call shell toggle dashboard   # dashboard, perf, wifi, bt, audio, battery,
qs ipc call shell open launcher      # notifications, calendar, launcher, power, clipboard, keybinds
qs ipc call shell close
qs ipc call shell current            # imprime el panel abierto o "none"
qs ipc call debug toggle             # panel de diagnóstico de servicios (desarrollo)
qs ipc call settings motion 0        # sin animaciones (0), normal (1), lentas (2); -1 = seguir a KDE
qs ipc call settings current         # velocidad de animación actual y de dónde sale
```
