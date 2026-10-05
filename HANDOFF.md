# dragon-island — HANDOFF

> **Fecha:** 2026-10-05 · **Rama:** `main` · **Estado:** interfaz completa según la spec, **pendiente de prueba en EndeavourOS**.
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
shell.qml ── Variants(screens) → modules/bar/Bar.qml            (PanelWindow, capa Top, "dragon-bar")
          └─ Variants(screens) → modules/island/IslandWindow.qml (PanelWindow, capa Overlay, "dragon-island")
                                   ├─ Island.qml  (forma + PillContent + Dashboard)
                                   ├─ popovers/PopoverHost.qml  (7 popovers)
                                   ├─ launcher/Launcher.qml · power/PowerMenu.qml
                                   └─ notifications/NotificationPopups.qml
Theme.qml · Icons.qml · ShellState.qml (raíz)      services/*.qml (datos)      components/*.qml (piezas)
```

- **Un overlay por monitor (patrón 4).**
  - Cerrado: la máscara es la forma de la isla más los popups, y el resto deja pasar el clic.
  - Con un panel abierto: máscara `null`, un atrapa‑clics (con scrim si es modal) cierra el panel y el foco de teclado es `Exclusive` para que Esc funcione.
- **Popovers:** se dibujan dentro de ese overlay (patrón 5, opción A), bajo la cápsula que los abrió. `Bar.openFrom()` → `ShellState.toggleAt(name, monitor, anchorRight)`.
- **Un solo panel abierto:** `ShellState.openPanel` + `panelScreen`. El IPC (`qs ipc call shell …`) abre en el monitor enfocado.
- **Isla cerrada:** el estado lo calcula `services/IslandState.qml` (prioridad OSD > notificación > escritorio > música > reloj, con las duraciones de la spec).
- **Coreografía de la isla** (`Island.qml`):
  - Usa `expanded`, `contentShown` y `opening`.
  - `opening` se fija antes de cambiar la geometría, para que los Behaviors usen la curva correcta: OutBack 420 / OutCubic 480 al abrir y OutCubic 300 al cerrar.
  - La caída inicial anima `dropOffset` con los Behaviors desactivados.
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

## 6. Decisiones

- `SUPER + L` = bloquear; Vim = `SUPER + ALT + HJKL` (conflicto dentro de la propia spec).
- Tema Qt: plataforma `kde` en Hyprland, porque Plasma ya está instalado.
- `IslandState` vive en `services/` para evitar un ciclo de imports entre la raíz y `services`.
- Las notificaciones aparecen a la vez en la isla (compacta, como pide la spec) y como popups con cuerpo y acciones (la petición de "centro + popups").
- Calendario: aún **no hay fuente de eventos** (`Clock.hasEventSource = false`), así que no hay anillos cian ni agenda. Hay un `TODO(calendar)` en `Clock.qml`.
- Grabación: `wf-recorder` sobre una zona o salida elegida con `slurp -o`, guardada en la carpeta XDG de vídeos.
- Historial del portapapeles: sigue con `rofi -dmenu`.
- Blur: solo por reglas de capa (no `BackgroundEffect`), siguiendo la skill.

## 7. Siguientes pasos

1. Recorrer [docs/TESTING.md](docs/TESTING.md) en EndeavourOS y corregir lo que falle (`qs log` da el archivo y la línea).
2. Hacer las capturas y guardarlas en `docs/screenshots/` (el README ya tiene los huecos).
3. Opcional:
   - fuente de calendario (khal o un `.ics` vía `FileView`);
   - portapapeles dentro de Quickshell;
   - `Theme.motionScale` ligado a una preferencia de movimiento reducido;
   - bandeja del sistema (`SystemTray`), que la spec no pide.

## 8. Cómo depurar rápido

```sh
qs -p ~/.config/quickshell          # recarga en caliente
qs log -f                           # errores archivo:línea
qs ipc show                         # funciones IPC registradas (shell, debug)
qs ipc call debug toggle            # valores en vivo de los servicios
hyprctl configerrors; hyprpm list; hyprctl plugin list
```
