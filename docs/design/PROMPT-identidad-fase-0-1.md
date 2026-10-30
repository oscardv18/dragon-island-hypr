# Nueva identidad de dragon-island — Fase 0 (cimientos) + Fase 1 (barra y Ajustes)

Vas a implementar la nueva identidad visual del escritorio, aprobada en unas maquetas. Las maquetas son la referencia de diseño: lo que dicen manda sobre el estilo actual del repo. Las reglas técnicas del repo (arquitectura, Theme, migraciones, HANDOFF) siguen mandando sobre cómo implementarlo.

## Antes de tocar nada

1. Lee la skill `.agents/skills/dragon-island/SKILL.md` y carga `quickshell`, `hyprland` y `hyprland-plugins`.
2. Lee `docs/HANDOFF.md` entero, en especial §7c, §7e, §7g, §7m, §7n, §7t, §7x y §7za. Ahí están las lecciones que no hay que repetir:
   - una región de blur por ventana;
   - máscara por alfa;
   - ventanas de tamaño constante;
   - no ensanchar la isla derecha con el hover;
   - zona sensible dentro de la misma ventana.
3. Mira las imágenes de referencia en `docs/design/`:
   - `01-escritorio.png`
   - `05-barras.png`
   - `08-ajustes.png`
   - `15-movimiento.png`
   - `18-nucleo.png`
   - `19-islas.png`
   - `componente-lados.png`
   - `componente-esfera.png`
4. Crea la rama `feat/nueva-identidad`. Haz un commit por cada punto numerado de abajo.
5. Si algo de este documento choca con una lección del HANDOFF o con algo que no exista en Quickshell 0.3.1 / Hyprland 0.56.2, **para y pregúntame** antes de improvisar.

## Alcance

Solo Fase 0 y Fase 1.

- **Fuera de alcance, para fases posteriores:** el dock, el launcher (salvo que herede el núcleo), el bloqueo (ídem), los fondos orbitales, Alt+Tab y el módulo ágil.
- **No quites nada que hoy funcione:** cápsulas contextuales, vista previa de escritorio, popovers, acciones de ventana en la isla izquierda, bandeja en la pestaña Apps, IPC existentes.

---

## FASE 0 · Cimientos

### 0.1 Paleta y tokens en `Theme.qml`

Actualiza los valores sin renombrar los tokens que ya existen, para no romper componentes. Añade los nuevos.

| Token | Valor nuevo | Uso |
|---|---|---|
| `bg` | `#07060D` | fondo más profundo |
| `text` | `#EDEBF5` | texto principal |
| `textSoft` | `#C8C4D8` | texto de cuerpo, iconos neutros |
| `textDim` | `#A29EB6` | subtítulos |
| `muted` | `#7F7A93` | puntos vacíos, desactivado |
| `cyan` | `#67E8F9` | **lo vivo**: CPU, actividad, agentes trabajando, selección |
| `warn` | `#F5B04A` | espera / atención |
| `ok` | `#86EFAC` | éxito |
| **nuevo** `lavender` | `#C8B6E6` | acento suave: RAM, foco, estados activos |
| **nuevo** `lavenderInk` | `#EDE3FB` | texto sobre un estado activo |
| **nuevo** `lavenderDeep` | `#A78BCF` | barras de datos lavanda |
| **nuevo** `violetBase` | `#B26BFF` | base de los tintes (nunca como relleno sólido) |
| **nuevo** `islandInk` | `#05040A` | isla central / notch (casi negro) |

Tintes que dependen de la intensidad del acento (`Settings.accentIntensity`, 0–1, por defecto **0.3**):

- `accentTint = alpha(violetBase, 0.06 + accentIntensity * 0.40)` es el relleno de un estado activo.
- `accentEdge = alpha(violetBase, 0.15 + accentIntensity * 0.50)` es el borde interior de 1 px de un estado activo.

Regla de identidad: **el púrpura deja de ser relleno.**

- Los estados activos (escritorio activo, toggles encendidos, día seleccionado, botón primario de paneles) pasan de `BrandFill` a `accentTint` + borde `accentEdge` + texto `lavenderInk`.
- Crea `components/AccentFill.qml` para esto y úsalo en los 13 archivos que hoy usan `BrandFill`. Encuéntralos con `grep -rl BrandFill config/quickshell`.
- `BrandFill` se queda en el repo, pero deja de usarse en estados normales.
- Quita el brillo `RectangularShadow` magenta de la píldora activa.
- La cápsula del reloj deja de ser degradado de marca: pasa a fondo neutro (`white 6 %`) con un punto lavanda de 5 px.

Cristal de las islas, según las maquetas:
- fondo `rgba(13,11,22,0.66)` o el equivalente con `surface0`;
- borde blanco al 9 %;
- brillo interior superior blanco al 6 %.

Ajusta `glassBg` / `glassBorder` solo si las capturas con hyprglass lo confirman. El cristal real lo pone hyprglass: no rompas su máscara por alfa (`mask_threshold`).

### 0.2 Núcleo neural: estados nuevos, HUD y modo compacto

Edita **solo** `shared/neural-core/NeuralCore.qml` y luego ejecuta `scripts/sync-shared.sh` para copiarlo a Quickshell y al tema SDDM. Comprueba con `scripts/sync-shared.sh --check`.

- **Estados (`mood`):** se mantienen `calm · verifying · alert · ok` y se añaden tres más.
  - `listening`: respiración ±3,5 % del radio a ~0,5 Hz y brillo ×1,6.
  - `thinking`: giro ×5, umbral de conexión más alto (más líneas) y sinapsis (pulsos que viajan por las líneas) frecuentes.
  - `speaking`: ondas circulares que salen del centro cada ~0,42 s y se desvanecen en 1,4 s; los nodos vibran un 5 %.
  - Las transiciones entre estados son suaves (~0,3 s), sin saltos.
- **Paleta nueva** (todos los estados salvo `alert` y `ok`): nodos rosa lavanda `#E896EC`, lavanda `#C8B6E6` y cian `#67E8F9`; líneas mezcla lavanda/cian según profundidad; resplandor central lavanda suave.
- **Nueva propiedad `hud: bool`** (por defecto `false`). Dibuja, todo girando lento:
  - un aro tenue a 1,56 r;
  - 90 marcas tipo dial a 1,45 r (cada 5ª más larga);
  - dos arcos lavanda a 1,64 r (0,9 rad y 0,35 rad) que giran en un sentido;
  - un arco cian a 1,72 r que gira al revés;
  - una órbita elíptica punteada (rx 1,38 r, ry 0,34 r, inclinada −0,18 rad) con un satélite cian.
- **Modo compacto** automático cuando el lado es < 64 px: ~60 puntos, sin halos, cap de 30 fps y `running` solo si es visible. Es para la barra.
- **Compatibilidad:** el launcher, el bloqueo y SDDM ya usan `mood` y `energy`. Deben seguir funcionando igual (solo cambia la paleta).

### 0.3 Curvas de movimiento

En `config/hypr/animations.lua` añade estas curvas:

```lua
hl.curve("emergente", { type = "bezier", points = { {0.2, 0.9},  {0.1, 1.08} } })
hl.curve("estandar",  { type = "bezier", points = { {0.3, 0},    {0, 1}      } })
hl.curve("salida",    { type = "bezier", points = { {0.4, 0},    {1, 1}      } })
hl.curve("orbita",    { type = "bezier", points = { {0.16, 1.2}, {0.3, 1}    } })
```

Úsalas así:
- `windowsIn` y `layersIn` → emergente;
- `windowsOut` y `layersOut` → salida;
- `workspaces*` y `fade` → estandar.

Conserva el spring `easy` de las ventanas si se ve mejor; compáralo.

En `Theme.qml` añade los equivalentes QML para `Easing.BezierSpline`:
- `curveEmergente: [0.2,0.9,0.1,1.08,1,1]` con `durEmerge: ms(340)`;
- `curveEstandar` con `durStd: ms(240)`;
- `curveSalida` con `durOut: ms(160)`;
- `curveOrbita` con `durOrbit: ms(620)`.

Todo pasa por `ms()` (`motionScale`). Los springs del notch se quedan.

### 0.4 Ajustes nuevos en `services/Settings.qml`

Claves de `settings.json`, con sus valores por defecto si faltan:

| Clave | Valores | Por defecto |
|---|---|---|
| `barStyle` | `"A"` notch fino · `"B"` isla dinámica · `"C"` barra unida · `"D"` mínima | `"B"` |
| `islandContent` | `"media"` · `"window"` · `"date"` | `"media"` |
| `barMetrics` | bool (mostrar CPU/RAM/red) | `true` |
| `barAutohide` | bool (atenuar la barra con ventanas maximizadas) | `false` |
| `accentIntensity` | 0–1 | `0.3` |
| `wallpaperPalette` | bool (paleta tomada del fondo; se usa en una fase posterior, crea solo la clave) | `true` |

Añade un setter por clave, documentado en el bloque de comentarios del archivo (regla 6 de la skill). IPC `settings`:
- `barStyle(s)`, `cycleBarStyle()`, `accent(x)`, `islandContent(s)`, `metrics(on)`, `autohide(on)`;
- `current()` ampliado.

---

## FASE 1 · Barra con 4 estilos, islas nuevas y panel de Ajustes

### 1.1 Los cuatro estilos de barra

Medidas en px para una pantalla de 1366×768 a escala 1. La **zona reservada** es el `exclusiveZone` de `dragon-bar-zone`.

| | Islas laterales | Isla central | Zona reservada |
|---|---|---|---|
| **A · Notch fino** | alto 26, `top` 5, radio 9, cristal | pegada al borde superior, alto 26, esquinas inferiores 13, `islandInk`; el Nook crece desde ella | 31 |
| **B · Isla dinámica** (por defecto) | alto 26, `top` 6, radio 13, cristal | **píldora flotante** separada del borde: alto 26, radio 13, `top` 6, `islandInk` con sombra suave; sus estados (OSD, escritorio, agente, media…) la deforman | 32 |
| **C · Barra unida** | sin cajas propias: el contenido va dentro de una franja de borde a borde de alto 24, cristal, con línea inferior blanca al 7 % | notch de **exactamente 24 de alto** (igual que la franja, como el de un MacBook), esquinas inferiores 9 y orejas cóncavas de radio 8 arriba | 24 |
| **D · Mínima** | izquierda: solo la constelación en una píldora de alto 18; derecha: solo el reloj orbital | micro-isla de 80×18 que solo aparece con actividad (ecualizador, grabación, agente) | 18 |

Para implementarlo:
- `Bar.qml` elige el estilo con `Settings.barStyle` (un `Loader` por variante o propiedades condicionales; elige lo que mantenga las **ventanas de tamaño constante**, §7r).
- **C** es una sola forma en una ventana, así que no viola §7e (el problema allí eran dos regiones disjuntas en una misma ventana).
- **D** con `barAutohide` o al acercar el cursor al borde superior: zona sensible de 3 px **dentro de la misma ventana** (§7x). Al pasar el cursor despliega temporalmente el estilo B **sin cambiar** la zona reservada.
- **`Notch.qml` / `NotchShape.qml`** ganan `attached: bool`. Con `true` tienen orejas cóncavas y van pegados al borde (A, C); con `false` son la píldora flotante (B, D). El Nook expandido sigue abriéndose desde la isla en los cuatro estilos: en B se transforma desde la píldora flotante (sin orejas), en A y C desde el borde.
- `BarMetrics` sigue informando dónde acaban las islas en todos los estilos.
- **Cambiar de estilo en vivo** (IPC o Ajustes) debe funcionar sin reiniciar Quickshell. Comprueba con `hyprctl layers` que la zona reservada cambia y que las ventanas en mosaico se reacomodan.
- `barAutohide = true` en A/B/C: con una ventana maximizada en el escritorio enfocado, la barra baja a opacidad 0,35 y recupera la total al pasar el cursor.

### 1.2 Isla izquierda: núcleo, constelación y contexto vivo

De izquierda a derecha. Referencia: `19-islas.png` y `componente-lados.png`.

**1. Botón del núcleo** (sustituye al botón de degradado del launcher)
- Círculo de 22–24 px con fondo blanco al 5 % y un `NeuralCore` compacto dentro (`mood: "calm"`; `"listening"` al pasar el cursor).
- Clic: launcher. Sigue llamando a lo mismo que hoy.

**2. Constelación de escritorios** (sustituye a las `WorkspacePill`)

Geometría:
- 5 nodos separados 20 px (14 px en D), unidos por una línea de 1 px con degradado lavanda (40 % → 12 % de opacidad).
- Nodo vacío: aro de 5 px, 1 px, color `muted`.
- Nodo ocupado: punto de 5 px en `textSoft`, y una luna cian de 3 px arriba a la derecha si el escritorio tiene más de una ventana.
- Escritorio activo: un **planeta** de 18 px (12 en D), círculo con degradado de 150° de `alpha(violetBase,.34)` a `alpha(cyan,.2)`, borde interior de 1 px `alpha(lavender,.6)`, halo suave de 10 px y el icono de la app principal de ese escritorio en blanco (9–11 px).

Interacción:
- Al cambiar de escritorio, el planeta **viaja** al nuevo nodo con `curveOrbita` / `durOrbit` (≈520 ms).
- Al pasar el cursor por un nodo: el punto se vuelve blanco con un fondo circular blanco al 8 %, y tras 350 ms aparece la vista previa que ya existe (`PreviewWindow` / `WorkspacePreview`), alineada bajo ese nodo.
- Clic: ir al escritorio. Rueda: anterior / siguiente.
- Urgente: el nodo late en `warn`.

**3. Contexto vivo** (sustituye al título técnico de la ventana)
- Icono de la app en su color, **nombre amigable** (`DesktopEntries`, nunca la clase tipo `org.telegram.desktop`) y una ficha a la derecha.
- **Nuevo servicio `services/WindowContext.qml`**, solo datos. Para terminales y editores calcula el directorio de trabajo del proceso hijo más profundo de la ventana enfocada (por `/proc`) y la rama de git (`git -C <cwd> rev-parse --abbrev-ref HEAD`), con caché de ~5 s. Para Ghostty dentro de herdr puede usar el `cwd` que ya da `Herdr.qml`. Expone `title`, `chip` y `chipKind` (`"branch" | "unread" | ""`).
- Telegram (y apps con notificaciones): ficha con «N sin leer» a partir de `Notifs`.
- Las acciones de ventana que hoy salen al pasar el cursor (cerrar, flotar, fijar, mover) **se conservan** con el nuevo estilo.

### 1.3 Isla derecha: medidores en anillo y reloj orbital

Orden:

> [cápsulas contextuales existentes] · anillo CPU · anillo RAM · línea de red · │ · teclado · mosaico · Wi‑Fi · BT · volumen · batería · reloj orbital

- **Anillos** de 14–16 px (`conic-gradient` → `Shape` con `PathAngleArc`): CPU en `cyan`, RAM en `lavender`, con el fondo del anillo blanco al 13 %. Se ocultan con `barMetrics = false`. Clic: el popover de Rendimiento que ya existe.
- **Línea de red:** sparkline de 30×12 en `cyan` con las últimas 12 muestras de bajada. Si `SysStats` no guarda historial de red, añádelo ahí; solo datos.
- **Al pasar el cursor por los medidores:** el detalle («CPU 14 % · 55 °», «RAM 13.1 / 16 G», «↓ 1.2 MB/s · ↑ 84 KB/s») sale como **tooltip por debajo**. La isla no se ensancha (§7t).
- **Volumen:** icono + barra de 30×4. La rueda sube y baja de 5 en 5 y el clic silencia; conserva lo que ya hace hoy.
- **Reloj orbital:**
  - un aro de 14 px (1 px, lavanda al 40 %) con un punto cian de 4 px que da la vuelta una vez por minuto (posición según los segundos de `Clock`);
  - la hora en `fontMono` 12 semibold, sobre fondo blanco al 6 %;
  - los marcadores actuales (No molestar, sin leer, actualizaciones) como puntos diminutos;
  - clic y clic derecho igual que ahora; la fecha sale como tooltip al pasar el cursor.
- Las cápsulas de teclado, mosaico, red, BT y batería se quedan, reestilizadas al lenguaje nuevo: iconos `textSoft`, hover blanco al 8 % y activo con `accentTint`.

### 1.4 Panel de Ajustes

Panel nuevo `settings`, abierto por `ShellState` como los demás.
- Ventana propia (namespace `dragon-settings`) con cristal `dragon-panel` en `glass.lua` y regla de blur nativa de respaldo en `rules.lua`, como `dragon-wallpapers`.
- Referencia: `08-ajustes.png`.

Contenido:
- **Navegación lateral:** Apariencia, Barra superior, Launcher, Bloqueo e inicio, Fondo y colores, Atajos. En esta fase solo funcionan **Barra superior** y **Apariencia**; las demás se ocultan.
- **Barra superior:**
  - 4 tarjetas de estilo con una miniatura esquemática; la elegida lleva un aro cian de 1,5 px. Al elegir, la barra real cambia al instante.
  - Segmentado «Contenido de la isla»: Música / Ventana / Fecha.
  - Interruptores «Mostrar CPU y RAM» y «Ocultar automáticamente».
- **Apariencia:**
  - deslizador «Intensidad del acento» (sutil ↔ intenso) con una muestra en vivo;
  - interruptor «Colores desde el fondo de pantalla» (guarda `wallpaperPalette`; el efecto llega en otra fase).

Atajos:
- `SUPER + ALT + B` → `qs ipc call settings cycleBarStyle`, descripción «Shell · Cambiar el estilo de la barra».
- Un atajo libre para abrir Ajustes (propuesta: `SUPER + F2`, descripción «Shell · Ajustes»). Comprueba antes que esté libre.
- Añádelos también a `docs/KEYBINDS.md` y, si hay teclas dentro del panel, a `panelGroups` en `services/Keybinds.qml`.

### 1.5 Migración y documentación

- `migrations/020-nueva-identidad.sh`:
  - añade a `~/.config/dragon-island/settings.json` **solo las claves que falten** (nunca pisa las del usuario);
  - idempotente, respeta `DRY_RUN` / `ASSUME_YES`, sale con 10 si no hay nada que hacer;
  - sigue `migrations/README.md`.
- `docs/HANDOFF.md`: sección nueva «8a. Nueva identidad — Fase 0 + 1» con hecho / verificado / no verificado / decisiones, igual que las anteriores.

---

## Verificación (no marques nada como hecho sin esto)

1. `qs -p config/quickshell` arranca sin errores y `qs log` queda limpio. `hyprctl configerrors` vacío, `luac -p` en los Lua tocados, `shellcheck -x` en la migración y `scripts/sync-shared.sh --check` en verde.
2. Para **cada estilo A, B, C y D**:
   - captura de la barra con un fondo oscuro y otro casi blanco;
   - zona reservada correcta según `hyprctl layers` y la posición de una ventana en mosaico;
   - esquinas del cristal limpias, sin puntas;
   - el Nook se abre y se cierra bien desde la isla;
   - cambiar al siguiente estilo en vivo funciona.
3. **Constelación:** el planeta viaja al cambiar con `SUPER + 1–5`, la rueda cambia de escritorio y la vista previa aparece bajo el nodo correcto.
4. **Contexto vivo:** Ghostty en un repo muestra la rama; fuera de un repo, sin ficha; con Telegram en foco, «N sin leer».
5. **Ajustes:** cada control cambia la barra al instante y persiste tras `qs` reiniciado.
6. **Movimiento reducido** (`qs ipc call settings motion 0`): sin animaciones infinitas, incluidos los núcleos mini.
7. **Rendimiento:** `gpu_busy_percent` en reposo antes y después (con el núcleo mini en la barra). Si sube más de ~2 puntos, baja los fps / puntos del modo compacto y anótalo.
8. Bloqueo, launcher y tema SDDM siguen cargando con la paleta nueva del núcleo (`sddm/install-theme.sh --test`).
9. Capturas en `docs/screenshots/identidad/`.

Al terminar, dame un resumen corto: qué quedó, qué no pudiste verificar y qué decisiones tomaste. Si algo de la maqueta no era viable tal cual, dime qué hiciste en su lugar.
