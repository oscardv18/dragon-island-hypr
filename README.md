# dragon-island

Escritorio **Hyprland + Quickshell** para EndeavourOS, instalado como **segunda sesión junto a KDE Plasma** (Plasma no se toca). Tiene una barra flotante de tres islas, una **Dynamic Island** que se despliega en dashboard, popovers para cada indicador, centro de notificaciones, lanzador, portapapeles y menú de energía. Usa la paleta Sweet / Garuda Dragonized.

> **Capturas pendientes.** Se añadirán desde EndeavourOS (ver [docs/TESTING.md](docs/TESTING.md)):
>
> | Vista | Archivo |
> |---|---|
> | Escritorio con la barra y la isla cerrada | `docs/screenshots/desktop.png` *(pendiente)* |
> | Dashboard abierto | `docs/screenshots/dashboard.png` *(pendiente)* |
> | Popovers (Wi‑Fi, Sonido, Calendario…) | `docs/screenshots/popovers.png` *(pendiente)* |
> | Lanzador y menú de energía | `docs/screenshots/launcher.png` *(pendiente)* |

## Qué incluye

| Pieza | Detalle |
|---|---|
| **Hyprland 0.56** | Configuración en **Lua** (`config/hypr/*.lua`), borde con degradado, blur, animaciones, reglas de capa para el shell |
| **Plugins** | `hyprbars` (barra de título de 30 px, botones a la izquierda) y `hyprfocus`, instalados con `hyprpm` en el primer inicio |
| **Barra** | Isla izquierda (lanzador, escritorios 1–5, ventana activa) e isla derecha (CPU, RAM, Wi‑Fi, Bluetooth, volumen, batería, bandeja del sistema, notificaciones, reloj). Los huecos dejan pasar el clic |
| **Dynamic Island** | Cae desde arriba al arrancar. Muestra OSD, cambio de escritorio, música o el reloj. Al pulsarla se "derrama" el dashboard |
| **Notificaciones** | Solo como popups (hasta 3, bajo la isla derecha) y en el centro de notificaciones |
| **Dashboard** | Saludo, música, volumen y brillo, 6 interruptores rápidos, perfil de energía, sistema y últimas notificaciones |
| **Popovers** | Rendimiento, Wi‑Fi, Bluetooth, Sonido (con mezclador por app), Batería, Notificaciones y Calendario (eventos de **khal**) |
| **Extras** | Lanzador con búsqueda difusa, historial del portapapeles con miniaturas, menú de energía, brillo de monitores externos por DDC/CI, movimiento reducido, fondo de pantalla propio, hyprlock, hypridle, kitty con el tema |

Versiones de referencia: Hyprland 0.56.2, Quickshell 0.3.1 y gum 2.x (Arch `extra`, octubre de 2026).

## Instalación

Requisitos: EndeavourOS o Arch, usuario normal con `sudo`, conexión a internet. Se recomienda tener KDE Plasma instalado, aunque no es obligatorio.

```sh
git clone <este-repo> ~/dragon-island-hypr
cd ~/dragon-island-hypr
./install.sh --dry-run   # ver qué haría, sin cambiar nada
./install.sh             # instalación interactiva (gum)
```

El instalador:

1. Comprueba el sistema y ofrece `pacman -Syu` antes de instalar nada.
2. Te deja elegir los componentes: `core` (Hyprland y herramientas), `shell` (Quickshell y servicios), `plugins` (compilación de hyprpm), `fonts` y `services` (NetworkManager, bluetooth, power-profiles-daemon).
3. Instala los paquetes de [`packages/pacman.txt`](packages/pacman.txt) y [`packages/aur.txt`](packages/aur.txt) (con `yay` o `paru`).
4. Enlaza (o copia) `config/hypr`, `config/kitty` y `config/quickshell` en `~/.config`. Lo que ya existía va a `~/.local/state/dragon-island/backups/<fecha>/`.
5. Es **idempotente**: si lo ejecutas otra vez, no cambia nada.

Después, cierra sesión, elige **Hyprland** en SDDM y entra. En el primer inicio se abre una terminal que compila hyprbars y hyprfocus (`hyprpm` pedirá tu contraseña).

Fondo de pantalla: el instalador pone el de dragon-island en `~/.local/share/dragon-island/wallpaper.jpg` (solo si no existe). Para usar el tuyo, sustituye ese archivo por otro JPEG.

### Calendario (khal)

El popover del calendario muestra los eventos de [khal](https://khal.readthedocs.io), que el instalador ya incluye. Configúralo una vez:

```sh
khal configure                       # crea ~/.config/khal/config y un calendario local
khal new hoy 18:00 19:00 Prueba      # comprueba que funciona
```

Para sincronizar con Google, Nextcloud u otro CalDAV, usa `vdirsyncer` y apunta khal a esa carpeta. Los eventos se recargan cada 10 minutos y al abrir el calendario.

### Brillo de monitores externos

El slider de brillo controla el monitor en el que lo usas: la retroiluminación en un portátil y **DDC/CI** (`ddcutil`) en los monitores externos. Tras instalar, reinicia una vez para que se cargue el módulo `i2c-dev`. El monitor debe tener DDC/CI activado en su menú.

### Opciones

```sh
./install.sh --yes        # sin preguntas (valores por defecto)
./install.sh --uninstall  # quita los enlaces y restaura los respaldos (no desinstala paquetes)
```

Registro de la instalación: `~/.local/state/dragon-island/install.log`.

## Uso

Los atajos y los controles con el ratón están en **[docs/KEYBINDS.md](docs/KEYBINDS.md)**. Los esenciales:

| Atajo | Acción |
|---|---|
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Lanzador |
| `SUPER + D` | Dashboard |
| `SUPER + N` | Notificaciones |
| `SUPER + Escape` | Menú de energía |
| `SUPER + L` | Bloquear |
| `SUPER + F1` | **Ayuda: todos los atajos** (panel en pantalla) |

El shell se controla también por IPC: `qs ipc call shell toggle <panel>`. Los paneles disponibles son `dashboard`, `perf`, `wifi`, `bt`, `audio`, `battery`, `notifications`, `calendar`, `launcher` y `power`.

## Estructura

```
config/hypr/            hyprland.lua + módulos (monitors, env, input, look, animations, rules, binds, plugins, autostart)
config/quickshell/
  shell.qml             una barra y una isla por monitor
  Theme.qml             todos los colores, tamaños, fuentes y duraciones (spec)
  Icons.qml             glifos Nerd Font
  ShellState.qml        panel abierto (uno a la vez) + IPC "shell"
  services/             datos: Hypr, Media, Audio, Network, Bluetooth, Power, Brightness,
                        SysStats, Notifs, Osd, Toggles, Apps, Clock, Session, IslandState,
                        Settings, Clipboard, Tray, Keybinds
  components/           Capsule, Slider, ToggleTile, PopoverFrame, ListRow…
  modules/              bar · island (+ dashboard) · popovers · notifications · launcher · power · clipboard · keybinds
  debug/DebugPanel.qml  diagnóstico (qs ipc call debug toggle)
assets/wallpapers/      fondo por defecto
installer/ install.sh packages/ docs/
```

Reglas del código (ver la skill `dragon-island`):

- La interfaz solo enlaza con propiedades de los servicios y llama a sus funciones; nunca ejecuta comandos.
- Nada de colores fijos en el código: todo sale de `Theme`.

## Desarrollo

```sh
qs -p ~/.config/quickshell     # recarga en caliente al guardar
qs log -f                      # errores con archivo:línea
qs ipc call debug toggle       # valores en vivo de todos los servicios
hyprctl configerrors           # errores de la config de Hyprland
```

Velocidad de las animaciones (movimiento reducido):

```sh
qs ipc call settings motion 0     # sin animaciones
qs ipc call settings motion 1.5   # más lentas
qs ipc call settings motion -1    # seguir a Plasma (Velocidad de animación)
```

Se guarda en `~/.config/dragon-island/settings.json`. Sin ese valor, se usa la velocidad de animación de Plasma.

## Pruebas

Checklist completo para hacer en EndeavourOS: **[docs/TESTING.md](docs/TESTING.md)**.
