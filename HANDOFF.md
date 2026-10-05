# Dragon Island — Handoff & Estado del Proyecto (Fase Base)

> **Fecha:** 2026-10-05  
> **Estado:** Fase Base completada e integrada en rama `main`.  
> **Objetivo:** Proporcionar los cimientos funcionales del entorno de escritorio Hyprland + Quickshell sobre EndeavourOS / Arch Linux (coexistiendo limpiamente con KDE Plasma), con paleta Garuda Dragonized / Sweet.

---

## 1. Resumen Ejecutivo de la Fase Base

En esta fase se establecieron los tres pilares estructurales del proyecto sin implementar componentes visuales finales de la barra o Dynamic Island:
1. **Configuración de Hyprland 0.56.x en Lua:** Modularizada al 100% mediante `require()`, complementada por configuraciones nativas para el ecosistema (`hyprlock`, `hypridle`, `hyprpaper`), integración de terminal (`kitty`) y plugins oficiales (`hyprbars`, `hyprfocus`).
2. **Instalador TUI Interactivo con Gum:** Script idempotente (`install.sh`), catálogo de paquetes (`pacman.txt`, `aur.txt`), respaldo con manifiesto inverso y script de inicialización de primera sesión (`installer/firstrun.sh`).
3. **Servicios Reactivos de Quickshell 0.3.1:** 13 servicios de datos desacoplados de la UI, gestor de estado global e IPC (`ShellState.qml`), tokens de diseño unificados (`Theme.qml`) y panel de diagnóstico en texto plano (`DebugPanel.qml`).

El desarrollo se ejecutó en ramas independientes (`agent/hyprland`, `agent/installer`, `agent/quickshell`) y se integró mediante merge commits `--no-ff` en `main`.

---

## 2. Reporte de Agentes

### Agente 1 — Hyprland & Ecosistema

#### Qué hizo
- **Configuración Modular en Lua (`config/hypr/`):**
  - `hyprland.lua`: Punto de entrada principal con ajuste de `package.path` para resolución local de módulos.
  - `monitors.lua`: Configuración por defecto de monitores (`name = "", resolution = "preferred", position = "auto", scale = 1.0`).
  - `env.lua`: Variables de sesión Wayland (`XDG_CURRENT_DESKTOP=Hyprland`, `GBM_BACKEND`, `QT_QPA_PLATFORM=wayland;xcb`, `MOZ_ENABLE_WAYLAND=1`, `HYPRCURSOR_THEME`, cursor 24px).
  - `input.lua`: Configuración de teclado (`latam`/`es`), mouse/touchpad (natural scroll, tap to click) y sensibilidad.
  - `look.lua`: Decoración Dragonized (bordes 2px con gradiente `#ff5555` a `#bd93f9`, fondo `#151928`, gaps in=5, out=10, blur Gaussiano estándar compatible con 0.56.2 sin variantes experimentales de git).
  - `animations.lua`: Curvas bezier personalizadas (`fluid`, `dragSpring`, `snappy`) y animaciones fluidas para ventanas y workspaces.
  - `rules.lua`: Reglas de ventanas y workspaces (flotantes para diálogos, PiP, apps multimedia, y asignaciones de workspaces).
  - `binds.lua`: Mapeo completo de atajos con teclado y ratón; control de audio, brillo y multimedia; disparadores de Quickshell IPC.
  - `autostart.lua`: Ejecución de servicios esenciales (`quickshell`, `hyprpaper`, `hypridle`, `hyprpolkitagent`, `installer/firstrun.sh`).
  - `plugins.lua`: Configuración protegida de `hyprbars` (barra de título de 24px, botones de ventana, colores Dragonized) y `hyprfocus` (animación de foco `flash` o `shrink`).
- **Herramientas del Ecosistema:**
  - `config/hypr/hyprlock.conf`: Pantalla de bloqueo elegante con fondo Dragonized, campo de contraseña translúcido con gradiente Sweet y reloj Outfit.
  - `config/hypr/hypridle.conf`: Detección de inactividad a 2.5 min (atenuar pantalla vía `brightnessctl`), 5 min (bloqueo vía `hyprlock`), 5.5 min (apagar pantallas vía `hyprctl dispatch dpms off`) y 30 min (suspensión del sistema).
  - `config/hypr/hyprpaper.conf`: Precarga y asignación de fondos de pantalla.
  - `config/kitty/kitty.conf`: Terminal Kitty tematizado con la paleta Dragonized, opacidad 0.88, blur activado y fuente JetBrains Mono Nerd Font.
- **Documentación:**
  - `docs/KEYBINDS.md`: Guía de referencia rápida con todos los atajos de teclado y convenciones del sistema.

#### Qué verificó
- **Sintaxis de Lua 5.4 estricta:** Todos los 10 archivos `.lua` se ejecutaron y validaron sintácticamente utilizando el motor `lupa` Lua 5.4 en entorno aislado.
- **Resolución de módulos:** Se comprobó que `require("monitors")`, `require("env")`, etc. cargan ordenadamente sin dependencias circulares ni errores de tabla.
- **Mocking de la API `hl`:** Se simularon las tablas globales `hl.monitors`, `hl.env`, `hl.input`, `hl.general`, `hl.decoration`, `hl.animations`, `hl.rules`, `hl.binds`, `hl.exec`, `hl.plugin` y los dispatchers `hl.dsp.window.*` verificando que no se produzcan excepciones de tipo ni llamadas nulas.
- **Formato de colores RGBA:** Se verificó que los colores se especifican en formato `0xRRGGBBAA` y cadenas compatibles con Hyprland.

#### Qué NO verificó
- `[NO VERIFICADO]` Renderizado Wayland en vivo y compositing en GPU física (NVIDIA / AMD / Intel) bajo Hyprland 0.56.2.
- `[NO VERIFICADO]` Compilación y carga en caliente de bibliotecas dinámicas de plugins (`hyprbars.so`, `hyprfocus.so`) mediante `hyprpm`.
- `[NO VERIFICADO]` Transiciones y eventos DPMS / logind en vivo bajo `hypridle`.
- `[NO VERIFICADO]` Autenticación PAM real y renderizado gráfico de la pantalla de bloqueo en `hyprlock`.

#### Qué decisiones tomó
- **Resolución del atajo `SUPER + L` vs Vim Binds:** Se priorizó la seguridad y el estándar moderno reservando `SUPER + L` para `loginctl lock-session` (bloqueo inmediato). La navegación estilo Vim se asignó a `SUPER + ALT + H/J/K/L`, mientras que la navegación rápida habitual se mantiene en `SUPER + Flechas`.
- **Uso de `.conf` para herramientas auxiliares:** Aunque la directiva principal prohíbe `hyprlang` para el compositor, se usó sintaxis `.conf` en `hyprlock`, `hypridle` y `hyprpaper` porque las versiones estables de estas herramientas satélite carecen de parser Lua.
- **Guardas condicionales en `plugins.lua`:** Para evitar que Hyprland falle en el primer arranque antes de que `hyprpm` compile los plugins, se implementaron guardas `if hl.plugin and ...` que permiten un arranque limpio sin plugins cargados.
- **Aislamiento absoluto de KDE Plasma:** Ninguna variable de entorno se exporta en perfiles globales de shell (`/etc/environment`, `~/.profile`). Todas se declaran en `env.lua`, afectando únicamente a la sesión de Hyprland.

---

### Agente 2 — Instalador & Despliegue

#### Qué hizo
- **Script Interactivo TUI (`install.sh`):**
  - Interfaz interactiva construida con `gum` (charmbracelet) con estilos, paleta Sweet/Garuda y cabeceras ASCII.
  - Soporte de argumentos de línea de comandos: `--dry-run`, `--uninstall`, `--yes` / `-y`.
  - Chequeos de preflight exhaustivos:
    - Verificación de distribución Arch Linux o EndeavourOS (`/etc/os-release`).
    - Verificación de sesión no-root con privilegios `sudo`.
    - Detección de gestores AUR (`yay` o `paru`) con procedimiento asistido para clonar y compilar `yay-bin` si ninguno está presente.
    - Comprobación de espacio libre en disco (mínimo 5 GB en la partición raíz).
    - Detección de instalación previa de KDE Plasma para alertar y asegurar la coexistencia dual.
  - Selección modular de componentes con `gum choose`: Core (Hyprland + Quickshell), Herramientas (Kitty, Rofi, Grimblast), Plugins de Hyprland, y Dotfiles.
  - Sistema de respaldos idempotente con timestamp en `~/.config/dragon-island-backups/backup_YYYYMMDD_HHMMSS/` y generación de `manifest.txt`.
  - Mecanismo de desinstalación limpia (`--uninstall`) leyendo el manifiesto en orden inverso para restaurar los archivos originales sin dejar residuos.
- **Script de Inicialización de Primera Sesión (`installer/firstrun.sh`):**
  - Script autoejecutable desde `autostart.lua` que solo se activa en la primera sesión Wayland mediante el archivo marcador `~/.config/dragon-island/.firstrun_done`.
  - Ejecuta `hyprpm update`, añade el repositorio oficial de plugins (`hyprwm/hyprland-plugins`), habilita `hyprbars` y `hyprfocus`, y notifica al usuario mediante `notify-send`.
- **Catálogo de Dependencias (`packages/`):**
  - `packages/pacman.txt`: Paquetes oficiales validados en repositorios `extra` (`hyprland`, `quickshell`, `kitty`, `pipewire`, `wireplumber`, `brightnessctl`, `hyprpolkitagent`, `hyprlock`, `hypridle`, `hyprpaper`, `ttf-jetbrains-mono-nerd`, etc.).
  - `packages/aur.txt`: Paquetes exclusivos de AUR (`outfit-font`, `grimblast-git`).

#### Qué verificó
- **Análisis estático de Shell (`shellcheck`):** Se ejecutó `shellcheck -x -s bash` sobre `install.sh` e `installer/firstrun.sh`, superando la validación con 0 errores y 0 advertencias.
- **Validación de paquetes en repositorios:** Se verificó la disponibilidad de cada paquete en el índice de Arch Linux `extra` (ej. `hyprpolkitagent` ya está en repositorio oficial y no requiere AUR).
- **Fin de línea LF:** Se forzó el uso de finales de línea LF en todos los scripts mediante configuración estricta en `.gitattributes`.

#### Qué NO verificó
- `[NO VERIFICADO]` Ejecución real de `pacman -Syu` o comandos `yay` descargando e instalando paquetes desde los servidores de Arch en vivo.
- `[NO VERIFICADO]` Renderizado e interacción del usuario en un terminal TTY / PTY real bajo `gum`.
- `[NO VERIFICADO]` Enlace simbólico o copia real en el sistema de archivos Linux de un usuario.
- `[NO VERIFICADO]` Flujo completo de compilación de plugins de C++ ejecutado por `hyprpm` en una máquina real.

#### Qué decisiones tomó
- **Manifiesto de respaldo inverso:** El instalador registra cada enlace simbólico o copia en `manifest.txt` en orden secuencial y `--uninstall` lo procesa en reversa (`tac`), asegurando que restauraciones anidadas no colisionen.
- **Marcador de primera ejecución (`.firstrun_done`):** Se evitó recargar `hyprpm update` en cada inicio del sistema encapsulando la inicialización en un script de primer arranque con flag persistente.
- **Preservación incondicional de KDE Plasma:** El instalador jamás modifica configuraciones de SDDM ni añade variables a `/etc/profile.d/`, garantizando que la sesión de Plasma no se vea afectada.

---

### Agente 3 — Servicios Quickshell & Diagnóstico

#### Qué hizo
- **Tokens de Diseño (`config/quickshell/Theme.qml`):**
  - Singleton QML con la paleta de colores Sweet Dragonized (`bgBase`, `bgSurface`, `bgElevated`, `primary`, `secondary`, `accentCyan`, `accentPink`, `accentYellow`, etc.).
  - Gradientes predefinidos (Dragonized gradient de morado a cian/rosa).
  - Configuración tipográfica (Outfit como fuente de interfaz y JetBrains Mono Nerd Font para datos monoespaciados).
  - Radios de curvatura (`radiusSm`, `radiusMd`, `radiusLg`, `radiusPill`), dimensiones de componentes y curvas de animación fluidas.
- **Gestión de Estado e IPC (`config/quickshell/ShellState.qml`):**
  - Singleton reactivo con registro de panel activo (`currentPanel`), visibilidad de barra (`barVisible`) e indicador de Dynamic Island (`islandExpanded`).
  - `IpcHandler` con target `"shell"` que expone métodos fuertemente tipados (`toggle(name: string): void`, `open(name: string): void`, `close(): void`, `current(): string`) invocables mediante `qs ipc call shell toggle <panel>`.
- **Estructura Modular (`qmldir`):**
  - `config/quickshell/qmldir` y `config/quickshell/services/qmldir` configurados para permitir importaciones directas limpias.
- **13 Servicios de Datos (`config/quickshell/services/`):**
  1. `Hypr.qml`: Integración con `Quickshell.Hyprland` (workspaces activos, ventanas enfocadas, monitores).
  2. `Media.qml`: Servicio MPRIS vía `Quickshell.Services.Mpris` (título, artista, estado de reproducción, progreso, carátula).
  3. `Audio.qml`: Control de audio PipeWire con `PwObjectTracker` (volumen maestro, estado de silencio, lista de salidas y cambio de sink).
  4. `Network.qml`: Estado de conectividad y WiFi vía `Quickshell.Networking`.
  5. `Bluetooth.qml`: Dispositivos conectados y estado del adaptador vía `Quickshell.Bluetooth`.
  6. `Power.qml`: Estado de carga y batería vía `Quickshell.Services.UPower` (porcentaje normalizado) y perfiles energéticos `power-profiles-daemon`.
  7. `Brightness.qml`: Consulta y ajuste de brillo de pantalla utilizando `brightnessctl` encapsulado en un `Process`.
  8. `SysStats.qml`: Monitoreo en tiempo real de CPU, memoria RAM, temperatura del sistema y almacenamiento en disco con temporizador configurable.
  9. `Notifs.qml`: Servidor de notificaciones basado en `Quickshell.Services.Notifications` con retención explícita (`n.tracked = true`).
  10. `Osd.qml`: Estado transitorio para notificaciones en pantalla de volumen, brillo y caps lock con auto-cierre tras 1.8 segundos.
  11. `Toggles.qml`: Estados lógicos de interruptores rápidos (WiFi, Bluetooth, No Molestar, Micrófono Mute, Luz Nocturna con `hyprsunset`).
  12. `Apps.qml`: Indexación de aplicaciones `.desktop` para el lanzador.
  13. `Clock.qml`: Fecha, hora actual y formateador reactivo.
- **Panel de Diagnóstico (`config/quickshell/debug/DebugPanel.qml`):**
  - Panel visual de desarrollo que muestra en texto plano valores en vivo de los 13 servicios (sin gráficos ni dependencias complejas de UI).
- **Ventana de Prueba (`config/quickshell/shell.qml`):**
  - Instancia de `FloatingWindow` que aloja el `DebugPanel.qml` para verificación directa en entorno de pruebas.

#### Qué verificó
- **Análisis de sintaxis y balance de bloques AST:** Se implementó un validador en Python que analizó los 17 archivos `.qml`, confirmando balance perfecto de llaves, corchetes, paréntesis y ausencia de errores de sintaxis.
- **Contratos de API Quickshell 0.3.1:**
  - Uso obligatorio de `PwObjectTracker { objects: [...] }` para evitar punteros inválidos al leer nodos de PipeWire.
  - Normalización de valores en `UPower` (porcentaje multiplicado por 100).
  - Retención de notificaciones mediante `n.tracked = true` en el manejador `onNotification`.
  - Tipado explícito en signaturas de funciones de `IpcHandler` en `ShellState.qml`.
- **Cero componentes visuales de producción:** Se garantizó que no se incluyeran barras, islas o popovers prematuros.

#### Qué NO verificó
- `[NO VERIFICADO]` Conexión y lectura del socket IPC de Hyprland (`$XDG_RUNTIME_DIR/hypr/.../.socket.sock`).
- `[NO VERIFICADO]` Respuestas en vivo de los daemons D-Bus de PipeWire, BlueZ, NetworkManager y UPower a través de las extensiones C++ de Quickshell.
- `[NO VERIFICADO]` Lanzamiento y salida del subproceso `brightnessctl` en hardware real.
- `[NO VERIFICADO]` Comportamiento del renderizado QtQuick / Wayland en un monitor físico.

#### Qué decisiones tomó
- **Encapsulación estricta en servicios:** La UI nunca ejecutará comandos de consola ni interactuará directamente con D-Bus. Toda llamada se canaliza a través de las propiedades reactivas y métodos de los servicios.
- **Procesos externos solo cuando no hay API nativa:** Se empleó `Process` de Quickshell únicamente para brillo (`brightnessctl`), temperatura/disco y luz nocturna (`hyprsunset`), priorizando siempre los módulos nativos de Quickshell (`Mpris`, `Pipewire`, `UPower`, `Networking`, `Bluetooth`).
- **Prevención de recolección de basura en notificaciones:** Se añadió `n.tracked = true` explícitamente para cumplir con el ciclo de vida de objetos en Quickshell 0.3.1.

---

## 3. Integración en Git

Todas las tareas de la Fase Base se desarrollaron en ramas dedicadas y se fusionaron a `main` sin conflictos de integración:

| Rama | Commit | Descripción del Aporte |
|---|---|---|
| `agent/hyprland` | `75ef967` | Módulos Lua de Hyprland, configs de hyprlock/idle/paper, kitty y documentación de atajos. |
| `agent/installer` | `10a0b15` | Instalador Gum TUI, listas de paquetes pacman/AUR y script de primer inicio. |
| `agent/quickshell` | `bbddf43` | Singletons Theme/ShellState, 13 servicios de datos y DebugPanel. |
| **`main`** | `da82995` | Merge de `agent/hyprland` |
| **`main`** | `26c4e87` | Merge de `agent/installer` |
| **`main`** | `27acaec` | Merge de `agent/quickshell` |

---

## 4. Lista de Pendientes para Fase 2 (Roadmap Visual & UI)

Habiendo validado la capa funcional y de datos, la **Fase 2** abordará la construcción visual completa según la especificación de diseño (`references/design.md`):

1. **Componentes UI Reutilizables (`config/quickshell/components/`):**
   - [ ] `Capsule.qml`: Contenedor base con fondo translúcido (`bgSurface`), borde sutil (`borderDim`), sombra y radio ajustable.
   - [ ] `Card.qml`: Tarjeta para paneles y dashboard con soporte de bordes activos.
   - [ ] `IconButton.qml`: Botón con micro-animaciones en `hovered` y `pressed`, tooltip y soporte para iconos Nerd Font.
   - [ ] `Slider.qml`: Deslizador fluido interactivo con gradiente Dragonized para volumen y brillo.
   - [ ] `Toggle.qml`: Interruptor reactivo con transiciones animadas para estados on/off.
   - [ ] `ProgressBar.qml`: Barra de progreso continua para consumo de CPU/RAM y estado de reproducción MPRIS.

2. **Barra Flotante Superior (`config/quickshell/modules/bar/`):**
   - [ ] `Bar.qml`: Contenedor `PanelWindow` anclado al borde superior con márgenes laterales y zona exclusiva.
   - [ ] `LeftIsland.qml`: Workspaces dinámicos de Hyprland con píldora indicadora activa animada y título de la ventana enfocada.
   - [ ] `RightIsland.qml`: SysTray embebido, indicadores de red/bluetooth/audio/batería, reloj con fecha y botón de invocación del dashboard.

3. **Dynamic Island (`config/quickshell/modules/island/`):**
   - [ ] `Island.qml`: Contenedor animado central con apertura estilo "drop-in" desde el margen superior.
   - [ ] Estados de visualización:
     - **Compacto:** Estado en reposo o reloj central.
     - **OSD:** Despliegue temporal de 1.8 segundos al modificar volumen o brillo.
     - **Media:** Título en marquesina, controles de reproducción y miniatura de álbum cuando la música está activa.
     - **Notificación:** Expansión suave para mostrar alertas entrantes con acciones interactivas.

4. **Dashboard Expandido (`config/quickshell/modules/dashboard/`):**
   - [ ] `Dashboard.qml`: Ventana emergente con animación de despliegue suave ("pour" effect).
   - [ ] Grilla 2x3 de interruptores rápidos (WiFi, Bluetooth, No Molestar, Silencio Micrófono, Luz Nocturna, Ahorro de Energía).
   - [ ] Deslizadores táctiles maestros para volumen y brillo.
   - [ ] Selector interactivo de perfiles de energía (`performance`, `balanced`, `power-saver`).
   - [ ] Widget de música integrado con barra de búsqueda y carátula.

5. **Popovers y Ventanas Auxiliares (`config/quickshell/modules/popovers/`):**
   - [ ] Popover de Calendario mensual con eventos.
   - [ ] Popover de Redes Wi-Fi con escaneo y conexión asistida.
   - [ ] Popover de Dispositivos Bluetooth con estado de emparejamiento.
   - [ ] Popover de Dispositivos de Audio con selector de sink activo y volumen por aplicación.
   - [ ] Popover de Centro de Notificaciones con histórico y botón de limpieza.

6. **Pruebas en Hardware Real / Máquina Virtual:**
   - [ ] Probar la instalación completa en una máquina virtual EndeavourOS con KDE Plasma instalada.
   - [ ] Verificar que el inicio de sesión secundario en SDDM funciona sin interferir con la sesión estándar de KDE Plasma.
   - [ ] Validar la compilación y activación de plugins con `hyprpm` tras el primer login.
