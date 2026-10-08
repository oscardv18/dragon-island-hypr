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
- **update.sh** (`./install.sh --update` es un alias): pull → migraciones → paquetes → configs → plugins → recarga → resumen. Las ayudas comunes con `install.sh` viven en `lib/common.sh`; las migraciones cargan `lib/migration-env.sh` (también se pueden ejecutar solas). `install.sh` ahora guarda `components` y `link-mode` en el estado y marca todas las migraciones como aplicadas en una instalación nueva; en instalaciones anteriores `update.sh` los infiere del manifiesto.
- **Regla:** todo cambio que afecte a sistemas ya instalados lleva migración (`migrations/NNN-*.sh`, ver `migrations/README.md` y la skill `dragon-island`).
- `shellcheck` no estaba instalado: se usó `shellcheck-py` en un venv (0.11.0). `update.sh`, `install.sh`, `installer/*.sh` y `migrations/*.sh` pasan `shellcheck -x`.
- **zsh + starship (importados, no reescritos):** `config/zsh/.zshrc` es el `.zshrc` del usuario (oh-my-zsh, `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)`, `eval "$(starship init zsh)"`) más la línea que carga `~/.zshrc.local`; no había secretos que mover. oh-my-zsh y los dos plugins son clones de git (`ensure_omz` en `lib/common.sh`); `zsh` y `starship` salen de `extra` (`@zsh` en `packages/pacman.txt`; starship ya estaba en `/usr/local/bin` y `update.sh` no lo reinstala si el comando existe). Colores de starship pasados a la paleta (decisión del usuario). Componente opcional `zsh` en el instalador y migración `002-zsh-starship.sh` (backup + symlinks, `chsh` con confirmación). `kitty.conf` abre zsh si existe.
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

## 7p. Rendimiento en una píldora y texto nítido (2026-10-07)

- CPU y RAM son **una sola** cápsula (`perfCap`); no se despliega nada con el ratón. El popover de Rendimiento gana la gráfica de CPU de los últimos 30 s.
- **Texto e iconos pixelados:** lo causaban las sombras `MultiEffect` (`layer.enabled`) de `UiText` / `Glyph`: el texto pasa por una textura y pierde nitidez (se ve borroso y con bordes escalonados). Se apagaron con `Theme.textShadows = false` (el tipo `shadow: true` sigue existiendo por si se quiere probar de nuevo). Comprobado ampliando capturas antes y después.

## 7q. Dock en arco (2026-10-07)

- `services/Dock.qml` (estado `~/.local/state/dragon-island/dock.json`), `modules/dock/DockWindow.qml` (namespace `dragon-dock`, capa Top: una ventana de pantalla completa a lo largo del borde con máscara solo en el arco / menú / abanico) y `DockEdge.qml` (`dragon-dock-edge`, zona sensible de 3 px, sin píxeles). Arco = `Shape` + `PathArc` de 520 × 90 rellenos con `Theme.popoverBg` (cristal `dragon-panel`); los iconos van por una parábola poco profunda con ligera inclinación y la ampliación es una gaussiana a lo largo del arco. Para `left` / `right` se gira el marco 90° y los iconos se contragiran.
- **Ocultado:** `workspaceFree` = el escritorio enfocado no tiene ventanas que no floten (se reevalúa ~300 ms después de los eventos `openwindow`, `closewindow`, `movewindow`, `workspace`, `fullscreen`, `changefloatingmode`, refrescando `Hyprland.refreshToplevels()`); se hunde con un `SpringAnimation`.
- **Minimizar:** `hl.dsp.window.move({ workspace = "special:minimized", follow = false })`; las ventanas con ese escritorio salen atenuadas y un clic las trae al escritorio actual.
- **Trampas:** `HyprlandToplevel.address` no lleva `0x` (los dispatchers lo exigen: `Hypr.addr()`); la propiedad `index` de un delegado del `Repeater` tapa a una propia llamada `index` (ahora `slotNo`); un `Shape` no tiene `parent` en sus `ShapePath` (usar `id`); con `left` / `right` la ventana debe anclarse arriba **y** abajo.
- **Verificado en vivo:** arco visible en un escritorio vacío, oculto con una ventana en mosaico, zona sensible, ampliación, menú contextual, minimizar + restaurar con un clic, posiciones izquierda y derecha. **Sin verificar:** abanico de descargas, reordenar arrastrando, insignias de notificaciones, clic central, ciclar entre ventanas de una app, `SUPER + M` real (se probó el mismo dispatcher a mano), dock en un segundo monitor.
- Sin migración: el estado lo crea el propio servicio y los atajos / reglas llegan con `config/hypr`.

## 7r. Dock en semidona, islas fluidas y lanzador con píldoras de cristal (2026-10-07)

- **Dock:** ya no es un segmento relleno sino una **franja** (`Theme.dockBand` 66 px) curvada, hueca por dentro: el `Shape` dibuja el arco exterior, el borde de la pantalla y el arco interior de vuelta, con `Theme.glassBg` y el borde de 1 px como las islas. Cada app va en una **cápsula circular** (`surface2`, 54 px, icono de 36) sobre la línea central de la franja; la inclinación sigue la curva (×0,4) y la ampliación es más contenida (×1,4). Ángulo entre vecinos `min(56 px / R, 0,56 rad / huecos)`.
- **Islas con retraso al expandirse / contraerse:** las ventanas de las islas seguían (`implicitWidth`) el ancho animado de la isla, y redimensionar una superficie de capa es un viaje de ida y vuelta al compositor: el contenido se recortaba y la contracción llegaba tarde. Ahora cada ventana tiene un ancho **constante** (izquierda: el máximo que puede ocupar; derecha: 47 % de la pantalla), es transparente alrededor, la isla va anclada dentro (a la derecha, en la derecha) y la máscara de entrada es la isla (`Region { item: isla }`). hyprglass sigue la forma por el alfa, así que el hueco transparente no cuesta nada. `windowX` del popover pasa a ser la `x` constante de la ventana.
- **Lanzador:** detrás de cada icono hay una **píldora circular** translúcida (`popoverBg` + borde; en el icono de delante, tinte de acento) que la capa del lanzador convierte en cristal líquido.

## 7s. Dock: proporciones y desplazamiento con la rueda (2026-10-07)

- (Superado por §7u) Franja de 72 px, cápsulas de 52 px con el icono a 30 (antes 54 / 36: el icono rozaba el borde); las cápsulas van centradas en la línea media de la franja (radio medio). Las píldoras del lanzador pasan a `orbitIcon + 32`.
- **Rueda del ratón:** el dock no crece nunca. Hay `Theme.dockSlotsPerSide` (3) huecos por lado; si hay más apps, la rueda gira cada lado por separado (según de qué lado del centro esté el puntero) con un spring y las cápsulas que pasan del último hueco se desvanecen «bajo la pantalla»; hacia el botón central se desvanecen antes de cruzarlo (`side`: −1 fijadas, +1 abiertas, 0 centro). La carpeta de descargas forma parte de la lista de la derecha.
- Bug: con el estado cargado antes de que `DesktopEntries` terminara de escanear, las apps fijadas quedaban vacías para siempre (la propiedad no dependía de la lista de entradas); ahora `pinnedItems` lee `DesktopEntries.applications.values`.

## 7t. Wi‑Fi sin expansión y cristal «de verdad» en el dock y el lanzador (2026-10-07)

- La cápsula de Wi‑Fi ya no se expande con el ratón (quitaba sitio al notch): bajada / subida están en una tarjeta del popover de Wi‑Fi.
- Lanzador: el nombre de la app ya no se pinta sobre el borde de la píldora del icono; va en su **propia píldora de cristal** debajo (`nameText` dentro de un `Rectangle`).
- **Bordes planos en el dock y el lanzador:** hyprglass calcula el relieve del borde (bisel, especular, fresnel) a partir del **rectángulo de la capa**, no de la forma que hay dentro (la máscara por alfa solo recorta). En las islas se nota porque su ventana tiene casi su tamaño; en el dock (1366 × 300) y el lanzador (pantalla completa) el borde queda fuera de la forma, así que las formas curvas salían planas aunque el preset fuera extremo (probado con `edge_thickness` 0,16 y refracción 3: sin cambio). Solución: `components/GlassRim.qml` (luz que cae desde arriba, borde brillante en la mitad superior, borde tenue completo y una línea oscura bajo el borde inferior) y `components/BandShape.qml` (la semidona dibujada tres veces: relleno, degradado de luz y borde interior de 3 px) pintados en QML encima del cristal de hyprglass (que sigue dando desenfoque y refracción). Presets `dragon-dock` y `dragon-orbit` en `glass.lua` (bisel y especular al máximo; el relieve del rectángulo de la capa sigue sin verse).
- Pendiente de decisión: las islas de la barra pasaron a ventanas de ancho constante (fluidez), así que su relieve de hyprglass solo aparece en los bordes de la ventana; si quieres el mismo `GlassRim` en las islas hay que añadirlo en `LeftIsland` / `RightIsland`.

## 7u. Dock fino, sin ampliación y contornos en degradado (2026-10-07)

- **Sin ampliación** (efecto macOS): el icono bajo el puntero ya no crece (`grow = 1`); se resalta con su contorno en el degradado de la ventana (accent → violet → cyan), de 1,2 px tenue a 2 px pleno al pasar el ratón. El problema de «intenta ampliarlo pero no pasa» era la escala animada bajo el puntero moviendo el área clicable.
- **Contornos:** `components/BorderGradient.qml` (el degradado como fuente) + `components/GradientRing.qml` (anillo enmascarado con `MultiEffect.maskEnabled`) sustituyen al borde blanco de `GlassRim` (que ahora solo da luz y profundidad). El dock lleva el contorno de la franja subtil (0,5), las cápsulas 0,4 (1 si hay ratón encima); el lanzador, el planeta (0,9), las píldoras (0,75; la de delante 2,5 px al 100 %) y la píldora del nombre (0,6).
- **Dock más fino:** la franja pasa a 48 px (como las islas), 440 × 90, cápsulas de 36 con icono de 22, separación 42 px y 4 huecos por lado.

## 7v. Dock: hover estable y contornos más finos (2026-10-07)

- **Subía y bajaba con el cursor encima:** el `HoverHandler` estaba en un `Item` hermano de las cápsulas; al pasar sobre una cápsula (con su propio `MouseArea`) el dock creía que el cursor salía y se ocultaba, luego reaparecía, etc. Ahora `HoverHandler` y `WheelHandler` cuelgan del propio `arc` (padre de las cápsulas) con margen de 8 px. Verificado: 8 s con el cursor sobre un icono sin parpadeo; se oculta al quitarlo.
- Contornos más finos: cápsulas 1 px (1,4 al hover), franja 1 px al 40 %; lanzador 1–1,6 px. Máscaras supermuestreadas ×2.
- Limitación: el borde exterior de la franja se ve algo escalonado porque el recorte alfa de hyprglass (`mask_threshold`) es un corte duro por píxel; no se puede suavizar desde QML.

## 7w. Dock y lanzador: mismo acabado que las islas + cristal visible (2026-10-07)

- Se quitaron los contornos en degradado y los brillos blancos (`GradientRing`, `BorderGradient`, `GlassRim` quedan sin usar). Franja, planeta y píldoras llevan relleno translúcido y un borde de 1 px gris muy tenue (`Theme.glassRim`, blanco 17 %).
- Las cápsulas del dock y las píldoras del lanzador usan `Theme.pillBg` / `pillBgHi` (surface2 al 38 %) en vez del `surface2` opaco, que tapaba el cristal de hyprglass: ahora se ve el desenfoque detrás de cada píldora. Preset `dragon-dock` con `blur_strength` 4.

## 7x. Dock: arreglo del clic / parpadeo y solo aplicaciones (2026-10-07)

- **Bug real:** la zona sensible era una ventana aparte (`DockEdge`, 3 px). Al pasar el puntero de ella a la ventana del dock, el dock subía y se hundía a la vez y los clics no llegaban (reproducido con uinput: 3 de 3 intentos sin clic). Ahora la franja de 3 px es un `Item` (`strip`) **dentro de `DockWindow`** y entra en la máscara de entrada solo cuando el dock está oculto: una sola superficie, sin traspaso. `DockEdge.qml` eliminado. Verificado: sube, se queda, clic en Ghostty → workspace 3, clic en Brave → workspace 1.
- **Solo aplicaciones:** quitados el botón del lanzador y la carpeta de descargas (con su abanico). Una sola banda centrada (fijadas primero, luego las abiertas), 8 huecos; la rueda desplaza la banda entera y los extremos se desvanecen bajo el borde.

## 7y. Dock como pestaña de cristal (2026-10-07)

- Se descarta la semidona. El dock es una **pestaña de cristal que sobresale del borde** (abajo, izquierda o derecha, `Dock.position`), como el notch pero desde el otro lado: una capa `dragon-dock` del **tamaño exacto** de la pestaña (así hyprglass dibuja el mismo liquid glass con borde que en Ghostty: preset `dragon-liquid` tal cual), esquinas exteriores redondeadas por un `Rectangle` que se pasa del borde de la pantalla. Se oculta hundiéndose (el contenido sale de la ventana). Sin bordes blancos ni degradados en el dock ni en el lanzador (el lanzador usa también `dragon-liquid`; sus formas siguen sin relieve de borde porque la capa es de pantalla completa).
- Cápsulas con `Theme.pillBg` (translúcidas), icono de 28 en cápsula de 44, paso de 54, hasta 8 a la vez (`dockCapacity`); más → rueda. Nombre al pasar el ratón y menús como `PopupWindow`.
- **Menú del dock:** clic derecho sobre el cristal → Abajo / Izquierda / Derecha y «Siempre visible». Clic derecho en una app → su menú (fijar, nueva ventana, cerrar, mover a).
- Lecciones: (1) `Region { item }` NO sigue el movimiento de un ancestro: usar un `Item` fijo (`hitbox`); (2) la franja sensible debe quedarse en la máscara mientras la pestaña sube y el hover es la unión franja ∪ pestaña; (3) el `index` requerido del delegado pisa una propiedad `index` del Slot (`slotIdx`).
- Eliminados `BandShape`, `GlassRim`, `GradientRing`, `BorderGradient`.

## 7z. Dock con la silueta del notch y planeta con ventana propia (2026-10-07)

- **Dock = notch desde el otro borde:** negro opaco (`Theme.island`), misma silueta (`NotchShape`: orejas cóncavas junto al borde y esquinas redondeadas lejos) girada hacia el borde (abajo 180°, izquierda −90°, derecha 90°), grosor 40 px (= altura de las islas), cápsulas de 30 (icono 20) con `surface2` / `surfaceHi` como las de las islas. El namespace `dragon-dock` está **excluido** de hyprglass (`glass.lua`) y fuera de las reglas de blur nativo. Solo aplicaciones. Menú del dock con clic derecho sobre la pestaña.
- **Planeta del lanzador con cristal real:** `modules/launcher/PlanetGlass.qml`, ventana de 200 × 200 (namespace `dragon-launcher`, centrada, sin entrada, mapeada al arrancar para quedar bajo el anillo) con el disco de cristal; así hyprglass dibuja el relieve de su borde. El disco dentro de `Launcher.qml` quedó transparente (solo conserva el campo de búsqueda). Las píldoras de los iconos siguen dentro de la capa de pantalla completa (sin relieve de borde: haría falta una ventana por icono, que además orbitan).

## 7m. Iconos Candy + Sweet Folders sin KDE (2026-10-07)

- Tema `Sweet-Purple` (hereda de `candy-icons`; la lista real de `/usr/share/icons` tiene los `Sweet-*` de `sweet-folders-icons-git`). `QT_QPA_PLATFORMTHEME` pasa de `kde` a `hyprqt6engine` (confirmado por el usuario) solo en `env.lua`. Opciones del `.conf` comprobadas en el plugin instalado: `theme:{color_scheme, icon_theme, style, font, font_size, font_fixed, font_fixed_size}` y `misc:{single_click_activate, menus_have_icons, shortcuts_for_context_menus}`; se busca `hypr/hyprqt6engine.conf` en `XDG_CONFIG_HOME`. Sin `color_scheme` Qt cae a una paleta clara: se usa `/usr/share/color-schemes/BreezeDark.colors` porque no hay esquema Sweet.
- GTK: `settings.ini` (3.0 y 4.0) enlazados + dconf. Plasma también los lee: avisado en el README.
- Quickshell: `//@ pragma IconTheme Sweet-Purple`.
- Verificado: el Dolphin lanzado por Hyprland tiene `QT_QPA_PLATFORMTHEME=hyprqt6engine` en `/proc/<pid>/environ` (hl.env se aplica tras `hyprctl reload`), carpetas moradas de Sweet, iconos Candy y tema oscuro; dock y lanzador orbital con iconos Candy; `gsettings` devuelve `Sweet-Purple`.
- `update.sh`: un `git pull` fallido (sin red / sin clave SSH: el remoto ahora es `git@github.com`) y un paquete que no se puede instalar sin terminal son avisos, no abortan; el paquete queda anotado en el resumen.
- Migración `008-icon-theme.sh`: paquetes AUR, `settings.ini`, gsettings y aviso de reiniciar las apps Qt abiertas.

## 7n. Lanzador orbital: los iconos de atrás pasan DETRÁS del planeta (2026-10-07)

- **Causa:** el disco de cristal es `PlanetGlass`, una ventana propia; los iconos eran hijos de `LauncherWindow`, que se mapea después, así que **todos** (también los de `depth < 0`, cuyo `z` negativo solo cuenta dentro de su propia ventana) se dibujaban por encima del disco.
- **Corrección:** el anillo se reparte en dos ventanas y el orden de mapeo (las ventanas de una misma capa se apilan en ese orden) pasa a ser: `OrbitBack` (iconos con `depth < -0.15`, ventana de 1027×400 centrada, sin entrada) → `PlanetGlass` → `LauncherWindow` (iconos delanteros + buscador). `OrbitIcon.qml` es el delegado común (`half: "back" | "front"`, misma matemática desde el estado del `Launcher`); un icono solo se ve en una de las dos. Los de atrás se ven desenfocados a través del cristal del planeta.
- **Orquestación:** `OrbitalLauncher.qml` (un `Scope` por monitor) mapea las tres ventanas por etapas con 45 ms de diferencia y las desmapea 900 ms tras cerrar; cerrado, ninguna está mapeada (también ahorra GPU: `PlanetGlass` antes estaba siempre mapeada). La ventana del lanzador espera a la etapa 3 solo para el panel `launcher`; el menú de energía, el portapapeles y los atajos abren como antes.
- Verificado: `hyprctl layers` lista las tres en ese orden (1027×400, 200×200, pantalla) y, en capturas seguidas, los iconos que cruzan por encima del planeta quedan tapados por el disco, mientras los delanteros lo cubren.
- Sin migración: solo archivos del repo (`update.sh` reinicia Quickshell).

## 7o. Dock y lanzador con los iconos de Candy de verdad (2026-10-07)

- **Causa:** `scripts/icon-paths.sh` (que da a Apps los archivos de icono del dock y del lanzador, porque el image provider devolvía pixmaps vacíos) buscaba primero en `hicolor` y `pixmaps` —los iconos propios de cada app— y solo después en «cualquier tema»: Ghostty, Dolphin y casi todo lo que traía su icono salían con el original aunque Candy lo tuviera. Solo se veía Candy en las apps sin icono hicolor (Brave), por casualidad.
- **Corrección:** el script lee el tema de `//@ pragma IconTheme` de `shell.qml` (una sola fuente de verdad, `ICON_THEME` lo sustituye), sigue su cadena `Inherits` (Sweet-Purple → candy-icons → breeze-dark → Adwaita …) y solo después usa hicolor / pixmaps / otros temas. Verificado: Ghostty, Dolphin y Brave → `candy-icons/apps/scalable`; pavucontrol (sin icono Candy) → hicolor; carpetas → `Sweet-Purple/Places`.
- Capturas del dock y del lanzador orbital: todos con el estilo neón de Candy.
- Sin migración (archivo del repo; `update.sh` reinicia Quickshell).

## 7p. Planeta del lanzador sin parches blancos (2026-10-07)

- **Causa:** la ventana del planeta mide justo lo que el disco, y hyprglass dibuja el relieve del borde (bevel, specular, fresnel, refracción) a partir del **rectángulo** de la capa: en un círculo solo se ve donde toca el cuadrado (arriba, izquierda…), como parches blancos.
- **Corrección:** `PlanetGlass` pasa a su propio namespace `dragon-planet` con el preset `dragon-planet` (hereda de `dragon-liquid`, con bevel / specular / fresnel / refracción / aberración a 0: solo desenfoque y tinte). Añadido a las listas de reglas nativas de respaldo y de `no_anim`.
- Nota de operación: lanzar `qs -d` a mano de más deja procesos `qs -d` colgados que bloquean `qs ipc`; reinicia con `kill` del PID y `quickshell`.

## 7q. Tienda de apps (pacman + AUR), SUPER + I (2026-10-07)

- **Piezas:** `services/Store.qml` (datos y acciones), `scripts/store.sh` (lecturas, solo lectura, `LC_ALL=C`), `modules/store/StorePanel.qml` + `StoreWindow.qml` (capa `dragon-store`, liquid glass por alfa con el preset `dragon-panel`), `bin/dragon-pkg` (acciones con privilegios, enlazado en `~/.local/bin`) y la regla de ventana flotante 900×520 para la clase `org.dragonisland.Pkg` (la clase de Ghostty necesita puntos). Atajo `SUPER + I`, IPC `shell toggle store` y prefijo `+nombre` del lanzador orbital (`Store.pendingQuery`).
- **Búsqueda:** `pacman -Sl` y `paru|yay -Slqa` (121 k nombres; caché en `~/.cache/dragon-island/aur-list.txt`, refresco diario) se buscan con `awk` en un `Process` (≈0,3 s), no en QML; espera de 200 ms; los oficiales van primero y los coincidencias exactas / por prefijo / por subcadena antes que las difusas (estas solo en oficiales). Detalles tras 300 ms (`pacman -Si`, `-Siia`); PKGBUILD con `-Gpa`.
- **Hechos de las herramientas** (comprobados, no supuestos): `pacman -Rnsp` no existe (`--nosave` y `--print` chocan) → la vista previa de eliminación usa `pacman -Rsp --print-format '%n'`, y cuando una dependencia lo impide muestra el error de pacman; los nombres de campo salen en español sin `LC_ALL=C`; `notify-send -A` implica `--wait` (la acción «Ver registro» corre en un `sh` aparte).
- **Terminal, nunca Quickshell, para contraseñas:** `dragon-pkg` hace `sudo -v` + keepalive, `pacman -S --needed`, AUR sin `--noconfirm`, `-Rns`, `-Syu` o `paccache -r`; escribe `pkg-status.json` (el panel lo vigila con `FileView`) y `pkg.log`; el panel notifica, refresca las listas, `Updates` y los `.desktop` nuevos aparecen solos en el lanzador. `DRAGON_PKG_DRYRUN=1` ejecuta todo sin sudo (así se probó el flujo completo: ventana flotante, notificación «(simulación)»).
- **Mis apps:** `dragon-pkg` mantiene `packages/user-pacman.txt` / `user-aur.txt`; componente opcional del instalador (`--myapps`) y `update.sh` ofrece las que falten; esos dos archivos no cuentan como «cambios locales» al comprobar el árbol.
- **Actualizaciones:** la pestaña carga `checkupdates` + `-Qua` y fija `Updates.repoCount/aurCount` (contador de la isla derecha y de la propia pestaña).
- Migración `009-store.sh` (pacman-contrib, enlace de `dragon-pkg`).
- **Sin probar con sudo real** (no hay terminal para la contraseña desde aquí): la instalación / eliminación reales de `cowsay` y de un paquete AUR quedan para la checklist `docs/TESTING.md` §12e.

## 7r. Lista de atajos al día (2026-10-07)

- El panel `SUPER + F1` lee los binds de Hyprland por su descripción (así ya sale «Shell · Tienda de apps»); las teclas **dentro** de los paneles (lanzador orbital con `=`, `>`, `+`, Tienda, fondos, portapapeles, energía) no son binds: ahora están en `panelGroups` de `services/Keybinds.qml` y se pueden buscar en el panel. `docs/KEYBINDS.md` (tabla «Teclado dentro de los paneles», IPC) igualado. Regla anotada en la skill `dragon-island`: cada atajo o tecla nueva actualiza `binds.lua` (con descripción), `panelGroups` y KEYBINDS.md.

## 7s. Sistema lento por un vídeo 4K de fondo (2026-10-07)

- **Síntoma:** menús y sistema «lentos» con recursos libres. **Causa:** GPU al 70–78 % (`gpu_busy_percent`) por `mpvpaper` reproduciendo un HEVC de 3840×2160 a 30 fps (16 Mbps) en un portátil de 1366×768 con iGPU; con `kill -STOP` al proceso caía al 9 %. CPU, RAM (11 GB libres) y reloj no eran el problema.
- **Corrección:** `scripts/wallpapers.sh apply-video` mira la altura del vídeo (`ffprobe`) y, si pasa en más de un 25 % la de la pantalla (`hyprctl monitors`), reproduce el original al momento y en segundo plano (prioridad baja) genera una copia H.264 del tamaño de la pantalla, sin audio, 30 fps, en `~/.cache/dragon-island/video/<hash>.mp4` (7 s para un clip de 14 s); cuando existe, relanza `mpvpaper` con ella si sigue siendo el fondo actual. mpv usa además `profile=fast`. Las siguientes veces usa la copia directamente.
- **Medido:** GPU 70 % → 12 % con la copia; el cambio automático original → copia comprobado.

## 7t. Terminal avanzada: eza, fzf, fzf-tab, zoxide (2026-10-07)

- **Diagnóstico:** oh-my-zsh con `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)` (clones de git en `custom/plugins`); `oh-my-zsh.sh` carga los plugins y **después** ejecuta `compinit` (línea 238). fzf-tab necesita ir tras `compinit` y antes de autosuggestions / resaltado, así que esos dos salen de `plugins=()` y se cargan a mano después. `fzf --zsh` enlaza Tab (`fzf-completion`): va antes que fzf-tab para que este sea el último en enlazar `^I` (comprobado con `bindkey`).
- **Archivos** (`config/zsh/`, desplegados en `~/.config/dragon-island/zsh`): `history.zsh`, `fzf.zsh` (paleta, `fd`, previsualizaciones; sin terminal no hace nada), `completion.zsh` (zstyles del README de fzf-tab + previsualizaciones por comando, `/` continuo, `<` `>`), `aliases.zsh` (eza + `EZA_COLORS` en truecolor; `cat` → bat). `zoxide init` queda al final con `z` / `zi` y **`cd` normal**: con `--cmd cd` zoxide se mete en funciones y scripts y las vistas previas de fzf-tab perderían las rutas reales.
- **Medido** (`zsh -i -c exit`, 5 pruebas, mismo estado de la máquina): 60 ms antes, 71 ms después (+11 ms, sin carga diferida ni caché extra). La medida inicial de ~140 ms se hizo con la GPU saturada por el vídeo 4K (§7s).
- **Probado en Ghostty con teclado virtual:** `cd ` + Tab (fzf-tab con bordes redondeados, colores Dragonized y vista previa de eza), `git checkout ` + Tab (archivos modificados / head local / ramas remotas con su `git diff`), `Ctrl+R`. El prompt de starship no cambió.
- Paquetes: `eza fzf zoxide fd bat` en `@zsh`; `fzf-tab` por `ensure_omz` (git). Migración `010-terminal-tools.sh`. Las teclas están en el panel `SUPER + F1` (`panelGroups`) y en KEYBINDS.md.

## 7za. dragon-core: bloqueo de Quickshell y tema de login (2026-10-07)

- **Qué es:** pantalla de bloqueo propia (`config/quickshell/modules/lock/`: `Lock.qml` = `WlSessionLock` + `PamContext` + IPC `lock`; `LockView.qml` = la UI) y tema SDDM Qt6 (`sddm/dragon-core/`), con el mismo núcleo neural animado. hyprlock **no se borra**: es el respaldo, re-tematizado con la misma paleta (`config/hypr/hyprlock.conf`, fondo estático `config/hypr/assets/core.png` = el núcleo solo, renderizado con `qml6` desde `shared/neural-core/`; `preview.png` no sirve de fondo porque lleva el reloj y el campo de contraseña dentro).
- **Fuente única del núcleo:** `shared/neural-core/{NeuralCore,CoreIcon}.qml` → `scripts/sync-shared.sh` los copia a `config/quickshell/components/` y `sddm/dragon-core/components/` (lo llaman `install.sh` y `update.sh`; con `--dry-run` solo comprueban con `diff`; `scripts/sync-shared.sh --check` sale con 1 si divergen).
- **Cableado:** `shell.qml` → `Lock { id: lock; notifCount: Notifs.unreadCount }` (único `WlSessionLock`). `SUPER + L` → `qs ipc call lock lock || hyprlock`. `hypridle.conf`: `lock_cmd = pidof hyprlock || qs ipc call lock lock || hyprlock` (`before_sleep_cmd` ya era `loginctl lock-session`; `after_sleep_cmd` sigue con `dpms({ action = "enable" })`, verificado en 0.56.2; `"on"` también devuelve ok pero el repo ya usaba `enable`). `look.lua` → `misc.allow_session_lock_restore = true`. PAM: `/etc/pam.d/hyprlock` (`auth include login`), con caída a `login` si falta. No se toca `/etc`.
- **Migración `012-dragon-core.sh`** (el repo usa `migrations/NNN-*.sh`, no bloques run-once dentro de `update.sh`): sincroniza el núcleo, reinicia `hypridle` (solo lee `lock_cmd` al arrancar) y **pregunta con gum** «¿Instalar el tema de login dragon-core? (pide sudo)»; solo con terminal interactiva y un «Sí» explícito ejecuta `sddm/install-theme.sh` en primer plano (`--yes`, sin gum o sin TTY: no lo instala y lo avisa). `install.sh --dry-run` lo lista sin ejecutarlo.
- **Si el bloqueo muere (pantalla roja):** `Ctrl + Alt + F3` → iniciar sesión; `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` (sintaxis comprobada en 0.56.2 con `exec_cmd("true")`; con `allow_session_lock_restore` hyprlock recupera el bloqueo); `Ctrl + Alt + F1` para volver y desbloquear.
- **Verificado:** `qs -p config/quickshell` carga sin errores (`Configuration Loaded`); el shell vivo expone `target lock` (`lock`, `isLocked`); `hyprctl reload` → `configerrors` vacío; `allow_session_lock_restore: true`; `sddm/install-theme.sh --test` abre el greeter (1366×768, núcleo animado, sin errores en el log); migración 012 en dry-run; `sync-shared.sh --check` en verde.
- **Probado por el usuario (2026-10-07):** el bloqueo real de Quickshell funciona y le gusta; el detalle de cada caso (contraseña mala, Bloq Mayús, etiqueta US/LATAM, reproductor) no se anotó caso por caso.
- **NO verificado:** `hyprlock` como respaldo con el nuevo tema (sin confirmar); 2 monitores (esta máquina tiene 1); rendimiento (si va lento: `pointCount` a 160 en `LockView.pointCount` / `theme.conf`); la instalación del tema SDDM (`sudo`, no ejecutada). Aviso aparte: Quickshell está compilado contra Qt 6.11.2 y el sistema tiene 6.12.0; hay que recompilar el paquete `quickshell`.
- **Revertir:** `sddm/install-theme.sh --uninstall` (tema de login). Bloqueo: quitar `Lock {}` de `shell.qml` y devolver `SUPER + L` a `loginctl lock-session`; hyprlock sigue funcionando.

## 7zb. Lanzador orbital sobre el núcleo neural (2026-10-07)

- **Hecho:** `modules/launcher/LauncherView.qml` (sin tocar, copiado de dragon-core) pinta el lanzador; `Launcher.qml` pasa a ser solo lógica y vive dentro de `LauncherWindow` (una sola ventana `dragon-launcher`, junto a energía / portapapeles / atajos). `shell.qml` instancia `LauncherWindow` directamente.
- **Lógica conservada:** orden `Apps` (anclados → más lanzadas → alfabético) como orden base del anillo, `Apps.launchById` (terminal, contador de uso), `=cálculo` (Enter copia), `>comando` (Enter en Ghostty), `+nombre` (abre la Tienda), IPC `shell toggle launcher`. Los prefijos se resuelven con `Shortcut` (Enter) en el wrapper, sin tocar la vista.
- **Atajos nuevos:** `Ctrl+I` sin coincidencias → Tienda con la búsqueda; `Ctrl+F` ancla/desancla la app del frente (sustituye al clic derecho).
- **Eliminado:** `OrbitalLauncher`, `OrbitBack`, `OrbitIcon`, `PlanetGlass`, tokens `Theme.orbit*`, namespace/preset `dragon-planet` (rules.lua, glass.lua).
- **Verificado (sesión Hyprland real, instancia `qs -p` aparte):** carga sin errores de QML; SUPER+Space (IPC) abre; núcleo + anillo + iconos reales + app en frente (orden por frecuencia, Brave); cierra por IPC.
- **No verificado (no hay wtype/ydotool para teclear):** filtrar, ←/→/Tab/rueda, Enter, Esc doble, clic fuera, 1–2 resultados, núcleo rojo/verde, `reducedMotion`, nitidez en movimiento, `=`/`>`/`+`, Ctrl+I/Ctrl+F, y que la ventana vaya fluida.
- **Riesgos / diferencias a revisar:**
  - La vista pinta un velo oscuro a pantalla completa dentro de `dragon-launcher`, que tiene regla hyprglass (máscara alfa): puede aplicar cristal a toda la pantalla (GPU). Si pasa: quitar el velo de la vista (cambio mínimo: opción `backdrop: false`) porque `dragon-scrim` ya oscurece.
  - La vista filtra solo por nombre/subtítulo: se pierden coincidencias por palabras clave y el bonus por uso en la búsqueda (solo desempata). Cambio mínimo: propiedad `externalFilter` para pasar `Apps.search(query)` ya ordenada.
  - Con `=`/`>`/`+` el núcleo se pone rojo y el contador muestra 0 (la vista los trata como «sin resultados»).
  - Hay solo una pila de teclas: el hint inferior usa glifos (⏎) que pueden salir como cuadro con la fuente actual.
- **Revertir:** `git revert` del commit (aún sin hacer commit; hasta entonces `git checkout -- config/quickshell config/hypr` y restaurar los 4 archivos borrados con `git checkout HEAD -- config/quickshell/modules/launcher`).

## 7zc. Repo ordenado e instalador modular (2026-10-07)

- **Hecho:**
  - **Repo:** una sola copia de los skills (`.agents/skills/`; se borraron las de la raíz y `dragon-island-skills/`), `lib/`, `modules/`, `scripts/`, `tests/`, `docs/`; `installer/` desaparece; `dragon-core/` se fusionó (prompts, mocks, referencia) y se versiona; `shared/neural-core/` es la fuente de NeuralCore/CoreIcon (`scripts/sync-shared.sh [--check]`); LICENSE MIT; `.gitignore` (`out/`, `*.zip`, `config/hypr/local.lua`).
  - **Scripts:** `install.sh` (menú gum, plan, `--dry-run/--yes/--modules/--extras/--no-sudo/--copy`), `update.sh` (por módulos; `hyprpm update` solo si cambió Hyprland), `uninstall.sh` (por módulo; paquetes solo con `--remove-packages`), `doctor.sh` / `doctor.sh --pre`, `bootstrap.sh`.
  - **Módulos:** core, shell, theme, plugins, login, keyring, keyboard, extras (`desc/sudo/check/plan/apply/revert/packages`). Cada paso con sudo se explica y se confirma (`confirm_sudo`); PAM y `/etc` solo en módulos opt-in con diff y `.bak-dragon`. Ajustes por máquina: `~/.config/hypr/local.lua` (se carga el último, probado en la sesión real) y `~/.config/dragon-island/local.conf`.
  - **`pre-instalation.md`** (12 pasos) hecho a partir de esta máquina; `lib/checks.sh` tiene la tabla única comprobación → paso y cada fallo imprime «ver pre-instalation.md, Paso N».
  - **Plugins:** `scripts/plugins-foreground.sh` (hyprbars + hyprfocus + hyprglass, en primer plano) sustituye a `installer/firstrun.sh` + `glass.sh`; `autostart.lua` usa `plugins.pending`. **Migración 013** reenlaza el estado y traduce componentes → módulos.
  - **Paquetes:** `packages/` troceado y verificado; la lista `desc` (apps personales) queda fuera; `opencode`/`genoffice-bin` siguen en «Mis apps» (`user-*.txt`).
  - **Docs:** README, INSTALL, TROUBLESHOOTING, TESTED-VERSIONS, KEYBINDS (con referencia generada por `scripts/gen-keybinds.sh`; se reparó una fila rota de `SUPER + Escape`) y el skill del proyecto.
  - Teclas del lanzador `Ctrl+F` / `Ctrl+I` añadidas al panel `SUPER + F1` y a KEYBINDS (faltaban).
- **Verificado en esta máquina** (`tests/run-all.sh`, sin root):
  - shellcheck limpio en 44 scripts, `bash -n`, `luac -p`, `qmllint` en lanzador / núcleo / bloqueo.
  - `tests/check-docs.sh`: 29 bloques bash de `pre-instalation.md` con `bash -n`, cada paso citado por el código existe con el mismo título, el Paso 3 es `packages/base.txt`, los paquetes de los comandos existen (`pacman -Si` / `yay -Si`), tabla generada al día.
  - Los nombres de `packages/*.txt` existen (`pacman -Si`, `yay -Si`, y el AUR RPC con la misma consulta que usa el contenedor).
  - `tests/idempotency.sh`: core, shell, theme, plugins, keyboard, keyring y extras dos veces en un `$HOME` temporal con shims (sin sudo real): árbol idéntico, un solo bloque en `~/.zshrc`, líneas propias intactas, respaldo creado.
  - `./install.sh --dry-run --yes` completo (los 8 módulos): termina bien, `git status` idéntico y ningún archivo de configuración tocado. `./update.sh --dry-run`, `./uninstall.sh --dry-run`.
  - `./doctor.sh --pre` y `./doctor.sh`: todo ✔ en esta máquina.
- **No verificado** (necesita una instalación limpia o root):
  - Contenedor Arch: `tests/container.sh` está escrito pero **no se ejecutó** (el daemon de docker está parado y `sudo` pide contraseña). Para correrlo: `sudo systemctl start docker && DOCKER="sudo docker" tests/container.sh`.
  - Instalación REAL de punta a punta: `pacman -Syu`, `pacman -S`, `yay -S`, servicios con sudo, `hyprpm update` en una máquina limpia, `sddm/install-theme.sh`, el cambio de PAM (`keyring`), `localectl`, `chsh`, drivers NVIDIA / Intel, Plasma Login Manager, Arch puro (yay vía AUR) y CachyOS.
  - Los menús interactivos de gum (solo se probaron las rutas `--yes` / `--dry-run`).
  - `./update.sh` y `./uninstall.sh` reales (la migración 013 se probó solo con `DRY_RUN=true`; en esta máquina se aplicará con el próximo `./update.sh`) y `bootstrap.sh` (`curl | bash`).
  - El procedimiento de TTY para un bloqueo trabado (TROUBLESHOOTING).
  - **Cómo probarlo todo en una VM de EndeavourOS:** instala la ISO siguiendo `pre-instalation.md` **al pie de la letra** (Pasos 1–9, sin saltarte ninguno), `./doctor.sh --pre`, `./install.sh --dry-run`, `./install.sh` con los módulos por defecto, cierra sesión y entra en Hyprland, `./doctor.sh`; luego repite con `--modules login,keyring,extras` y por último `./uninstall.sh` y `./update.sh`. Anota cada paso que no se pudo seguir tal cual: es un error de la guía.
- **Cómo revertir:** cada cambio es un commit (desde `afde345` hasta el último de esta sección); `git revert <rango>` o `git revert <commit>`. Tu instalación actual no se tocó: sigue enlazada a `config/` y `bin/`, que no se movieron. Estado local: `~/.local/state/dragon-island/firstrun.sh` apunta a un archivo que ya no existe (inocuo: `firstrun.done` existe); lo arregla la migración 013.

## 8. Cómo depurar rápido

```sh
qs -p ~/.config/quickshell          # recarga en caliente
qs log -f                           # errores archivo:línea
qs ipc show                         # funciones IPC registradas (shell, debug)
qs ipc call debug toggle            # valores en vivo de los servicios
hyprctl configerrors; hyprpm list; hyprctl plugin list
```
