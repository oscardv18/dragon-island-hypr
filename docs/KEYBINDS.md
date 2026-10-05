# dragon-island — Atajos de Teclado (Keybindings)

Todos los atajos principales usan la tecla modificadora **SUPER** (tecla Windows).

---

## Aplicaciones y Sistema

| Combinación | Acción | Descripción |
|---|---|---|
| `SUPER + Return` | Terminal | Abre `kitty` con tema Dragonized |
| `SUPER + Space` | Lanzador de aplicaciones | Alterna lanzador Quickshell (`shell toggle launcher`) |
| `SUPER + E` | Explorador de archivos | Abre `dolphin` (KDE Dolphin) |
| `SUPER + Q` | Cerrar ventana | Cierra la ventana activa grácilmente (`hl.dsp.window.close()`) |
| `SUPER + F` | Maximizar ventana | Alterna maximizado conservando márgenes |
| `SUPER + SHIFT + F` | Pantalla completa | Alterna fullscreen completo |
| `SUPER + V` | Ventana flotante | Alterna modo flotante en la ventana activa |
| `SUPER + L` | Bloqueo de pantalla | Ejecuta `loginctl lock-session` (dispara `hyprlock`) |
| `SUPER + Escape` | Menú de energía | Alterna menú de apagado/reinicio Quickshell (`shell toggle power`) |

---

## Shell y Paneles Interactivos (Quickshell)

| Combinación | Panel Quickshell | IPC invocado |
|---|---|---|
| `SUPER + Space` | Lanzador | `qs ipc call shell toggle launcher` |
| `SUPER + D` | Dashboard | `qs ipc call shell toggle dashboard` |
| `SUPER + N` | Centro de notificaciones | `qs ipc call shell toggle notifications` |
| `SUPER + Escape` | Menú de energía | `qs ipc call shell toggle power` |

---

## Navegación y Foco

> [!NOTE]
> Para evitar conflictos con `SUPER + L` (bloqueo de sesión), el movimiento de foco estilo Vim utiliza `SUPER + ALT + H/J/K/L`. Las teclas de flechas están disponibles directamente con `SUPER`.

| Combinación | Acción |
|---|---|
| `SUPER + Left / Right / Up / Down` | Mover foco a la izquierda / derecha / arriba / abajo |
| `SUPER + ALT + H / L / K / J` | Mover foco a la izquierda / derecha / arriba / abajo (Vim) |
| `SUPER + SHIFT + Left / Right / Up / Down` | Mover ventana hacia la dirección indicada |
| `SUPER + SHIFT + H / L / K / J` | Mover ventana hacia la dirección indicada (Vim) |
| `SUPER + 1` .. `5` | Cambiar al espacio de trabajo 1 a 5 |
| `SUPER + SHIFT + 1` .. `5` | Mover la ventana activa al espacio de trabajo 1 a 5 |

---

## Ratón

| Combinación | Acción |
|---|---|
| `SUPER + Clic Izquierdo (arrastrar)` | Mover ventana flotante (`mouse:272`) |
| `SUPER + Clic Derecho (arrastrar)` | Redimensionar ventana flotante (`mouse:273`) |

---

## Capturas y Portapapeles

| Combinación | Acción | Comando |
|---|---|---|
| `Print` | Captura de pantalla completa | `grimblast --notify copysave output` |
| `SUPER + SHIFT + S` | Captura de región seleccionada | `grimblast --notify copysave area` |
| `SUPER + SHIFT + V` | Historial de portapapeles | `cliphist list \| rofi -dmenu \| cliphist decode \| wl-copy` |

---

## Teclas Multimedia y Brillo (XF86)

Funcionan incluso con la pantalla bloqueada (`locked = true`):

| Tecla | Acción |
|---|---|
| `XF86AudioRaiseVolume` | Subir volumen (+5%) vía `wpctl` |
| `XF86AudioLowerVolume` | Bajar volumen (-5%) vía `wpctl` |
| `XF86AudioMute` | Silenciar / activar audio vía `wpctl` |
| `XF86AudioMicMute` | Silenciar / activar micrófono vía `wpctl` |
| `XF86MonBrightnessUp` | Subir brillo (+5%) vía `brightnessctl` |
| `XF86MonBrightnessDown` | Bajar brillo (-5%) vía `brightnessctl` |
| `XF86AudioPlay` / `Pause` | Reproducir / Pausar vía `playerctl` |
| `XF86AudioNext` | Siguiente pista vía `playerctl` |
| `XF86AudioPrev` | Pista anterior vía `playerctl` |
