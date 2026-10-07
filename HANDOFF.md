# dragon-island — HANDOFF

> **Fecha:** 2026-10-06 · **Rama:** `main` · **Estado:** interfaz completa según la spec; llavero único (gnome-keyring) y bandeja listos, **pendiente de prueba en una sesión Hyprland**.
> Todo se escribió y validó en Windows (sin Hyprland ni Quickshell). Lo que exige hardware real está en [docs/TESTING.md](docs/TESTING.md).

## 1. Resumen

Escritorio Hyprland 0.56 (configuración Lua) + Quickshell 0.3.1, instalado como segunda sesión junto a KDE Plasma.

- **Base (fase anterior):** configuración de Hyprland, instalador gum y servicios QML.
- **Esta fase:**
  - Auditoría y corrección de esa base.
  - Construcción de toda la interfaz según `references/design.md`: barra, Dynamic Island, dashboard, popovers, notificaciones, lanzador y menú de energía.
  - Pulido de animaciones y casos límite.
  - Integración en el instalador y documentación.

Fuente de verdad: la skill `.agents/skills/dragon-island` (versiones, arquitectura y spec visual). Ante cualquier duda, manda sobre este documento.

## 2. Arquitectura del shell

```
shell.qml ── Variants(screens) → modules/bar/Bar.qml                       (Scope: una ventana por isla, capa Top, "dragon-bar" + "dragon-bar-zone" que reserva el hueco)
          ├─ Variants(screens) → modules/island/IslandWindow.qml           (capa Overlay, "dragon-island")  → Notch.qml
          ├─ Variants(screens) → modules/popovers/PopoverWindow.qml        (capa Overlay, "dragon-popover") → PopoverHost (7 popovers)
          ├─ Variants(screens) → modules/launcher/LauncherWindow.qml       (capa Overlay, "dragon-launcher") → launcher · power · portapapeles · atajos
          └─ Variants(screens) → modules/notifications/NotificationWindow.qml (Scope: una ventana por tarjeta, capa Overlay, "dragon-notifications")
Theme.qml · Icons.qml · ShellState.qml (raíz)      services/*.qml (datos)      components/*.qml (piezas)
```

- **Cada componente en su capa (namespace propio)**, para poder dar reglas de blur / hyprglass distintas. Con hyprglass en `mask_mode = "alpha"` el cristal sigue el alfa de cada ventana (no hay `BackgroundEffect.blurRegion`, ver §7g); el velo de los paneles es su propia ventana (`dragon-scrim`).
- **Notch (`modules/island/`):**
  - `IslandWindow` mide el ancho de la pantalla y `Theme.notchWindowHeight` (270). `exclusionMode: Ignore`, máscara = solo la forma, `HyprlandFocusGrab` + Esc cierran.
  - `Notch.qml` hace la coreografía (`expanded`, `contentShown`, `appeared`) y anima ancho, alto y x con `SpringAnimation`. `NotchShape.qml` dibuja la silueta con `ShapePath` + `PathArc` (orejas cóncavas r = 12, esquinas inferiores 18 / 34).
  - `NotchContent.qml` = estado colapsado + línea del peek; `NotchExpanded.qml` = pestañas Nook | Tray + engranaje, con `NookTab` (`MediaNook`, `CalendarStrip`, `NotchToggles`, `NotchStats`) y `TrayTab`.
  - `services/BarMetrics.qml`: cada `Bar` informa de dónde acaban sus islas; el notch colapsado vive en el hueco libre − 16 px por lado, centrado en la pantalla salvo que una isla lo obligue a desplazarse.
- **Un solo panel abierto:** `ShellState.openPanel` + `panelScreen` (el panel `dashboard` es el notch expandido). El IPC (`qs ipc call shell …`) abre en el monitor enfocado.
- **Estados temporales:** `services/IslandState.qml` (OSD > notificación > escritorio > música > reloj). Los transitorios hacen que el notch se "asome" (peek) y vuelva solo.
- **Degradado de marca:** `components/BrandFill.qml` usa `QtQuick.Shapes` (`PathRectangle` + `LinearGradient` a 135°). Se descartó Qt5Compat `LinearGradient` porque no pintaba en la verificación offscreen y añadía una dependencia.

## 3. Lo que se hizo, por fase

### Fase 1 — Auditoría (commits `bae9182`, `bf59f0f`, `ee41e2c`, `c1058be`)

| Área | Problema | Corrección |
|---|---|---|
| Hyprland | `gestures.workspace_swipe*` no existe en 0.56 | `hl.gesture({...})` |
| Hyprland | Sin decisión de tema Qt | `QT_QPA_PLATFORMTHEME=kde` solo vía `hl.env` |
| Hyprland | polkit por ruta adivinada; opciones de plugins antes de cargarlos | `systemctl --user start hyprpolkitagent`; `hyprpm reload -n && hyprctl reload` |
| hyprlock | `disable_loading_bar`, `no_fade_in`, `grace` no existen | Eliminadas |
| Paquetes | `rofi-wayland` y `outfit-font` **no existen** | `rofi` y `ttf-outfit` (verificados en archlinux.org y AUR) |
| Instalador | Los componentes no filtraban paquetes; `--dry-run` pedía sudo; copia no idempotente; scripts sin `+x` | Secciones `@componente`, dry‑run sin efectos, `diff -rq`, `100755` |
| QML | `Audio`: señales que chocaban con las de sus propiedades → el singleton no cargaba | Eliminadas |
| QML | `Bluetooth`: `onEnabledChanged` duplicado | Corregido |
| QML | Bindings bidireccionales rotos (Network, Bluetooth, Toggles) | `readonly` + funciones |
| QML | `Hypr.activeClass` leía un campo inexistente | Corregido |
| QML | El OSD nunca se disparaba | Ahora reacciona a Audio y Brightness |

Servicios completados para la interfaz: detalles de Wi‑Fi (`nmcli`), vincular dispositivos Bluetooth, mezclador por app, uso por núcleo, GPU y procesos, notificaciones no leídas y popups, búsqueda difusa con frecuencia de uso, calendario y el servicio nuevo `Session`.

### Fase 2 — Barra e isla (`b473001`, `8c7e7e4`, `ab1fc3d`)

- `Theme.qml` con todos los tokens de la spec (paleta, geometría y tabla Motion con `motionScale`) e `Icons.qml`.
- 15 componentes reutilizables.
- Barra de tres islas con máscara, píldoras de escritorio (200 ms OutCubic) y cápsulas (hover de 120 ms).
- Dynamic Island: caída con rebote y aplastamiento; "pour" pegado arriba con radios 0/0/34/34; contenido con retraso; scrim; Esc; estados temporales.

### Fase 3 — Dashboard y popovers (`ab1fc3d`, `d8a2036`, `657958d`)

- Dashboard completo.
- Popovers Rendimiento, Wi‑Fi (con contraseña), Bluetooth, Sonido, Batería, Notificaciones y Calendario. Solo uno abierto.
- Popups de notificación: hasta 3, solo en el monitor enfocado, se pausan con el ratón y las críticas duran hasta descartarlas.
- Lanzador (`DesktopEntries`, búsqueda difusa, teclado) y menú de energía (teclado y `1–5`).

### Fase 4 — Pulido (incluido en los commits anteriores y `f46d56b`)

- Duraciones y curvas revisadas contra la tabla Motion (ver `Theme.qml`, sección Motion).
- Casos límite:
  - sin batería, sin reproductor, sin Bluetooth, Wi‑Fi apagado o bloqueado y solo Ethernet;
  - 0 notificaciones y hasta 100 (ListView + `ScriptModel` por identidad, historial con límite);
  - varios monitores e isla oculta sobre pantalla completa.
- Rendimiento:
  - el brillo se lee de sysfs cada 300 ms (sin procesos);
  - los procesos de Rendimiento solo se sondean con el popover abierto;
  - el escaneo Wi‑Fi solo corre con su popover abierto;
  - el calendario se recalcula una vez al día, no cada segundo.
- DebugPanel fuera del arranque: se abre con `qs ipc call debug toggle`.

### Fase 6 — Decisiones del usuario y mejoras

- **Notificaciones solo como popups.** Se quitó el estado de notificación de la isla. Esto se aparta a propósito de la spec (`design.md` lo incluía); la spec no se ha editado.
- **Calendario con khal** (`Clock.qml`):
  - `khal list` con `--day-format "@@{date-long}"` y un formato separado por tabuladores.
  - El formato de fecha del usuario se aprende de `khal printformats` (europeo, ISO y US probados).
  - Anillos cian en los días con eventos; clic en un día muestra su agenda.
  - Recarga cada 10 min y al abrir el calendario.
- **Portapapeles en Quickshell** (`Clipboard.qml` + `modules/clipboard/`):
  - Sustituye a rofi (paquete eliminado). Se abre con `SUPER + SHIFT + V` → `shell toggle clipboard`.
  - Muestra miniaturas de las imágenes; `Supr` borra la entrada y "Borrar historial" lo vacía.
- **Bandeja del sistema** (`Tray.qml`): una cápsula en la isla derecha. Clic, derecho = menú de la plataforma, central y rueda. Oculta las entradas pasivas.
- **Movimiento reducido** (`Settings.qml`):
  - `Theme.motionScale` se toma de `~/.config/dragon-island/settings.json`; si no hay valor, de la "Velocidad de animación" de Plasma (`kdeglobals AnimationDurationFactor`); si tampoco, 1.0.
  - IPC: `qs ipc call settings motion <x>`.
  - Los tiempos de pantalla (OSD 2 s, popups 4 s) **no** se escalan.
  - Con 0, las animaciones infinitas no corren.
- **Brillo por DDC/CI** (`Brightness.qml`):
  - `ddcutil detect` empareja cada monitor con Hyprland por su `DRM connector`; la lectura y escritura van por `--bus`, en cola, porque DDC no admite concurrencia.
  - La escritura espera 250 ms tras el último cambio.
  - El slider del dashboard y del popover de Batería actúa sobre **su** monitor.
  - El paquete `ddcutil` instala el módulo `i2c-dev` y la regla udev, así que el instalador no toca `/etc`.
- **Panel de atajos (`SUPER + F1`)** (`Keybinds.qml` + `modules/keybinds/`):
  - Lee los atajos en vivo con `hyprctl binds -j` y se recarga al abrirse.
  - Cada `hl.bind` de `binds.lua` lleva `description = "Grupo · Texto"` (con un helper `bind()`), así que no hay ninguna lista duplicada.
  - Agrupa las filas iguales (`SUPER + 1–5`, flechas, `Play / Pausa`) y traduce los nombres de tecla.
  - Dos columnas equilibradas, búsqueda y Esc. Probado con el `binds.lua` real ejecutado en lupa: 53 atajos → 32 filas.
  - **No verificado:** los nombres exactos de los campos del JSON de `hyprctl binds -j` en 0.56 (se asumen `modmask`, `key`, `description` y `submap`).
- **Fondo propio:** `assets/wallpapers/dragon-island.jpg` (4K, paleta de la spec). El instalador lo enlaza en `~/.local/share/dragon-island/wallpaper.jpg` solo si no existe, y `hyprpaper.conf` apunta ahí.

### Fase 7 — Llavero único (gnome-keyring) y bandeja (`ec50bcd`, `3349a1b` y el commit de esta revisión)

Diagnóstico, hecho en EndeavourOS desde Plasma con los logs de la sesión Hyprland anterior:

- **Gestor de inicio:** es **Plasma Login Manager** (`plasmalogin`), no SDDM. Su PAM está en `/usr/lib/pam.d/plasmalogin` y ya trae `pam_gnome_keyring` (auth, password y `session … auto_start`). No hay inicio de sesión automático. En cada inicio, el journal muestra `gkr-pam: unlocked login keyring`: la contraseña de `login` coincide con la del usuario.
- **Proton VPN en Hyprland:** se quedaba colgado al leer su sesión del Secret Service. gnome-keyring abrió un diálogo de `gcr-prompter` (22:15) que nadie respondió hasta cerrar la sesión. El log no dice qué pedía; probablemente crear el llavero predeterminado, porque las entradas de Proton se crearon después, a las 22:21. Hoy `default` → `login`.
- **Dos llaveros:** gnome-keyring tenía `org.freedesktop.secrets` y `ksecretd` (KWallet) intentaba registrarlo también. Brave guardaba su clave en KWallet en Plasma y usaba otro almacén en Hyprland.

**Primer plan, descartado:** KWallet como único llavero. Descartado porque gnome-keyring es **dependencia** de `python-proton-keyring-linux` (Proton VPN) y de `qtkeychain-qt6` (`plasma-nm`). El diagnóstico inicial lo pasó por alto: filtró la salida de `pacman -Qi` con el nombre del campo en inglés y el sistema está en español.

**Estrategia final:** gnome-keyring es el único Secret Service en las dos sesiones, abierto por PAM.

- Sin `kwallet-pam` ni `pam_kwallet_init` en el repo. `autostart.lua` no arranca nada del llavero, porque PAM ya lanza y desbloquea el daemon.
- `packages/pacman.txt`: `gnome-keyring` y `libsecret` en `core`. Nuevo componente opcional `tools` con `seahorse`.
- `hyprland-portals.conf`: el portal *Secret* va a `gnome-keyring` (ni `hyprland` ni `gtk` lo implementan).
- `brave-flags.conf`: `--password-store=gnome-libsecret`. Hay que exportar las contraseñas antes: lo cifrado con la clave de KWallet se pierde (el perfil Default tenía 0 contraseñas y 80 cookies).
- Instalador: avisa si KWallet sigue ofreciendo Secret Service (`kwalletrc [org.freedesktop.secrets] apiEnabled`) y muestra el comando para desactivarlo, sin aplicarlo. La pantalla final y el README (*Llavero / contraseñas*) explican la estrategia.
- **Bandeja:** la cápsula está entre la campana y el reloj, con `QsMenuAnchor`. La lógica de iconos, clic, rueda y menú está en `Tray.qml`.
- **En manos del usuario:** desactivar el Secret Service de KWallet (`kwriteconfig6 … apiEnabled false`). No hace falta tocar `/etc` ni PAM.

### Fase 5 — Cierre

- **Instalador:** al terminar avisa si falta `qs`, si faltan las fuentes o si hay otro daemon de notificaciones (mako, dunst o swaync). Se quitó `qt6-5compat`, que ya no hace falta.
- **Docs:** [README.md](README.md), [docs/KEYBINDS.md](docs/KEYBINDS.md) y [docs/TESTING.md](docs/TESTING.md).

## 4. Qué se verificó (en Windows)

| Comprobación | Herramienta | Resultado |
|---|---|---|
| Scripts | `shellcheck -x` 0.11.0 | Limpio |
| Config Lua | Sintaxis + ejecución con `hl` simulado (lupa) | OK, 158 llamadas |
| QML | `qmllint` 6.11 (sin las categorías de tipos Quickshell no resolubles) | Sin avisos |
| **Carga real de QML** | Motor QML de PySide6 6.11 offscreen + stubs mínimos de `Quickshell` + servicios simulados con datos realistas | **Todos los módulos (barra, isla en sus 5 estados, dashboard, 7 popovers, popups, lanzador, menú) se instancian sin un solo aviso**. Se revisaron las capturas renderizadas contra la spec |
| Paquetes | archlinux.org / AUR RPC | Todos existen |
| Fin de línea | `git ls-files --eol` | Todo LF |
| Reglas | grep | 0 colores fijos fuera de `Theme`; la UI no usa `Process`/`exec`/D‑Bus |
| khal (`Clock.qml` real) | Motor QML + stubs; salida de ejemplo con cabeceras ANSI en 3 formatos de fecha | Fechas, rango de consulta, orden y anillos correctos |
| DDC (`Brightness.qml` real) | Motor QML + salida de ejemplo de `ddcutil detect` / `getvcp` | Ignora pantallas inválidas, escala al máximo del monitor y aplica el retardo |
| Nuevas vistas | Render offscreen (calendario con eventos, portapapeles, bandeja) | Sin avisos y coherentes con la spec |

Gracias al render se detectó y corrigió que Qt5Compat `LinearGradient` no pintaba (de ahí BrandFill con Shapes). También se corrigieron:

- un nombre que tapaba la propiedad `top` de `Item`;
- un Behavior que habría peleado con la caída inicial;
- clics en zonas vacías del dashboard que lo cerraban.

## 5. Qué NO se verificó (requiere EndeavourOS)

- **Quickshell real:**
  - los servicios contra PipeWire, NetworkManager, BlueZ, UPower, MPRIS e Hyprland;
  - la máscara de clics y el foco `Exclusive` en Wayland;
  - el blur por reglas de capa;
  - el import de directorios con `qmldir` dentro de Quickshell;
  - `RectangularShadow` (QtQuick.Effects, Qt ≥ 6.9).
- **Hyprland:**
  - `hyprctl configerrors`;
  - las opciones de hyprbars en Lua y el **orden visual de los botones**;
  - el bloque `plugin` aplicado antes de cargar los plugins;
  - `hyprpm` dentro de kitty en el primer arranque.
- **Datos de `nmcli`:** banda, velocidad e IP (el formato `-t` puede variar).
- **Glifos Nerd Font:** los códigos de `Icons.qml` son del set Material Design (nf‑md) y en Windows salían como cuadros por falta de la fuente. Revisa que cada icono sea el esperado.
- **gum con la salida redirigida al log** (`exec > >(tee …)`).
- **khal real:** que `printformats` y `list --day-format/--format` se comporten como dice su documentación (0.14).
- **ddcutil 3.0 real:** que `detect` muestre `DRM connector` y los permisos tras reiniciar.
- **Bandeja:** el menú con `QsMenuAnchor` (posición, cierre al pulsar fuera). Se probó en Plasma que la cápsula carga sin avisos y muestra Proton VPN entre la campana y el reloj; el menú no se probó.
- **Llavero:** que Brave y Proton no pidan la clave en ninguna de las dos sesiones, ya con `apiEnabled=false` en KWallet y la nueva opción de Brave (checklist en el README).
- `shellcheck` no estaba instalado en la máquina: `install.sh` solo pasó `bash -n` y `--dry-run`.
- **Portapapeles:** que las miniaturas decodificadas (`*.img` en caché) se carguen.

## 6. Decisiones

- `SUPER + L` = bloquear; Vim = `SUPER + ALT + HJKL` (conflicto dentro de la propia spec).
- Tema Qt: plataforma `kde` en Hyprland, porque Plasma ya está instalado.
- `IslandState` vive en `services/` para evitar un ciclo de imports entre la raíz y `services`.
- Notificaciones: popups + centro, y desde la v2 del notch también un peek de ~4 s con el título (pedido en "Notch Island v2").
- Calendario: **khal** como fuente de eventos; la sincronización (vdirsyncer) la configura el usuario.
- Grabación: `wf-recorder` sobre una zona o salida elegida con `slurp -o`, guardada en la carpeta XDG de vídeos.
- Historial del portapapeles: panel propio en Quickshell (rofi ya no se instala).
- Movimiento reducido: el usuario manda (`settings.json`); si no, se sigue a Plasma.
- Blur: reglas de capa nativas (`ignore_alpha` 0.3) **y** `BackgroundEffect.blurRegion` en cada ventana, para que el blur / cristal solo aparezca tras las islas y tarjetas (con hyprglass `mask_mode = "region"` lo exige).
- Llavero: **un único Secret Service, gnome-keyring**, abierto por PAM en las dos sesiones (Proton VPN y `plasma-nm` dependen de él). KWallet queda solo para Plasma, sin Secret Service. El repo no edita `/etc` ni PAM.

## 7. Siguientes pasos

1. Recorrer [docs/TESTING.md](docs/TESTING.md) en EndeavourOS y corregir lo que falle (`qs log` da el archivo y la línea).
2. Hacer las capturas y guardarlas en `docs/screenshots/` (el README ya tiene los huecos).
3. Opcional:
   - crear eventos desde el calendario (`khal new`);
   - un selector de fondos de pantalla;
   - pegar automáticamente tras elegir en el portapapeles (`wtype`).

## 7b. Primer arranque real en Hyprland (2026-10-05)

- `misc.vfr` no existe en Hyprland 0.56 (Lua): quitado de `look.lua`. Mientras estuvo, el banner de error de Hyprland tapaba la zona superior y **la isla parecía no aparecer**: la ventana `dragon-island` sí existía en `hyprctl layers`. Lección: ante "no aparece", mira primero `hyprctl configerrors`.
- `hyprpm` es un paquete aparte en Arch: añadido a `packages/pacman.txt` (con `pkgconf`). `installer/firstrun.sh` comprueba que exista y luego hace update/add/enable en primer plano.
- `Network.connectivity` y `Power.currentProfile` pasan a `int` (avisos "Unable to assign int to …*"). Anotado en `gotchas.md`.
- `~/.config/hypr` y `~/.config/quickshell` ya son symlinks al repo (`deploy_item`).
- Los avisos de `IconPixmap` (Proton) y `printer.svg` (Humanity) son inofensivos.
- Verificado: `hyprctl configerrors` vacío, hyprbars y hyprfocus cargados, `qs log` sin errores desde la recarga, isla visible y dashboard abierto/cerrado por IPC (lo que ejecuta SUPER+D).
- Sin probar: el clic físico sobre la isla (usa el mismo `ShellState.toggle`).

## 7c. Notch v2, blur nativo y hyprglass (2026-10-06)

Tres commits, uno por parte:

1. **Notch (`feat(island)`).** Sustituye a la píldora flotante y al dashboard. Emerge del borde (alto 0 → 50, ancho 120 → colapsado, `SpringAnimation`), peek al pasar el ratón (+8 px alto, +16 px ancho), expandido ≈720×230 con pestañas Nook | Tray. Popovers, lanzador / menús modales y popups de notificaciones salen del overlay de la isla a sus propias ventanas.
2. **Blur nativo (`feat(blur)`).** `decoration.blur` comentado valor a valor, reglas de capa por namespace, `Theme.glassBg` + borde 8 %, kitty 0.85, reglas de opacidad por app (comentadas) y ventanas opacas en pantalla completa / vídeo.
3. **hyprglass (`feat(glass)`).** Componente opcional del instalador (`installer/glass.sh`), `config/hypr/glass.lua` guardado con `hl.plugin.hyprglass` y `BackgroundEffect.blurRegion` en barra, popovers, notificaciones y lanzador.

Decisiones y trampas:
- `HyprlandFocusGrab` se limpiaba al instante si la ventana pedía foco de teclado `Exclusive`: el notch usa `OnDemand`. Con eso Esc y el clic fuera funcionan (probados con un teclado / ratón virtual por uinput).
- `transient` es palabra reservada de QML (`IslandState.isTransient`).
- Los `Layout.fillWidth` de un `ColumnLayout` anidado valen `true` por defecto: hay que ponerlo a `false` para que respete `preferredWidth`.
- El engranaje del notch abre el menú de energía: es donde fueron a parar bloquear / suspender / apagar de la cabecera del dashboard antiguo. El slider de brillo vive ahora en el popover de batería.
- Con el hueco libre de 1366 px (isla derecha ancha) el notch colapsado se desplaza unos píxeles del centro si hace falta y su ancho máximo ronda los 250 px; en monitores pequeños queda estrecho (mínimo 120) pero nunca se superpone.
- hyprglass 0.9.1 instalado con `installer/glass.sh` en una terminal real: hyprpm escribe su estado con `sudo`, así que no funciona sin tty (ni desde Claude Code). `hyprctl plugin list` → 0.9.1, `layers:enabled` → `set: true`, `hyprctl hyprglass status` → windows / layers on. Stats: ~1 layer draw y ~5 blur passes por fotograma. GPU (AMD Lucienne, `gpu_busy_percent`): ~5 % en reposo y ~11 % abriendo y cerrando el notch en bucle → no hace falta `live_resample = false`.
- Probado con un monitor headless (`hyprctl output create headless`) además del portátil.

## 7d. Teclado US/Latam, update.sh y migraciones (2026-10-06)

- **Teclado:** `kb_layout = "us,latam"` (el teclado físico del usuario es US; los atajos se resuelven contra el primero), `kb_variant = ","`, `grp:alt_shift_toggle`. `SUPER + ALT + Space` → `hyprctl switchxkblayout all next`. `services/Keyboard.qml` sigue el evento `activelayout` de `Hyprland.rawEvent` y `RightIsland` muestra la cápsula `US` / `LA` (clic = siguiente). hyprlock toma el keymap de Hyprland y muestra `$LAYOUT`.
  - El grupo xkb por `Alt+Shift` es **por teclado**: el evento `activelayout` llega solo del teclado que lo pulsó; la cápsula muestra el último evento.
  - Probado con un teclado/ratón virtual (uinput): SUPER+ALT+Space y el clic en la cápsula cambian la distribución del teclado principal; `Alt+Shift` cambió el grupo del dispositivo virtual. Sin probar: escribir ñ físicamente y hyprlock (no se bloqueó la sesión para probarlo).
- **update.sh** (`./install.sh --update` es un alias): pull → migraciones → paquetes → configs → plugins → recarga → resumen. Las ayudas comunes con `install.sh` viven en `installer/lib.sh`; las migraciones cargan `installer/migration-env.sh` (también se pueden ejecutar solas). `install.sh` ahora guarda `components` y `link-mode` en el estado y marca todas las migraciones como aplicadas en una instalación nueva; en instalaciones anteriores `update.sh` los infiere del manifiesto.
- **Regla:** todo cambio que afecte a sistemas ya instalados lleva migración (`migrations/NNN-*.sh`, ver `migrations/README.md` y la skill `dragon-island`).
- `shellcheck` no estaba instalado: se usó `shellcheck-py` en un venv (0.11.0). `update.sh`, `install.sh`, `installer/*.sh` y `migrations/*.sh` pasan `shellcheck -x`.
- **zsh + starship (importados, no reescritos):** `config/zsh/.zshrc` es el `.zshrc` del usuario (oh-my-zsh, `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)`, `eval "$(starship init zsh)"`) más la línea que carga `~/.zshrc.local`; no había secretos que mover. oh-my-zsh y los dos plugins son clones de git (`ensure_omz` en `installer/lib.sh`); `zsh` y `starship` salen de `extra` (`@zsh` en `packages/pacman.txt`; starship ya estaba en `/usr/local/bin` y `update.sh` no lo reinstala si el comando existe). Colores de starship pasados a la paleta (decisión del usuario). Componente opcional `zsh` en el instalador y migración `002-zsh-starship.sh` (backup + symlinks, `chsh` con confirmación). `kitty.conf` abre zsh si existe.
- Los cambios locales sin commit (también los de `.agents/skills`) detienen `update.sh`: es lo pedido.

## 7e. Blur: un solo sistema por capa y una ventana por isla / tarjeta (2026-10-06)

- **Síntoma:** franja gris‑morada de lado a lado de la barra, con las islas dentro de un rectángulo.
- **Diagnóstico:** `hyprctl eval 'hl.plugin.hyprglass.config({ layers = { enabled = false } })'` hacía desaparecer la franja (el blur nativo no pintaba nada visible); `hyprctl keyword` **no funciona en modo Lua**, usa `hyprctl eval`. Con **una** región (solo la isla izquierda) el cristal quedaba en esa isla: hyprglass (y el protocolo) usan la **caja envolvente de la unión** de las regiones de blur, así que dos islas disjuntas en una ventana cubren también el hueco.
- **Corrección:** `Bar.qml` es ahora un `Scope` con una ventana por isla (namespace `dragon-bar`, tamaño exacto de la isla, una sola región con su radio) y una ventana transparente de 1 px (`dragon-bar-zone`, máscara vacía) que solo reserva el espacio. Cada tarjeta de notificación es su propia ventana (`NotificationWindow.qml`, sin `NotificationPopups.qml`), así los 8 px entre tarjetas quedan limpios. Popovers y lanzador muestran una sola tarjeta a la vez, por lo que su región ya era exacta.
- **Un sistema por capa:** `rules.lua` guarda los handles de las reglas nativas (`ignore_alpha` 0.35) en `DragonBlurRules`; `glass.lua` las desactiva (`:set_enabled(false)`) para las capas que pasa a hyprglass. Sin el plugin quedan activas. El notch no tiene regla de blur y está excluido en hyprglass (`exclude = true`).
- **Verificado** (píxeles de los huecos y capturas): con hyprglass y con el plugin descargado (`hyprctl plugin unload …/HyprGlass/hyprglass.so` + `hyprctl reload`; luego `plugin load`) los huecos entre islas y entre tarjetas quedan limpios y el notch negro sin halo.
- Migración `003-remove-stale-qml.sh`: borra de una copia de `~/.config/quickshell` los QML eliminados (`update.sh` nunca borra).

## 7f. Selector de fondos (2026-10-06)

- `services/Wallpaper.qml` + `scripts/wallpapers.sh` + `modules/wallpapers/WallpaperPanel.qml` (hospedado en `LauncherWindow`, panel `wallpapers`), IPC `wallpaper`, `SUPER + W` / `SUPER + SHIFT + W`. awww para imágenes / GIF (`--transition-type grow --transition-pos center --transition-fps 60`), mpvpaper por monitor para vídeo (`-o "no-audio loop hwdec=auto-safe panscan=1.0 input-ipc-server=…"`). El script hace `awww kill` al aplicar un vídeo y `pkill mpvpaper` al aplicar una imagen: nunca conviven.
- **Pausa del vídeo:** socket IPC de mpv (`components/MpvPause.qml`, `Quickshell.Io.Socket`) por monitor cuando `Hypr.fullscreenOn(monitor)` cambia. Descartado `SIGSTOP` (congela también el bucle Wayland del cliente: no atiende `configure` ni cambios de salida) y el `--auto-pause` de mpvpaper (no distingue monitores ni usa los eventos de Hyprland). Verificado con `get_property pause`: False → True en pantalla completa → False al salir.
- **Restauración:** awww restaura por su cuenta la última imagen al arrancar el daemon, así que `running` devuelve lo que muestra awww y el servicio solo aplica si no coincide con `wallpaper.json` (probado con vídeo, GIF e imagen guardados tras matar los demonios). Reiniciar Quickshell no reinicia un vídeo activo.
- hyprlock: `path = ~/.cache/dragon-island/current-wallpaper`; hyprgraphics detecta el formato por bytes mágicos (libmagic), no por extensión. **Sin probar el bloqueo real** (no se bloqueó la sesión).
- hyprpaper fuera del autostart, de `packages/pacman.txt` y su `.conf` borrado (el paquete sigue instalado). Migración `004-wallpapers.sh`: paquetes, carpeta, fondo personalizado antiguo → `mi-fondo.jpg`, cambio de demonios.
- **Rendimiento con vídeo** (vídeo de prueba 720p H.264, portátil AMD Lucienne, `gpu_busy_percent`): GPU ~5 % con imagen → 14–20 % con vídeo + hyprglass; mpvpaper ~5–6 % de un núcleo; Hyprland ~8–9 %. `live_resample` desactivado en la barra ahorra ~3 puntos, igual que bajar `live_resample_fps` de 30 a 10: se dejó `live_resample_fps = 12` en `glass.lua` y el cristal sigue vivo.
- Los fondos de prueba (GIF / mp4 sintéticos) se generaron con ffmpeg y se borraron.
- Color dominante del fondo con `ColorQuantizer`: no (decisión del usuario).

## 7g. Cristal por alfa, sin puntas en las esquinas (2026-10-06)

- **Problema:** puntas cuadradas en las esquinas de islas, tarjetas y popovers. `BackgroundEffect.blurRegion` es una región de Wayland (solo rectángulos, el `radius` no se respeta) y hyprglass en `mask_mode = "region"` usa esa misma región.
- **Solución:** se eliminó todo `BackgroundEffect.blurRegion` (y `frameItem` / `frames`); hyprglass usa `mask_mode = "alpha"`, `mask_threshold = 0.3` en barra, popovers, notificaciones, lanzador y el selector de fondos (que ahora tiene su propia ventana `dragon-wallpapers`, `WallpaperWindow.qml`). `glassAlpha` pasa a 0.50 (> umbral). Presets `dragon-bar` (hereda de `pomme`; blur 2.8 / 4 iteraciones, refracción 0.3, aberración 0.15, `bevel` 0.25 de 2 px, tinte `0xc50ed214`, `adaptive_dim` 0.85) y `dragon-panel` (hereda de `dragon-bar`, más opaco). Notch y velo con `exclude = true`.
- **Trampa del modo alfa:** el velo negro al 45 % de los modales (alfa > umbral) se habría llenado de cristal en toda la pantalla; ahora es otra ventana (`ScrimWindow.qml`, `dragon-scrim`, capa Top, máscara vacía, sin blur). Además las ventanas de pantalla completa en reposo (popovers, lanzador, selector) se dibujaban cada fotograma en la máscara de alfa (≈ 3,8 Mpx de cristal por fotograma, GPU 20 %): ahora están **desmapeadas** (`visible: open || lingering`) mientras no hay nada abierto (0,04 Mpx, GPU ≈ 10–13 % en reposo con el navegador reproduciendo).
- **Texto sobre fondos claros:** con un fondo casi blanco las islas quedaban grises y el texto tenue casi ilegible; `adaptive_dim` 0.85 / 0.9 y `dark.brightness` 0.74 / 0.72 lo arreglan (comprobado con capturas sobre un degradado claro).
- **Respaldo:** las reglas nativas (`ignore_alpha` 0.3) se crean en `rules.lua` solo `if not (hl.plugin and hl.plugin.hyprglass)`; se probó descargando el plugin (`hyprctl plugin unload …/HyprGlass/hyprglass.so` + `hyprctl reload`): esquinas redondas y huecos limpios también con blur nativo. Se sustituyen los handles `DragonBlurRules` de §7e.
- **Rendimiento con vídeo** (`hyprctl hyprglass stats`, `gpu_busy_percent`; cifras con un navegador reproduciendo vídeo): imagen estática 2 dibujados de capa por fotograma, GPU ≈ 13 %; vídeo con `live_resample_fps = 8`: ≈ 23 %; vídeo con `live_resample = false` en la barra: ≈ 25 %. Desactivar `live_resample` no ahorró nada y congelaría el cristal tras las islas, así que se deja activo con el tope de 8 fps.
- **Migración:** no aplica. Todo vive en archivos del repo (symlink o `update.sh` en modo copia) y no se eliminó ningún archivo; `update.sh` ya reinicia Quickshell y hace `hyprctl reload`.

## 7h. Ghostty, cristal líquido visible y popovers bajo su cápsula (2026-10-06)

- **Popovers:** `Bar.openFrom` comparaba `item.Window.window` (un `QQuickWindow`) con un `PanelWindow` de Quickshell (nunca igual): usaba siempre el desplazamiento de la isla izquierda y los popovers salían pegados a la izquierda. Ahora cada isla pasa su `windowX` y su lado (`"right"` / `"left"`); `ShellState.anchorX` + `anchorSide` sustituyen a `anchorRight`; `PopoverHost.xFor` alinea el borde derecho (isla derecha) o izquierdo (isla izquierda) con el de la cápsula, recortado a 14 px del borde, y el origen de la animación va en ese lado. Probados los 7 popovers pulsando de verdad cada cápsula (teclado / ratón virtual) en un espacio vacío, y sonido y calendario en un monitor headless de escala 2.
- **Ghostty** (1.3.1, `extra`) sustituye a kitty: `SUPER + Return`, `Apps.launch` (`ghostty -e`), ventanas de configuración del autostart (`--class=org.dragonisland.Setup`: la clase de Ghostty es un ID de aplicación GTK, necesita puntos) y `config/ghostty/config` (paleta Dragonized, `background-opacity`, `background-blur = false`, `window-decoration = none` → una sola barra, la de hyprbars; con `hyprbars:no_bar` perdería los botones de ventana). Clase real: `com.mitchellh.ghostty`. kitty sigue instalado y desplegado, sin usarse por defecto. Ghostty 1.3 crea un `~/.config/ghostty/config.ghostty` vacío al abrirse; la migración 005 lo respalda y enlaza el directorio al repo (el archivo `config` se sigue leyendo).
- **Cristal líquido solo en Ghostty:** `hg.config({ enabled = false })` + etiquetas por ventana. Un solo `tag = "+a +b"` crea **una** etiqueta con espacio: hacen falta reglas separadas para `+hyprglass_enabled` y `+hyprglass_preset_dragon-liquid`. Los tags de reglas viejas persisten en las ventanas ya abiertas (Brave conserva uno de `hyprglass_disabled`, inofensivo con `enabled = false`). `dragon-liquid` hereda de `glass`; con 5.0 de refracción, bevel de 8 px y `background-opacity = 0.35` se ve el fondo desenfocado y el borde coloreado (a 1.2 con 0.55 de opacidad quedaba una mancha oscura).
- **Cristal visible en las capas:** diagnóstico con `hyprctl hyprglass stats`: las capas sí se dibujan (`layer_draws`, `layer_hit` suben con la barra, un popover y una notificación); lo que lo tapaba era el relleno casi opaco. `glassAlpha` 0.30 (islas), `popoverAlpha` 0.42 (paneles), `mask_threshold` 0.15, presets más marcados (`refraction_strength` 0.8, `bevel_strength` 0.5, `specular_strength` 0.8) y menos oscurecimiento (`adaptive_dim` 0.6 / 0.7, brillo 0.9 / 0.85), con sombra de texto (`MultiEffect`) solo en textos e iconos de la barra. Comprobado con capturas sobre un fondo oscuro y otro casi blanco.
- Migración `005-ghostty-glass.sh`: instala ghostty y enlaza `~/.config/ghostty`.

## 7i. Cristal líquido "oficial" y valores finales (2026-10-07)

- **(Corregido en §7j)** **Franja opaca de Ghostty:** era la barra de hyprbars (`bar_color` `rgba(161925ee)`). Probado: `hyprbars:no_bar` quita franja y botones; `["hyprbars:bar_color"] = "rgba(00000000)"` (regla de ventana en `plugins.lua`, dentro del guarda de hyprbars) deja la ventana entera de cristal **y conserva** los botones y el título → elegida. Además `window-decoration = none` + `gtk-titlebar = false` en Ghostty.
- **`dragon-liquid`** parte de los valores por defecto (no de `glass`): blur 1.6 / 3 iteraciones, refracción 0.6 con `refraction_spread` 0 y `refraction_flow` 0.3, `edge_thickness` 0.06, `lens_distortion` 0.1, aberración 0.4, specular 0.7, fresnel 0.5, bevel 0.5 de 3 px, `self_sample` 0, tinte `0x0b102060`; dark: brillo 1.0, contraste 1.0, saturación 0.9, `adaptive_dim` 0.5. Ghostty `background-opacity = 0.65`.
- **Comparación en vivo** (Ghostty de prueba, cerrado por dirección con `hl.dsp.window.close({ window = "address:…" })`; **nunca `pkill ghostty`**, mataría la terminal desde la que se trabaja): con tinte `0xb0` (el valor sugerido, 69 %) y opacidad 0.7 la ventana era casi opaca y el fondo no se intuía; con `0x50`–`0x60` y opacidad 0.5–0.65 se ve el fondo desenfocado. Con brillo 1.1 / `adaptive_dim` 0.2 sobre un fondo casi blanco el prompt magenta se leía mal; 1.0 / 0.5 se lee bien en oscuro y en claro. Preferencia final: la combinación de arriba.
- **Capas:** `dragon-bar` y `dragon-panel` reescritos con el mismo enfoque (defaults, `refraction_spread` 0, `lens_distortion` 0.1): bar `blur_strength` 2.2, `edge_thickness` 0.2, tinte `0xc50ed214`, dark brillo 0.9 / dim 0.6; panel hereda y pone `edge_thickness` 0.06, tinte `0xc50ed233`, brillo 0.85 / dim 0.7. Capturas de la barra, el popover de Sonido y una notificación sobre fondo oscuro y casi blanco: esquinas limpias y texto legible; el popover queda bajo su cápsula.
- La skill `dragon-island` pasó a la versión actualizada del usuario sin la sección de migraciones; se restauró.
- Migraciones: la 005 ya cubre Ghostty + cristal + popovers (todo lo demás vive en el repo); no hace falta otra.

## 7j. Banda oscura bajo la barra de Ghostty (2026-10-07)

- **Síntoma:** sobre el cristal de Ghostty, bajo la barra de título, una banda ~40 px más oscura con esquinas superiores redondeadas y el cristal "de verdad" debajo; además la barra de Ghostty (transparente) no se parecía a la de las demás ventanas.
- **Diagnóstico por eliminación** (ventana de Ghostty nueva y la del usuario): no es el cristal (con `-hyprglass_enabled` seguía), ni la cabecera GTK (`gtk-titlebar`, `gtk-tabs-location=hidden`, `window-show-tab-bar=never`, `window-theme=ghostty` no la quitaban), ni el borde del preset (`edge_thickness` 0.06 → 0.02 no cambió nada). Con `hyprbars:no_bar` desaparecía y con **`bar_blur = false`** también: el blur nativo de hyprbars pintaba una banda oscura sobre los primeros ~40 px de la ventana translúcida.
- **Corrección:** `bar_blur = false` en `plugins.lua` (la barra, `rgba(161925ee)`, es casi opaca: apenas cambia en el resto de ventanas) y se quita la regla `hyprbars:bar_color` transparente: la barra de Ghostty vuelve a ser idéntica a la de las demás. `edge_thickness` vuelve a 0.06.
- Sin migración nueva: es solo configuración del repo (symlink o copia con `update.sh`).

## 7k. Las capas con el mismo cristal líquido que Ghostty (2026-10-07)

- **Por qué se veían más sobrias:** las había suavizado yo (refracción 0.6 con `refraction_spread` 0, `adaptive_dim` 0.6–0.7), su relleno de Quickshell (30 % / 42 %) tapaba el cristal, el borde con refracción de una isla de 40 px mide ~8 px y el fondo era liso.
- **Ahora:** `dragon-bar` (`edge_thickness` 0.2, `bevel_size` 2, blur 2.0), `dragon-card` (notificaciones, 0.12, bevel 2.5) y `dragon-panel` (popovers, lanzador, selector, 0.06) **heredan de `dragon-liquid`** (mismos valores: refracción 0.6 solo en el borde, specular 0.7, fresnel 0.5, bevel 0.5, tinte navy `0x0b102060`, dark brillo 1.0 / `adaptive_dim` 0.5). Rellenos más transparentes: `glassAlpha` 0.18, `popoverAlpha` 0.30; `mask_threshold` 0.1.
- **Verificado** con capturas sobre el fondo "GTA" (detalle: se ve la cara desenfocada a través del calendario y de la notificación) y sobre un fondo casi blanco: cristal visible, esquinas limpias, texto legible gracias a la sombra de texto y al `adaptive_dim`.
- Aviso: mis pruebas con `awww img …` cambiaban el fondo real sin pasar por el servicio; se restauró con `qs ipc call wallpaper set "$(qs ipc call wallpaper current)"`.

## 7l. Cristal líquido en toda ventana translúcida (2026-10-07)

- `hg.config({ enabled = true, default_preset = "dragon-liquid" })`: ya no es una lista blanca de Ghostty. Exclusiones por regla de ventana (`+hyprglass_disabled`, regex `(?i)` sin distinguir mayúsculas): navegadores, editores de código y IDE (VS Code y derivados, Cursor, Zed, JetBrains, Antigravity, Kate…), pantalla completa y reproductores de vídeo. Probado abriendo ventanas con clase `Code`, `Google-chrome`, `jetbrains-idea`, `Antigravity` y `org.kde.kate`: todas con `hyprglass_disabled`; `neovide` (Neovim GUI) sin la etiqueta. Neovim en terminal hereda el cristal de su terminal.
- `inactive_opacity` 0.95 → 1.0 en `look.lua`: con 0.95 toda ventana inactiva era translúcida y se habría llenado de cristal.
- kitty: `background_opacity 0.65` (como Ghostty). No se tocó el proceso de kitty en marcha: el cambio de opacidad se aplica al reiniciarlo; el cristal (compositor) ya actúa sobre su transparencia actual (0.85).
- Otros componentes de Quickshell: barra, notificaciones, popovers, lanzador y selector ya tienen cristal por capa. Los menús de la bandeja (`QsMenuAnchor`, xdg-popups) y el `DebugPanel` (dev) no se han tocado ni comprobado.
- Migración: no aplica (todo en el repo).

## 7m. Islas dinámicas (2026-10-07)

- **Servicios nuevos:** `Privacy` (PipeWire: nodos `Stream/Input/Audio` que graban de verdad —no monitores de salida, `stream.capture.sink`— = micrófono; `Stream/Input/Video` enlazado a un `Video/Source` = cámara, a un `Stream/Output/Video` del portal = pantalla compartida), `Vpn` (interfaz `proton*`, `tun*`, `wg*`, `ipv6leakintrf*` en `/sys/class/net`), `Caffeine` (+ `IdleInhibitor` en cada ventana de la isla izquierda), `Updates` (`checkupdates` + `paru`/`yay -Qua`, cada 30 min, `run()` abre Ghostty), `BarContext` (la lista de cápsulas contextuales con prioridad), `WorkspacePreview` (estado de la vista previa). `SysStats` guarda el historial de CPU (15 muestras = 30 s) y las velocidades de red (`/proc/net/dev`); `Hypr` expone `submap`, `windowsOn(id)`, `iconFor`, `focusWindow`, `togglePin`, `activeFloating/Pinned`.
- **Cápsulas contextuales:** un slot fijo por tipo (`ContextChip`), así cada una crece / se encoge con animación de ancho y opacidad. `ContextChips` decide con anchos estimados qué cabe en el espacio que deja la isla izquierda + el notch (`Theme.notchSideReserve`); privacidad y grabación (prio ≤ 2) nunca se agrupan; el resto pasa a `+N`, que despliega sus iconos con el ratón.
- **Vista previa de escritorio:** ventana propia `dragon-preview` (`PreviewWindow.qml`, con cristal `dragon-panel`) con `ScreencopyView` de cada `Toplevel` (`hyprland-toplevel-export`), instantánea (`live: false`); hay un retardo de 350 ms para abrir y 280 ms para cerrar.
- **Trampas:** (1) los iconos no se dibujaban tras `update.sh` porque Quickshell arrancó desde un shell sin el entorno de la sesión (sin `QT_QPA_PLATFORMTHEME`): reiniciar con `hyprctl dispatch 'hl.dsp.exec_cmd(...)'` o desde el propio escritorio. (2) `hl.dsp.window.pin` solo vale para ventanas flotantes. (3) Glifos MDI: comprobados renderizándolos (`F0E58` flotar, `F0E51` pantalla; `F0178` y `F0F13` eran otros). (4) La grabación solo se podía iniciar desde el mosaico que el dashboard viejo tenía: ahora `SUPER + SHIFT + R` → `qs ipc call toggles record`.
- **Verificado en vivo:** micrófono (`parecord`), grabación, VPN, actualizaciones, `+N`, vista previa con captura real, acciones de la ventana, gráfica de CPU, popover de privacidad. **Sin verificar:** cámara y compartir pantalla (no hay cámara ni flujo de portal en este equipo; el código sigue el mismo camino por enlaces), submap (hace falta registrar uno), cafeína frente a `hypridle` (se comprueba que la cápsula aparece, no el bloqueo), pulso de batería baja, auriculares Bluetooth.
- Capturas en `docs/screenshots/islas/`. Migración `006-dynamic-islands.sh` (`pacman-contrib`).

## 7n. Isla derecha más estrecha (2026-10-07)

- Sin cápsula de campana: notificaciones y actualizaciones viven en el popover del reloj (`CalendarPopover` = calendario | `NotificationsColumn`: lista, No molestar, «Borrar todo», contador de actualizaciones y «Actualizar»). `ShellState` redirige el panel `notifications` a `calendar` (SUPER+N, mosaicos del notch). El reloj muestra marcadores (No molestar, sin leer, actualizaciones) y el clic derecho alterna No molestar.
- El micrófono en uso es un punto naranja sobre el icono de volumen y una tarjeta «Micrófono en uso» en el popover de Sonido; la cápsula de privacidad solo sale para cámara y pantalla compartida.
- Sin migración (todo está en el repo).

## 7o. Lanzador orbital (2026-10-07)

- `modules/launcher/Launcher.qml` (mismo panel `launcher`, SUPER+Espacio): planeta de cristal de 200 px con el campo de búsqueda y anillo elíptico inclinado (rx 320, ry 90, −10°) de iconos de 48 px que gira una vuelta cada 40 s. Los de atrás (sin(θ) < 0) son más pequeños (≈ 0,6), tenues y pasan **detrás** del planeta (z negativo); los de delante, ≈ 1,15 y nítidos, con su nombre debajo. Búsqueda vacía: favoritos + más usados (con relleno alfabético si hay menos de 8); más de 16 resultados → segundo anillo exterior, más grande y tenue, que gira al revés. Un delegado por app instalada: las que no coinciden se desvanecen y el resto se redistribuye (`aj` / `an` con `SpringAnimation`). Selección con `SpringAnimation` y `modulus` 2π; la rotación automática es un `FrameAnimation` que solo corre con el lanzador abierto. Una sola coincidencia: el anillo se detiene, el icono va al frente, crece (×1,55) y brilla en el acento.
- `Apps`: favoritos, `ringEntries`, `calc` (solo dígitos y `+ - * / ( ) . % ^`, `Function` en modo estricto), `copy` (`wl-copy`), `runInTerminal` (Ghostty). Estado en `~/.local/state/dragon-island/launcher.json` (migración 007 trae el historial viejo).
- **Trampa:** el proveedor `image://icon/` devolvía pixmaps en blanco para casi todos los iconos de aplicaciones dentro de la ventana del lanzador (sí iba en la barra); se resuelven a archivos con `scripts/icon-paths.sh` y se dibujan como `file://`. Otras: reiniciar Quickshell al editar a veces exige `touch shell.qml`; una `Behavior on opacity` dentro del repetidor no avanzaba con el elemento invisible (se quitó).
- **Sin verificar:** `=expresión` y `>comando` (el código está, no se probaron con el teclado virtual), el segundo anillo (hay menos de 16 resultados con el historial actual) y la rueda del ratón.

## 8. Cómo depurar rápido

```sh
qs -p ~/.config/quickshell          # recarga en caliente
qs log -f                           # errores archivo:línea
qs ipc show                         # funciones IPC registradas (shell, debug)
qs ipc call debug toggle            # valores en vivo de los servicios
hyprctl configerrors; hyprpm list; hyprctl plugin list
```
