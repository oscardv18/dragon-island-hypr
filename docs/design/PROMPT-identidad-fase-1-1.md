# Nueva identidad de dragon-island — Fase 1.1 (pulido de la barra) + Dock Constelación + iconos

Continúa en la rama `feat/nueva-identidad`, sobre lo que hiciste en las Fases 0 y 1. Las mismas reglas de antes:
- primero la skill `dragon-island` y `docs/HANDOFF.md` (incluida tu sección 8a);
- un commit por punto numerado;
- migración para todo lo que afecte a sistemas instalados;
- nada de colores fuera de `Theme`;
- si algo no es viable tal cual, **para y pregunta**.

Referencias visuales en `docs/design/`:
- `05-barras.png`
- `19-islas.png`
- `componente-lados.png`
- `27-dock-constelacion.png` (el usuario la añade ahora)

## 0. Antes de empezar

- Añade `docs/design/` a git en la rama. Son la referencia versionada de la identidad.
- Saca una captura de la barra en cada estilo (A, B, C y D) **antes** de tocar nada, para poder comparar al final.

---

## PARTE 1 · Pulido de la barra (Fase 1.1)

### 1.1 Barra más alta, con un ajuste de tamaño

El usuario ve la barra y la isla demasiado delgadas.

- Añade a `Settings` la clave **`barSize`**: `"compacta"` · `"normal"` · `"amplia"`, por defecto **`"normal"`**.
- Expón la altura desde `Theme`, con una función tipo `barHeightFor(style, size)` y tokens derivados. Que nada tenga números sueltos.
- Agrega «Tamaño de la barra» (segmentado de 3) en Ajustes › Barra superior.
- Añade el IPC `settings barSize <valor>`.

Alturas de la isla o franja y zona reservada:

| Estilo | compacta (la actual) | **normal (nueva, por defecto)** | amplia |
|---|---|---|---|
| A · Notch fino (islas a 5 px del borde) | 26 → zona 31 | **30 → zona 35** | 34 → zona 39 |
| B · Isla dinámica (a 6 px, flotante) | 26 → zona 32 | **30 → zona 36** | 34 → zona 40 |
| C · Barra unida (franja = notch) | 24 → zona 24 | **28 → zona 28** | 32 → zona 32 |
| D · Mínima | 18 → zona 18 | **22 → zona 22** | 26 → zona 26 |

El contenido escala **en proporción** con la altura. Valores para «normal»:

| Pieza | Valor en «normal» |
|---|---|
| Radio de las islas | A 11 · B 15 · C 0 |
| Botón del núcleo | 26 px (el `NeuralCore` de dentro, 24) |
| Planeta de la constelación | 20 px, icono 11 |
| Nodos de la constelación | 6 px, separación 22 |
| Anillos CPU / RAM | 18 px |
| Sparkline | 34 × 14 |
| Barra de volumen | 34 × 4 |
| Reloj orbital | aro de 16 px |
| Texto | `sizeBar` 13 |
| Isla central (B) | alto 30, radio 15 |

- El notch en A y C mide **exactamente** lo que la franja o las islas, igual que hoy.
- El Nook expandido no cambia de tamaño. Solo debe partir de la nueva altura colapsada.
- Revisa `BarMetrics`, `notchHeight`, el peek (`notchPeekDy`/`Dx`) y las posiciones de los popovers y de `PreviewWindow`, que dependen de la altura.

### 1.2 La isla central en el estilo B debe flotar

En las capturas del usuario, con el estilo B, la isla central se ve **pegada al borde superior y con orejas cóncavas**, como el estilo A.

En B tiene que ser una **píldora flotante**:
- 6 px de aire arriba, radio = alto / 2;
- sin orejas;
- `islandInk` con una sombra suave debajo.

Comprueba que `attached: false` llega de verdad a `Notch.qml` / `NotchShape.qml` en B y D, y que el Nook expandido en B se transforma desde la píldora, sin orejas. Pon en el HANDOFF capturas de B colapsada, en peek y expandida.

### 1.3 Anillos de CPU y RAM que se lean como medidores

Hoy parecen indicadores de carga (arcos finos con la pista casi invisible). Cámbialos a:

- **Grosor del aro:** 3 px en «normal» (2,5 en compacta, 3,5 en amplia), con extremos redondeados.
- **Pista:** blanco al 13–15 %, siempre visible: el aro completo.
- **Progreso:** desde arriba, en sentido horario. CPU en `cyan`, RAM en `lavender`.
- **Centro vacío.** Por encima del 85 % el progreso pasa a `warn`.
- **Animación:** el valor cambia con `curveEstandar` / `durStd`. No debe girar nunca.

### 1.4 Bordes de ventana con la paleta nueva

En `config/hypr/look.lua` (o donde se definan los colores de borde):

- **Borde activo:** degradado `lavender` (`#C8B6E6`) → `cyan` (`#67E8F9`) a 45°. Fuera el rosa, verde y magenta.
- **Borde inactivo:** casi invisible (`rgba(255,255,255,0.08)` o el `outline` de `Theme`).
- **hyprbars:** revisa los colores de la barra de título y de los botones en `plugins.lua`. Los botones van en `textSoft`; el de cerrar en `error` solo al pasar el cursor, si el plugin lo permite. Ningún magenta de la paleta vieja.
- **hyprfocus:** si usa colores, los mismos.

Valida con `hyprctl configerrors` y una captura con dos ventanas (activa e inactiva).

**Fuera de alcance:** los colores de herdr, Ghostty, Starship, kitty y fastfetch. Se tiñen en la fase de la paleta desde el fondo; no los toques ahora.

---

## PARTE 2 · Dock Constelación (sustituye el aspecto de `modules/dock/`)

El dock deja de ser una pestaña con iconos. Es una **constelación**:
- las apps son **nodos de cristal circulares** unidos por un **hilo de luz**;
- el **núcleo** va en el centro;
- las ventanas de cada app son **lunas** que la orbitan;
- los agentes de herdr se ven como **sinapsis** que viajan por el hilo.

Referencia: `27-dock-constelacion.png`.

**Conserva toda la lógica que ya funciona** en `services/Dock.qml` y la ventana:
- fijadas y abiertas, minimizar a `special:minimized`, menús;
- posición abajo / izquierda / derecha, «Siempre visible», ocultarse con ventanas en mosaico (`workspaceFree`);
- la rueda para desplazar si hay muchas apps;
- el IPC `dock`.

Cambia el aspecto y la interacción. Antes de empezar, relee §7q–§7z del HANDOFF: zona sensible en la misma ventana, `Region` con un ítem fijo, `index` vs `slotIdx`, `HoverHandler` en el padre.

### 2.1 Disposición

- **Orden:** el núcleo en el centro de la pantalla. Las apps **fijadas** crecen hacia la izquierda y las **abiertas sin fijar** hacia la derecha (el dock puede quedar asimétrico).
- **Separación** entre centros de nodo: 74 px. Hasta `dockCapacity` nodos; el resto, con la rueda.
- **Hilo:** curva suave que pasa por el centro de cada nodo (Catmull-Rom → `PathCubic`). Hace un arco leve: los extremos ~10 px más abajo que el centro, como una sonrisa invertida. Sobresale ~60 px más allá del primer y último nodo y se desvanece hacia ambos extremos.
  - Trazo de 1,6 px con degradado `lavender` → rosa lavanda (`#E8C8F5`) en el centro → `cyan`, y alfa 0 en las puntas.
  - Debajo, un trazo de 7 px al 18 % como resplandor.
- **Altura:** el centro de los nodos queda a ~46 px del borde de la pantalla. La ventana necesita sitio por encima para la etiqueta y el levantamiento.
- **Izquierda / derecha:** lo mismo con el hilo vertical (gira el marco como ya hace el dock actual).

### 2.2 Nodos

- **Normal:** círculo de cristal de 42 px.
  - Relleno: degradado radial desde arriba a la izquierda, tinte de la app al 30 % → 8 % → `rgba(13,11,22,0.75)`.
  - Borde interior blanco al 14 % y brillo superior blanco al 18 %.
  - Sombra suave debajo.
- **Tinte de la app:** con `ColorQuantizer` sobre su icono (un color, en caché). Si no está disponible o falla, usa `lavender`.
- **App enfocada = planeta:** 48 px, aro de 2 px `alpha(lavender,.7)` y halo de 26 px `alpha(lavender,.45)`.
- **Núcleo (centro):** 64 px, `NeuralCore` con `mood`:
  - `"thinking"` si `Herdr.counts.working > 0`;
  - `"listening"` al pasar el cursor;
  - si no, `"calm"`.
  - Clic abre el launcher y la rueda cambia de escritorio.
- **Minimizada:** opacidad 0,4 y saturación al 30 %.
- **Iconos:** al 44 % del tamaño del nodo, del tema de iconos (ver Parte 3).

### 2.3 Lunas (ventanas)

- Un aro de órbita de diámetro `nodo + 18`, blanco al 8 % (22 % con hover o foco).
- Hasta 3 lunas de 6 px repartidas, que giran:
  - una vuelta cada 18 s;
  - cada 6 s si en la app hay un agente trabajando.
- Colores:
  - normal: `text`;
  - la de la ventana enfocada: `lavender` con resplandor;
  - app con agente trabajando: `cyan`;
  - minimizada: `muted`.
- **Clic** en una app con varias ventanas: cicla entre ellas.
- **Mantener pulsado**: muestra las miniaturas encima (reutiliza `ScreencopyView` como en `PreviewWindow`).

### 2.4 Agentes (herdr)

- **Sinapsis:** mientras una app tenga un agente `working` (relaciona el panel de herdr con su ventana, normalmente Ghostty), dos partículas cian de 7 px con resplandor viajan **por el hilo** desde el núcleo hasta esa app. Duran 1,8 s cada una, desfasadas 0,9 s, con entrada y salida en fundido.
- **Esperando respuesta** (`blocked`): un halo `warn` de 52 px late alrededor de la app (1,4 s).

### 2.5 Interacción

- **Hover:** el nodo crece 6 px y el hilo se **tensa** hacia el cursor. El nodo sube 16 px y sus vecinos menos, con una gaussiana de σ ≈ 1,1 nodos. Todo con `curveEmergente` (~380 ms).
- **Etiqueta** sobre el nodo: píldora de cristal oscuro con el nombre (13 semibold) y una línea de estado en `textDim` («3 ventanas · agente trabajando», «4 sin leer», «minimizada»).
- **Avisos:** píldora `#8B6BB8`, que puedes añadir a `Theme` como `badge`, en la esquina superior derecha del nodo, con el número. Usa el conteo por app de `Notifs`.
- **Clic derecho:** los menús que ya existen, con el estilo nuevo.

### 2.6 Oculto

- Con ventanas en mosaico, los nodos bajan y se desvanecen.
- Queda **solo el hilo** a ~6 px del borde, con un punto de 2,5 px por app abierta (cian si tiene agente) y una respiración lenta (opacidad 0,45 ↔ 1, 2,6 s).
- La zona sensible de 3 px va **dentro de la misma ventana** (§7x), y el hover cubre la unión de la franja y los nodos.

### 2.7 Rendimiento

- El núcleo de 64 px solo corre con el dock visible.
- Las lunas y las sinapsis se detienen con el dock oculto y con `motionScale = 0`.
- Mide `gpu_busy_percent` con el dock visible y en reposo: no debería sumar más de ~2 puntos frente al dock actual. Si se pasa, baja la frecuencia del núcleo como hiciste en la barra.

---

## PARTE 3 · Tema de iconos

El usuario ya instaló a mano **MacTahoe** y **WhiteSur** (temas de iconos). Usaremos uno como principal y el otro como respaldo. No instales Tela ni Papirus.

1. **Encuentra los nombres exactos** de los temas instalados y sus variantes oscuras:
   - `ls /usr/share/icons ~/.local/share/icons ~/.icons`
   - mira el `Name=` / `Inherits=` de cada `index.theme`.
   - Variantes de color: si hay una violeta o púrpura, priorízala; si no, la oscura estándar.
2. **Elige el principal comparando los dos de verdad**, no por intuición:
   - captura el launcher y el dock con cada tema, sobre el fondo oscuro;
   - criterios: legibilidad dentro de los nodos circulares de cristal, coherencia con la paleta lavanda / cian y cobertura de las apps del usuario (cuenta cuántas apps de `DesktopEntries` quedan con icono genérico en cada uno).
   - **Mi preferencia de partida es MacTahoe como principal y WhiteSur como respaldo**, porque su estilo con relieve de cristal encaja con la identidad. Si la comparación dice lo contrario, cambia el orden y explícalo.
3. **Iconos cuadrados en nodos circulares.** Ambos temas usan iconos con forma de cuadrado redondeado (estilo macOS). Prueba dos variantes en el dock y en el launcher, y deja la que se vea mejor (con capturas en el HANDOFF):
   - **a)** el icono al ~56 % dentro del nodo circular de cristal (tal cual la maqueta);
   - **b)** sin el disco de cristal: el propio icono es el nodo (~44 px). Las lunas, el halo de foco y la sinapsis se mantienen alrededor, y la órbita queda como único elemento circular.
4. **Tema propio `Dragon-Core`** en el módulo `theme`:
   - un `index.theme` en `~/.local/share/icons/Dragon-Core/` con `Inherits=<principal>,<respaldo>,hicolor`, usando los nombres exactos que encontraste;
   - aquí irán después los iconos propios del shell;
   - el tema de carpetas (Sweet Folders) se queda solo si el principal no trae carpetas coherentes. Decide con una captura de Dolphin y de la Tienda.
5. **Cambia `//@ pragma IconTheme`** de `shell.qml` a `Dragon-Core`.
   - Revisa `scripts/icon-paths.sh` (§7o): el launcher resuelve los iconos a archivos y debe seguir el tema nuevo y toda su cadena de herencia.
   - Comprueba launcher, dock, constelación, contexto vivo, pestaña Apps y Tienda.
6. **Paquetes y reproducibilidad:** comprueba si existen en el AUR (`yay -Si whitesur-icon-theme`, y busca el nombre correcto de MacTahoe con `yay -Ss mactahoe`).
   - Si existen: añádelos a `packages/` (sección de tema).
   - Si alguno solo se instala desde su repo de git: no lo automatices. Documenta la instalación manual en `pre-instalation.md` / `docs/INSTALL.md` y haz que `doctor.sh` avise si falta.
7. **Migración 021:** crea el tema `Dragon-Core` (sin instalar nada sin confirmación). Idempotente, con `DRY_RUN`; si falta el tema principal, avisa y sale con 10.
8. Lista en el HANDOFF las apps que hayan quedado **sin icono** o con uno genérico en el tema elegido.

---

## Verificación

- `qs -p` sin errores, `qs log -f` limpio durante el uso, `hyprctl configerrors` vacío, `shellcheck`, `luac -p` y `sync-shared --check`.
- **Barra:** capturas de A, B, C y D en los tamaños compacta, normal y amplia (12), comparadas con las del paso 0. La zona reservada correcta en cada caso. La isla B flotante en colapsada, peek y expandida.
- **Anillos:** se leen como medidores al 5 %, 50 % y 90 % (este último en `warn`).
- **Bordes:** captura con una ventana activa y otra inactiva.
- **Dock:**
  - visible con 6–8 apps, hover con el hilo tensándose y la etiqueta;
  - lunas de una app con 3 ventanas; ciclar con clic;
  - agente trabajando con sinapsis (abre un agente en herdr) y agente esperando con halo ámbar;
  - minimizada, aviso con número, oculto con ventanas en mosaico, posiciones izquierda y derecha.
- **Iconos:**
  - capturas del launcher y del dock con MacTahoe y con WhiteSur (la comparación del punto 2);
  - las dos variantes de nodo (a / b) y la elegida.
- `gpu_busy_percent` antes y después.
- `docs/HANDOFF.md`: sección «8b. Fase 1.1 + Dock Constelación + iconos», con hecho / verificado / no verificado / decisiones.

Al terminar: un resumen corto, qué no pudiste verificar y en qué te apartaste del prompt y por qué.
