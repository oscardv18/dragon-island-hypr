# dragon-island

Escritorio **Hyprland + Quickshell** para EndeavourOS, instalado como **segunda sesión junto a KDE Plasma** (Plasma no se toca). Tiene una barra flotante de tres islas, un **notch** pegado al borde superior que se expande (estilo NotchNook), popovers para cada indicador, centro de notificaciones, lanzador, portapapeles y menú de energía. Usa la paleta Sweet / Garuda Dragonized.

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
| **Notch** | Negro opaco pegado al borde superior, con orejas cóncavas; emerge del borde al arrancar y nunca se superpone a las islas de la barra. Al pasar el ratón se asoma (peek). Muestra OSD, notificación, cambio de escritorio, música o el reloj. Al pulsarlo (o SUPER+D) crece hasta ≈720×230 con las pestañas Nook y Tray |
| **Notificaciones** | Popups (hasta 3, bajo la isla derecha), un peek del notch y el centro de notificaciones |
| **Notch expandido** | Pestaña Nook: música, tira de calendario, toggles rápidos (Wi‑Fi, Bluetooth, No molestar, luz nocturna) y estadísticas. Pestaña Tray: la bandeja del sistema |
| **Popovers** | Rendimiento, Wi‑Fi, Bluetooth, Sonido (con mezclador por app), Batería, Notificaciones y Calendario (eventos de **khal**) |
| **Lanzador orbital** | `SUPER + Espacio`: un planeta de cristal con la búsqueda y un anillo de iconos que gira alrededor (los de atrás pasan detrás del planeta). Búsqueda difusa con memoria de uso, favoritos (clic derecho), `=cálculo` y `>comando` |
| **Dock en arco** | Una semidona de cristal (una franja como las islas, hueca por dentro, con las apps en cápsulas) que emerge del borde inferior (o izquierdo / derecho) con las apps fijadas, las abiertas y las minimizadas, puntos de ventanas, insignias de notificaciones, ampliación al pasar el ratón y abanico de descargas. Aparece cuando el escritorio no tiene ventanas en mosaico |
| **Islas dinámicas** | Las cápsulas aparecen solo cuando importan: privacidad (micrófono / cámara / pantalla compartida), grabación, VPN, batería de auriculares, cafeína, No molestar, actualizaciones y velocidad de red; si no caben se agrupan en `+N`. Escritorios con los iconos de sus apps y vista previa con miniaturas; el título de la ventana activa se convierte en acciones |
| **Extras** | Lanzador con búsqueda difusa, historial del portapapeles con miniaturas, menú de energía, brillo de monitores externos por DDC/CI, movimiento reducido, fondo de pantalla propio, hyprlock, hypridle, Ghostty con el tema (cristal líquido) |

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
2. Te deja elegir los componentes: `core` (Hyprland y herramientas), `shell` (Quickshell y servicios), `plugins` (compilación de hyprpm), `tools` (opcionales: Seahorse), `fonts` y `services` (NetworkManager, bluetooth, power-profiles-daemon).
3. Instala los paquetes de [`packages/pacman.txt`](packages/pacman.txt) y [`packages/aur.txt`](packages/aur.txt) (con `yay` o `paru`).
4. Enlaza (o copia) `config/hypr`, `config/ghostty`, `config/kitty` y `config/quickshell` en `~/.config`, además de `~/.config/brave-flags.conf` y `~/.config/xdg-desktop-portal/hyprland-portals.conf` (ver [Llavero](#llavero--contraseñas)). Lo que ya existía va a `~/.local/state/dragon-island/backups/<fecha>/`.
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

### Llavero / contraseñas

Plasma y Hyprland usan **un único llavero: gnome-keyring**. Es el único proveedor del servicio de secretos (`org.freedesktop.secrets`). Lo usan Brave, Proton VPN y las apps con libsecret o qtkeychain (también `plasma-nm`). Proton VPN y `plasma-nm` dependen de él: **no lo desinstales**.

El gestor de inicio lo arranca y lo desbloquea con la contraseña que escribes al entrar. Lo hace el módulo PAM `pam_gnome_keyring`: en Plasma Login (`/usr/lib/pam.d/plasmalogin`) ya viene incluido, y en SDDM lo trae su archivo PAM de Arch. En Hyprland no hay que arrancar nada.

Requisitos:

- El llavero **`login`** debe tener **la misma contraseña que tu usuario**. Si no coinciden, PAM no puede abrirlo y te la pedirá.
- **Sin inicio de sesión automático:** sin contraseña escrita, PAM no tiene con qué abrir el llavero.
- **KWallet no debe ofrecer el servicio de secretos.** Queda solo para Plasma. Si no, compite con gnome-keyring por el mismo nombre de D-Bus. Desactívalo una vez y luego cierra sesión:

  ```sh
  kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false
  ```

  Equivale a desmarcar *Usar KWallet para la interfaz Secret Service* en *Configuración del sistema → Cartera de KDE*. Esa página la instala `kwalletmanager`. El instalador avisa si sigue activo.

Comprobarlo con **Seahorse** (*Contraseñas y claves*, componente `tools`):

1. En *Contraseñas* aparece **Inicio de sesión** (`login`), abierto (candado sin cerrar) nada más entrar.
2. Clic derecho → *Establecer como predeterminado*, si no lo es ya.
3. Si te pidió la contraseña al entrar, la del llavero no coincide con la de tu usuario. Clic derecho → *Cambiar contraseña*: pon la antigua del llavero y, como nueva, la de tu usuario.

Desde la terminal también puedes ver quién da el servicio:

```sh
busctl --user status org.freedesktop.secrets | grep -E '^(PID|Comm)='   # debe ser gnome-keyring-d
```

Detalles:

- **Brave:** `config/brave/brave-flags.conf` se despliega en `~/.config/brave-flags.conf` con `--password-store=gnome-libsecret`. El lanzador de `brave-bin` lee ese archivo. **Antes de usarlo, exporta tus contraseñas** (`brave://password-manager/settings` → *Exportar contraseñas*). Brave guardaba su clave en KWallet: con el nuevo almacén ya no podrá descifrar lo anterior, así que se cierran las sesiones de las webs y las contraseñas se pierden. Después impórtalas desde la misma página.
- **Proton VPN:** guarda su sesión en `login`. Si ya la tenía ahí, la recuerda en las dos sesiones.
- **Portal Secret:** `config/xdg-desktop-portal/hyprland-portals.conf` (en `~/.config/xdg-desktop-portal/`) envía el portal *Secret* a gnome-keyring en Hyprland, porque ni `hyprland` ni `gtk` lo implementan.
- **Bandeja:** Proton VPN y otras apps se minimizan en la bandeja de la isla derecha (entre la campana y el reloj).

### Actualizar

**`git pull` no basta: usa `./update.sh`** (o `./install.sh --update`). Hace `git pull --ff-only` (se detiene si hay cambios locales sin commit), ejecuta las **migraciones** pendientes de `migrations/` (una sola vez cada una, registradas en `~/.local/state/dragon-island/migrations.done`), instala solo los paquetes que falten (nunca `-Syu` sin preguntar), redespliega los archivos que cambiaron si usas copias (y ofrece pasarlas a symlink), ofrece plugins nuevos como hyprglass (hyprpm en primer plano) y recarga en vivo (`hyprpm reload -n`, `hyprctl reload`, reinicio de Quickshell) sin cerrar sesión. Al final resume migraciones, paquetes, archivos, backups y `hyprctl configerrors`.

```sh
./update.sh --dry-run     # muestra lo que haría
./update.sh --yes         # sin preguntas (no instala plugins nuevos)
```

Regla del proyecto: todo cambio que afecte a sistemas ya instalados viene con su migración (`migrations/README.md`).

### Opciones

```sh
./install.sh --yes        # sin preguntas (valores por defecto)
./install.sh --glass      # incluye el componente opcional «Efecto cristal (hyprglass)»
./install.sh --zsh        # incluye el componente opcional «Shell: zsh + starship»
./install.sh --update     # alias de ./update.sh
./install.sh --uninstall  # quita los enlaces y restaura los respaldos (no desinstala paquetes)
```

Registro de la instalación: `~/.local/state/dragon-island/install.log`.

## Uso

Los atajos y los controles con el ratón están en **[docs/KEYBINDS.md](docs/KEYBINDS.md)**. Los esenciales:

| Atajo | Acción |
|---|---|
| `SUPER + Return` | Terminal |
| `SUPER + Space` | Lanzador |
| `SUPER + D` | Notch expandido (Nook · Tray) |
| `SUPER + W` · `SUPER + SHIFT + W` | Selector de fondos · fondo aleatorio |
| `SUPER + ALT + Space` · `ALT + SHIFT` | Cambiar distribución de teclado (US / LA) |
| `SUPER + N` | Notificaciones |
| `SUPER + Escape` | Menú de energía |
| `SUPER + L` | Bloquear |
| `SUPER + F1` | **Ayuda: todos los atajos** (panel en pantalla) |

El shell se controla también por IPC: `qs ipc call shell toggle <panel>`. Los paneles disponibles son `dashboard`, `perf`, `wifi`, `bt`, `audio`, `battery`, `notifications`, `calendar`, `launcher` y `power`.

## Fondos de pantalla

`SUPER + W` abre el selector (pestañas Todos / Imágenes / Animados, búsqueda, miniaturas 16:9 con badges GIF y VIDEO, vista previa grande, «Aleatorio» y «Abrir carpeta»); `SUPER + SHIFT + W` pone uno aleatorio. Los fondos están en `~/Pictures/Wallpapers` (cámbialo con `"wallpaperDir"` en `~/.config/dragon-island/settings.json`); el instalador copia ahí los del repo.

- **Imágenes y GIF** (jpg, png, webp, gif) los muestra **awww** (`awww-daemon` arranca con la sesión) con una transición `grow` desde el centro a 60 fps. **Vídeo** (mp4, webm, mkv): **mpvpaper**, un proceso por monitor, en bucle, sin audio y con aceleración por hardware. Nunca corren los dos a la vez.
- El fondo actual se guarda en `~/.local/state/dragon-island/wallpaper.json` y se restaura al iniciar sesión. `~/.cache/dragon-island/current-wallpaper` apunta a la imagen actual (un fotograma si es GIF o vídeo): **hyprlock** lo usa como fondo.
- Con una ventana a pantalla completa en un monitor, el vídeo de ese monitor se pausa solo (por el socket IPC de mpv) y se reanuda al salir.
- Las miniaturas se crean en `~/.cache/dragon-island/thumbs/` (ffmpeg / ffmpegthumbnailer), solo si faltan o el archivo cambió.
- Con vídeo y hyprglass, `glass.lua` limita el recálculo del cristal a 12 fps (`live_resample_fps`).
- Por IPC: `qs ipc call wallpaper toggle | set <ruta> | random | next | current`. Paquetes: `awww`, `ffmpeg`, `ffmpegthumbnailer`, `mpv` y `mpvpaper` (AUR); hyprpaper ya no se usa.

## Cristal y blur

Dos capas, y la segunda es opcional. Ambas trabajan por **alfa**: el blur / cristal aparece donde la ventana de Quickshell tiene píxeles con alfa por encima de un umbral, es decir, exactamente la forma visible (islas y tarjetas redondeadas). No se usa `BackgroundEffect.blurRegion`: una región de Wayland solo puede ser un rectángulo y dejaba puntas cuadradas en las esquinas.

1. **Blur nativo de Hyprland (base, sin plugins).** `decoration.blur` en `config/hypr/look.lua` (size 8, passes 3, vibrancy 0.17, noise 0.02, contrast 0.9, brightness 0.85, popups) y reglas de capa con `blur = true` e `ignore_alpha = 0.3` para `dragon-bar`, `dragon-popover`, `dragon-notifications`, `dragon-launcher` y `dragon-wallpapers` (`config/hypr/rules.lua`). Esas reglas **solo se crean si hyprglass no está cargado**: nunca hay dos blurs sobre la misma capa. El notch (`dragon-island`) queda negro opaco, sin blur, y el velo oscuro de los paneles (`dragon-scrim`) tampoco lleva blur.
2. **hyprglass (acrílico / liquid glass real, opcional).** Marca la casilla **«Efecto cristal (hyprglass)»** del instalador (o `./install.sh --glass`): ejecuta `hyprpm add https://github.com/hyprnux/hyprglass` y `hyprpm enable hyprglass` en una terminal visible. hyprpm instala la v0.9.1, la fijada para Hyprland 0.56.2. `config/hypr/glass.lua` (todo dentro de `if hl.plugin.hyprglass then … end`) define dos presets y usa `mask_mode = "alpha"`, `mask_threshold = 0.3` en cada capa:
   - **Las capas llevan el mismo cristal líquido que Ghostty**: `dragon-bar` (islas), `dragon-card` (notificaciones) y `dragon-panel` (popovers, lanzador, selector de fondos) heredan de `dragon-liquid` y solo cambian el ancho del borde (`edge_thickness` 0.2 / 0.12 / 0.06, porque es una fracción del lado menor de la forma) y el `bevel_size`; `mask_mode = "alpha"`, `mask_threshold` 0.1.
   - `dragon-liquid` (preset de todas las ventanas translúcidas): parte de los valores por defecto del plugin (no del preset `glass`) y busca el aspecto de la captura oficial: `blur_strength` 1.6 / 3 iteraciones (el fondo se intuye), `refraction_strength` 0.6 con `refraction_spread` 0 (solo en el borde, centro plano), `lens_distortion` 0.1, aberración 0.4, `specular_strength` 0.7, `fresnel_strength` 0.5, `bevel` 0.5 de 3 px, `self_sample` 0 y tinte azul marino `0x0b102060`; tema dark: brillo 1.0, `adaptive_dim` 0.5. El resto de ventanas no tiene cristal: `hg.config({ enabled = false })` y Ghostty se activa con las etiquetas `+hyprglass_enabled` y `+hyprglass_preset_dragon-liquid` (`+hyprglass_disabled` en pantalla completa). Para comparar presets en vivo: `hyprctl dispatch 'hl.dsp.window.clear_tags()'` y luego `hl.dsp.window.tag({ tag = "+hyprglass_enabled" })` y `… "+hyprglass_preset_<nombre>"` (la sintaxis `tagwindow` del README del plugin es de hyprlang y no funciona en Lua).
   - **Ventanas:** el cristal líquido (`default_preset`) va en **toda ventana translúcida**: Ghostty, kitty, Neovim (en su terminal, o `neovide`) y cualquier otra app con transparencia; hyprglass salta las opacas (`skip_opaque_windows`), así que no cuestan nada. **Sin cristal** (etiqueta `+hyprglass_disabled` por regla de ventana): navegadores (Brave, Chrome, Chromium, Firefox…), editores de código (VS Code y derivados, Cursor, Zed, JetBrains, Antigravity, Kate, gedit, Emacs…), ventanas en pantalla completa y reproductores de vídeo. Para añadir o quitar apps, edita la regla `glass-off-browsers-and-editors` en `glass.lua`. `decoration.inactive_opacity` es 1.0: con 0.95 todas las ventanas inactivas habrían sido translúcidas y habrían cogido cristal al perder el foco.
   - El notch y el velo están excluidos (`exclude = true`).
3. **Cómo se dibuja en Quickshell.** Cada isla de la barra y cada tarjeta de notificación es su propia ventana, transparente (alfa 0) alrededor de un Rectangle redondeado con `Theme.glassBg` (`surface0` al 18 %: `Theme.glassAlpha`) y un borde de 1 px blanco al 8 %; popovers, notificaciones y paneles van al 30 % (`Theme.popoverAlpha`). Tan translúcidos para que el cristal se vea de verdad; ambos quedan por encima del `mask_threshold` de 0.1. Los textos e iconos de la barra llevan una sombra sutil (`MultiEffect`, solo dentro de las islas) para leerse sobre el cristal. Las ventanas de pantalla completa (popovers, lanzador, selector) están desmapeadas mientras no hay nada abierto: dejarlas dibujándose costaba GPU. Nada se sale de las formas (sin sombras ni halos).
4. **Respaldo:** sin el plugin, o si una actualización de Hyprland lo rompe, todo se ve bien con el blur nativo y también respeta las esquinas. El gancho de capas de hyprglass usa una función privada de Hyprland, así que puede fallar tras actualizar.
5. **Comprobación:** `hyprctl plugin list` · `hyprctl getoption plugin:hyprglass:layers:enabled` · `hyprctl hyprglass status` · `hyprctl hyprglass stats`. Con un fondo de vídeo el recálculo del cristal se limita a 8 fps (`live_resample_fps`). Quitarlo: `hyprpm disable hyprglass`.
6. Ghostty (`config/ghostty/config`) y kitty (`background_opacity 0.65`; reinícialo para aplicarlo) son translúcidos sobre el cristal; su propio blur y su barra GTK están apagados (`window-decoration = none`, `gtk-titlebar = false`) y su barra de título es la de hyprbars como en el resto de ventanas (con `bar_blur = false`: con el blur de la barra aparecía una banda oscura de ~40 px sobre el cristal). Para opacidad por app hay reglas comentadas al final de `rules.lua`; las ventanas en pantalla completa y los reproductores de vídeo siempre quedan opacos.

## Shell: zsh + starship

Componente opcional del instalador (casilla «Shell: zsh + starship» o `--zsh`). Instala `zsh` y `starship`, clona **oh-my-zsh** y sus plugins `zsh-autosuggestions` y `zsh-syntax-highlighting` (son clones de git, no paquetes), despliega `config/zsh/.zshrc` en `~/.zshrc` y `config/starship/starship.toml` en `~/.config/starship.toml` (con backup de los tuyos) y pregunta antes de `chsh -s /usr/bin/zsh`.

- Lo privado (tokens, alias personales, rutas) va en `~/.zshrc.local`, fuera del repo: el `.zshrc` lo carga si existe.
- Los colores de starship usan la paleta Dragonized (accent, violetSoft, cyan, ok, warn, error).
- Ghostty abre tu shell de login (zsh tras el componente). Plasma no se toca: solo cambian tus dotfiles de usuario.
- En un sistema ya instalado lo aplica la migración `002-zsh-starship.sh` con `./update.sh`.

## Estructura

```
config/hypr/            hyprland.lua + módulos (monitors, env, input, look, animations, rules, binds, plugins, autostart)
config/quickshell/
  shell.qml             barra, notch, popovers, lanzador y notificaciones por monitor (cada uno en su capa)
  Theme.qml             todos los colores, tamaños, fuentes y duraciones (spec)
  Icons.qml             glifos Nerd Font
  ShellState.qml        panel abierto (uno a la vez) + IPC "shell"
  services/             datos: Hypr, Media, Audio, Network, Bluetooth, Power, Brightness,
                        SysStats, Notifs, Osd, Toggles, Apps, Clock, Session, IslandState,
                        Settings, Clipboard, Tray, Keybinds
  components/           Capsule, Slider, ToggleTile, PopoverFrame, ListRow…
  modules/              bar · island (notch) · popovers · notifications · launcher · power · clipboard · keybinds
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
