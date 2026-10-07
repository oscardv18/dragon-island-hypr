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

- **Cada componente en su capa (namespace propio)**, para poder dar reglas de blur / hyprglass distintas. Salvo el notch, todos llevan `BackgroundEffect.blurRegion` sobre sus tarjetas.
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

## 8. Cómo depurar rápido

```sh
qs -p ~/.config/quickshell          # recarga en caliente
qs log -f                           # errores archivo:línea
qs ipc show                         # funciones IPC registradas (shell, debug)
qs ipc call debug toggle            # valores en vivo de los servicios
hyprctl configerrors; hyprpm list; hyprctl plugin list
```
