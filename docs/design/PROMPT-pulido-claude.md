# dragon-island — Fase de pulido (Claude Code): cristal nuevo, islas más anchas, emergentes HUD, notificaciones, rendimiento y deudas de la identidad

Trabaja en una rama nueva `feat/pulido` creada desde `main`. Codex trabaja en paralelo en `feat/pulido-herramientas` (scripts, pruebas de tiempo, imágenes): **no toques** `update.sh`, `tests/engines/`, `scripts/optimize-images.sh` ni las imágenes de `docs/`. Codex no toca nada de `config/`, `sddm/` ni `shared/`.

Las mismas reglas de siempre:
- primero `AGENTS.md`, la skill `dragon-island` y `docs/HANDOFF.md`;
- un commit por punto numerado;
- nada de colores, tamaños ni duraciones fuera de `Theme`;
- la UI nunca ejecuta comandos: todo pasa por servicios;
- si algo no es viable tal cual en Quickshell 0.3.1 / Hyprland 0.56.2, **para y pregunta**.

**Migraciones:** tú usas `034` a `039`. Codex usa `040` en adelante.

**Contrato con Codex: `dragon-activity`** (registro de actividad para la línea de tiempo de la isla). Codex lo instala en `~/.local/bin/` (usa la ruta completa):
- `dragon-activity add --kind agent|command|focus --name "<texto>" --start <epoch> [--end <epoch>] [--status ok|fail|blocked]` imprime el `id`;
- `dragon-activity end <id> [--status ok|fail]` cierra una entrada abierta;
- `dragon-activity range --from <epoch> --to <epoch> --json` devuelve `{"items":[{"id","kind","name","start","end","status"}]}` (`end` es `null` si sigue abierta).

Mientras Codex no lo entregue, crea uno provisional fuera del repo que devuelva datos de prueba con ese esquema.
**`tests/run-all.sh`:** si añades pasos, ponlos **antes** del paso «pre-instalation.md ↔ código». Codex añade los suyos justo después del paso de motores. Así no chocan al fusionar.
**Notas:** en `docs/HANDOFF.md`, sección nueva `8h` (ver punto 10).

Referencias en `docs/design/`:
- `28-emergentes.png` (nueva: cristal, notificación y popover de Rendimiento; el tablero interactivo muestra las fases de cada animación);
- `29-paneles-wifi.png`, `29-paneles-sonido.png`, `29-paneles-bluetooth.png` y `29-paneles-fecha.png` (nuevas: las cuatro pestañas del tablero 29, paneles con gestión completa);
- `31-isla-mando.png` y `31-isla-mando-busqueda.png` (nuevas: la isla expandida que combina las tres propuestas del tablero 30);
- `04-paneles.png`, `09-isla.png`, `19-islas.png`, `27-dock-constelacion.png`, `15-movimiento.png`.

Si el código y una referencia chocan, manda la referencia.

**Fuera de alcance:** el módulo ágil (Fase 5) y las funciones extra (panel de desarrollo, modo juego, etc.).

---

## 1. Cristal: de «líquido» a «ahumado»

El usuario ya no quiere el cristal líquido de hyprglass como aspecto principal. Pasa a haber tres estilos, elegibles en Ajustes › Apariencia (`Settings.glassStyle`):

| Estilo | Qué es | Por defecto |
|---|---|---|
| `ahumado` | Desenfoque nativo de Hyprland, grano fino, relleno oscuro y un filo de luz arriba (degradado de acento a cian) | **Sí** |
| `clasico` | Desenfoque nativo y borde fino. Sin grano ni filo de luz | No |
| `liquido` | Lo actual de hyprglass. Solo se ofrece si el plugin está instalado | No |

1. **Ahumado, en Hyprland:** desenfoque nativo para las capas de Quickshell y las ventanas translúcidas (Ghostty incluida). Usa `blur.noise` de Hyprland para el grano (prueba 0,02 a 0,04) antes de dibujar una textura en QML; solo si el nativo no da el aspecto, añade un mosaico de ruido de 128 px en QML con opacidad ≤ 0,06. Ajusta `size`, `passes`, `vibrancy`, `contrast` y `brightness` en `look.lua` para que se lea como en `28-emergentes.png`.
2. **Ahumado, en Quickshell:** relleno `rgba(14,12,24,0.70)`, borde blanco 8 %, filo de luz de 1 px arriba (de `Theme.lavender` a `Theme.cyan`, con transparencia en los extremos) y sombra suave. Todo como tokens nuevos en `Theme` (`glassFill`, `glassBorder`, `glassLight`, `glassShadow`) que dependen de `glassStyle`.
3. **Clásico:** relleno `rgba(13,11,22,0.78)`, borde blanco 9 %, sin grano ni filo.
4. **Líquido:** los ajustes actuales de `glass.lua`, sin cambios, activos solo con `glassStyle = liquido`.
5. **Cambio en vivo:** el servicio de ajustes escribe `~/.config/dragon-island/glass-style` y aplica el cambio con `hyprctl eval` o una recarga controlada desde un servicio. `glass.lua` y `rules.lua` leen ese archivo al cargar. Sin dos desenfoques a la vez sobre la misma capa (regla del HANDOFF). **Si no hay una forma limpia de alternar hyprglass sin reiniciar Hyprland, para y pregunta.**
6. Migración `034-glass-style.sh`: añade `glassStyle: "ahumado"` a `settings.json` (el usuario lo pidió como nuevo aspecto también en su sistema instalado), crea el archivo de estilo y deja hyprglass instalado pero inactivo. Copia de seguridad y `DRY_RUN` como siempre.

## 2. Islas superiores más anchas

El contenido de la isla central y de las laterales se ve apretado. Hazlas **un poco** más anchas, sin ocupar mucha más pantalla. Las alturas no cambian.

1. Más aire dentro de las islas laterales: `barIslandPadH` de 6 a 10 y `barIslandGap` de 5 a 8.
2. Contenido algo más grande en las tres tallas: anillos +2 px, gráfica de CPU +8 px de ancho, control de volumen +10 px, planeta y nodos de la constelación +2 px, texto `sizeBar` +0,5.
3. Isla central: `notchRestWidth` de 190 a 220 y `notchMinWidth` de 120 a 140. Los estados de la isla que muestran texto (notificación, OSD, agentes) ganan unos 30 px de ancho máximo para que no corten tanto.
4. Las ventanas de la barra mantienen tamaño constante (regla del HANDOFF) y la isla derecha no se ensancha sola con el contenido.
5. Comprueba a 1366×768 en los cuatro estilos (A, B, C, D) y las tres tallas que nada se solapa y que la isla central nunca toca las laterales. **Deja en el HANDOFF una tabla de anchos antes y después.**
6. **Los anillos de CPU y RAM ya no deben parecer indicadores de carga:** arco fijo con pista de fondo, que empieza arriba y avanza en sentido horario según el valor, sin ningún giro. El valor numérico aparece al pasar el cursor (y siempre en la talla `amplia`). Sigue `19-islas.png`.
7. **Sin borde blanco en las islas.** Al usuario no le gusta el contorno blanco fino de las islas laterales (y de la central y la franja del estilo C). Quítalo: el borde de las islas de la barra pasa a ser transparente, y la forma se define por el contraste del relleno, una sombra suave y, en el cristal ahumado, solo el filo de luz superior. No cambies el borde de los paneles emergentes, que siguen el punto 3.

## 3. Emergentes con lenguaje HUD

Todos los popovers de la barra (`modules/popovers/`) pasan a un mismo sistema, según `28-emergentes.png`.

**Marco común (`PopoverFrame`):**
- material del punto 1;
- cabecera con rótulo en mayúsculas monoespaciado, línea que se desvanece y, si aplica, un indicador «● EN VIVO»;
- cuatro escuadras de esquina (12 px, trazo 1,5 px en cian, radio 6) que aparecen al final de la apertura;
- filas que entran en cascada.

**Apertura** (respeta las cuatro curvas de `Theme`):
1. El botón que lo abre en la isla se ilumina con un halo cian mientras el popover esté abierto.
2. **Haz:** una línea vertical de 1,5 px (cian con resplandor) baja desde el botón hasta el borde superior del popover (180 ms, `estandar`).
3. **Despliegue:** el popover se abre recortado desde el punto donde llega el haz, primero en ancho y luego hacia abajo (300 ms, `emergente`).
4. **Filas en cascada:** cada fila entra con opacidad y 8 px de desplazamiento, 40 ms después de la anterior. Indicadores, barras segmentadas y gráficas se llenan después.

**Cierre:** filas fuera (100 ms), el recorte se cierra hacia el haz (160 ms, `salida`) y el haz se recoge (120 ms). Apertura total ≤ 600 ms y cierre ≤ 400 ms.

**Con `Settings.reduceMotion`:** solo un fundido de 120 ms.

**Rendimiento** (el que hoy sigue con el diseño viejo), como en el tablero:
- indicador circular de 270° con marcas, el porcentaje grande en el centro y el rótulo «CPU»;
- RAM, GPU y temperatura como barras segmentadas de 18 segmentos (lavanda, cian y ámbar);
- gráfica de área de los últimos 60 s con degradado;
- núcleos como celdas de calor (6 por fila) con su número;
- procesos con barra fina, CPU y memoria;
- perfil de energía con una pastilla que se desliza entre opciones.

**El resto de popovers** adopta el mismo marco y vocabulario (niveles como barras segmentadas, valores en monoespaciado, rótulos en mayúsculas, filas del mismo alto, la misma pastilla deslizante para cualquier selector) y pasa a ser **un panel de gestión completa** de lo suyo, según las capturas `29-paneles-*.png`. Mantén lo que ya funciona (por ejemplo, clic derecho en volumen para el popover).

| Panel | Debe permitir |
|---|---|
| **Wi‑Fi** (`WifiPopover`) | Interruptor; red actual con banda, seguridad, velocidad de enlace, señal por segmentos, IP, puerta de enlace y DNS; tráfico en vivo de bajada y subida con gráfica pequeña (lee `/proc/net/dev` desde el servicio); compartir la red con un código QR (con `qrencode` si está instalado; si no, se oculta la opción); olvidar y desconectar; VPN con su estado, último servidor y conectar; redes cercanas con señal, banda y seguridad, pedir contraseña en línea al conectar; red oculta; punto de acceso (`nmcli device wifi hotspot`) |
| **Sonido** (`AudioPopover`) | Volumen general por segmentos (clic o arrastre para fijar) con silencio y refuerzo hasta 150 %; elegir salida (altavoces, USB, Bluetooth con batería si la da); elegir micrófono, con su volumen y un **medidor de nivel en vivo** (si Quickshell 0.3.1 no da el pico de un nodo de PipeWire, propón cómo y **pregunta**); supresión de ruido si hay un filtro disponible (si no, se oculta); volumen y silencio por aplicación; un ecualizador sencillo solo si hay una forma limpia (si no, déjalo fuera y dilo) |
| **Bluetooth** (`BluetoothPopover`) | Interruptor y visibilidad; conectados con tipo, batería por segmentos, perfil de audio y «usar como salida»; desconectar y olvidar; cercanos mientras busca (con un indicador de radar), emparejar y conectar; aviso en la isla al conectar un dispositivo o cuando su batería baja del 15 % |
| **Fecha y hora** (`CalendarPopover`) | Hora con segundos y fecha completa; relojes del mundo configurables en Ajustes; mes con puntos en los días con eventos (khal) y navegación de meses; agenda de hoy; crear un evento (con `khal new`, por un servicio); temporizador, cronómetro y alarmas (servicio nuevo `Timers.qml`, con aviso en la isla al vencer); atajo al modo enfoque |
| **Batería** (`BatteryPopover`) | Carga por segmentos, tiempo restante, consumo en vatios, salud, perfil de energía con la pastilla deslizante, y brillo de pantalla (incluidos monitores DDC) |
| **Privacidad** y **Agentes** | Mismo marco; sin funciones nuevas |

Si una función necesita una herramienta que no está instalada, el panel la oculta en lugar de fallar, y la migración del punto 8 la añade a la lista de paquetes opcionales.

## 4. Notificaciones que salen de la isla

Según `28-emergentes.png`.

**Llegada:**
1. La isla se ensancha unos 25 px por lado, gana un halo cian y muestra el remitente.
2. **Gota:** un punto cian de 12 px con resplandor viaja desde la isla hasta el borde superior de la tarjeta (440 ms, `orbita`).
3. **Trazo:** el contorno de la tarjeta se dibuja en cian desde el centro superior hacia los lados y hacia abajo (320 ms).
4. **Relleno:** el cristal se llena de arriba abajo (300 ms, `emergente`) y el contorno cian se apaga.
5. **Contenido:** filas en cascada (45 ms) y una banda de luz que barre la tarjeta una sola vez.
6. **Tiempo restante:** una línea de 2 px abajo (de cian a lavanda) que se acorta. Con el cursor encima se pausa el tiempo y la línea.

**Salida** (al vencer, al cerrarla o al deslizarla):
1. El contenido se apaga (120 ms).
2. La tarjeta se colapsa en una línea horizontal (200 ms, `salida`).
3. La línea se reduce a la gota, que vuelve a la isla (320 ms).
4. La isla hace un pulso breve con «Guardada en el centro».

**Varias a la vez:** máximo 3 visibles. Las nuevas empujan a las anteriores hacia abajo (240 ms, `estandar`). El resto se agrupa en un «+N».

**Urgencia crítica:** el contorno se queda en ámbar o rojo y no se cierra sola.

**No molestar:** sin gota ni tarjeta. Solo el contador en la isla.

**Ventanas:** la gota cruza de la isla a la columna de notificaciones. Dibújala dentro de la ventana de notificaciones, ampliando su área visible pero con la máscara de entrada solo en las tarjetas. **Si cruzar ventanas no es viable sin romper la regla de una región de desenfoque por ventana, para y pregunta.** La alternativa aceptable es que la gota nazca en el borde de la ventana de notificaciones.

El centro de notificaciones (en la isla expandida) adopta las mismas tarjetas y el mismo material.

## 4b. Isla de mando (la isla expandida)

El usuario eligió **combinar las tres propuestas** del tablero 30. El resultado está en `31-isla-mando.png` y `31-isla-mando-busqueda.png`. Sustituye a la pestaña «Nook» actual de `NotchExpanded` (la media, la tira de calendario, los interruptores y las barras de sistema).

**Tamaño:** 740 × 262 en la talla `normal` (700 en `compacta`, 780 en `amplia`). Comprueba que cabe a 1366 px sin tocar las islas laterales. Relleno opaco como el notch, **sin borde blanco**, con el filo de luz superior.

**Pestañas:** `Mando · Apps · IA`, compactas a la derecha de la cabecera. Apps e IA conservan su contenido actual, con el nuevo vocabulario visual.

1. **Línea de mando (cabecera, de la propuesta C).** Campo de 34 px con los chips de modo `=` `>` `?` `@` `IA`. Usa **el mismo** `services/Search.qml` que el launcher, sin duplicar lógica. Al escribir, el cuerpo de la isla se sustituye por hasta 4 resultados (↑↓ y Enter; Esc vuelve). El modo **IA** abre la terminal desplegable (`special:dropdown`) con `claude "<consulta>"` ya escrito, en lugar de mostrar la respuesta dentro de la isla. Atajo para enfocar la línea con la isla cerrada: `SUPER + /` (comprueba que no choca).
2. **Pila de prioridad (izquierda, de la propuesta B).** Una tarjeta grande y, debajo, las dos siguientes como filas finas (clic en una fila la sube). Se ordena sola:
   - agente que espera;
   - reunión en menos de 15 min;
   - bloque de enfoque activo;
   - comando largo terminado hace menos de 5 min;
   - actualizaciones pendientes.

   Cada tarjeta trae sus acciones:
   - agente: Aprobar / Rechazar (las de `AgentRow`);
   - reunión: Unirse (si la descripción o el lugar del evento tiene un enlace de Meet, Zoom o Teams) / Posponer el aviso 5 min;
   - enfoque: Pausar / Terminar;
   - comando: Abrir terminal.

   Rueda o ←/→ para pasar tarjetas. Sin tarjetas, un estado vacío tranquilo («Todo en orden»).
3. **Núcleo (centro, de la propuesta A).** `NeuralCore` de 92 px. Su estado sigue a los agentes: trabajando → pensando; uno espera → alerta en ámbar; terminado → ok. Debajo, «N AGENTES · M ESPERA». Clic → pestaña IA.
4. **Música (derecha, de la propuesta A).** Carátula, título, artista y app, progreso y controles. La onda es real si `cava` está instalado (por un servicio). Si no, son barras decorativas suaves solo mientras suena, y estáticas con `reduceMotion`. Sin reproductor: «Nada sonando» y el último reproductor usado.
5. **Franja de tiempo (abajo, de la propuesta C).** Ventana de 6 h centrada en ahora:
   - eventos de khal como bloques lavanda;
   - bloques de enfoque con contorno cian;
   - ejecuciones de agentes y comandos largos como líneas cian finas (de `dragon-activity range`);
   - marcador de «ahora».

   Pasar el cursor muestra el detalle. Clic en un evento abre el panel Fecha y hora.
6. **Interruptores (abajo a la derecha, de la propuesta A).** Cinco botones redondos: Wi‑Fi, Bluetooth, No molestar, Cafeína y Enfoque. Clic alterna; clic derecho abre su panel.
7. **Registrar actividad:** `Herdr.qml` (al empezar y terminar de trabajar un agente), `Commands.qml` (comandos ≥ 30 s) y `Focus.qml` llaman a `dragon-activity add` / `end` desde el servicio.
8. **Movimiento:** al expandir, las zonas entran en cascada (40 ms). La onda, el núcleo y la franja solo se animan con la isla expandida.

## 5. Rendimiento de Quickshell

Hoy Quickshell gasta un **12 % de CPU en reposo** y un **78 % con el launcher abierto**. Objetivos en la misma máquina:

| Situación | Objetivo |
|---|---|
| Reposo (sin paneles abiertos) | < 3 % |
| Launcher Gravedad abierto | < 35 % |
| Un popover abierto | < 15 % |

1. **Mide primero y deja la tabla en el HANDOFF:** `pidstat -p $(pgrep -x quickshell) 1 30` en cada situación. Revisa también si Qt está pintando por software (`QSG_INFO=1`). Si es así, dilo antes de seguir.
2. **Busca y corrige:**
   - animaciones o temporizadores activos con su ventana oculta;
   - el núcleo de la barra animándose sin parar (que repose estático o baje a 10–15 fps cuando no hay actividad, y se detenga del todo con `reduceMotion`);
   - `Canvas` que se repinta cada fotograma (núcleo, hilo del dock): pásalo a `Shape`, caché de capa o `ShaderEffect` donde se pueda;
   - procesos externos lanzados cada pocos segundos para métricas (lee `/proc` con `FileView` en su lugar);
   - `ColorQuantizer` y `ScreencopyView` vivos sin estar en pantalla.
3. Cada cambio en un commit propio, con su medición antes y después.

## 6. Dock Constelación

1. **Equilibrio:** hoy todas las apps fijadas crecen a la izquierda del núcleo. Repártelas a ambos lados de forma simétrica (alternando por orden, o mitad y mitad) y deja las apps abiertas no fijadas a la derecha. El núcleo queda siempre en el centro de la pantalla.
2. **Hilo visible en fondos claros:** añade un trazo de contraste debajo (oscuro y fino) o un halo, sin perder el aspecto sobre fondos oscuros.
3. **Iconos cuadrados de MacTahoe en nodos circulares:** escálalos al 70 % dentro del nodo, o recórtalos en círculo con un margen interior. Elige lo que se vea mejor con iconos reales y muestra ambos en el HANDOFF.

## 7. Deudas de la identidad

1. `modules/lock/LockView.qml`, `Lock.qml`, `LockTopIcon.qml`, `modules/launcher/LauncherView.qml` y `components/NeuralCore.qml` tienen colores propios (incluidos el violeta y magenta viejos en el launcher clásico) y unas 20 duraciones escritas a mano. Pásalos a tokens de `Theme`. Los colores semánticos del núcleo (`alert`, `ok`) pueden seguir como tokens fijos en `Theme`.
2. `Lock.qml` ejecuta `getent` y `hyprctl devices` directamente. Muévelo a servicios (`Session` para el nombre real, `Keyboard` para la distribución).
3. Regenera `sddm/dragon-core/preview.png` con el diseño actual.
4. En `sddm-greeter-qt6 --test-mode` no salen los botones de las esquinas (teclado y apagado). Averigua si es una limitación del modo de prueba. Si lo es, documéntalo; si no, arréglalo.

## 8. Migraciones

- `034-glass-style.sh` (punto 1).
- `035` solo si los cambios de `look.lua`, `rules.lua` o `glass.lua` necesitan llegar a configuraciones copiadas (no enlazadas) de sistemas instalados.
- Las dos con copia de seguridad, idempotentes y respetando `DRY_RUN` (ya cubierto por `tests/migrations-dry-run.sh`).

## 9. Comprobaciones antes de terminar

1. Ajustes › Apariencia cambia entre ahumado, clásico y líquido en vivo, sin doble desenfoque.
2. Las islas son algo más anchas, nada se solapa en los 4 estilos × 3 tallas, y los anillos ya no parecen indicadores de carga.
3. Todos los popovers abren y cierran con haz, despliegue y cascada, y Rendimiento coincide con el tablero.
4. Una notificación sale de la isla, se traza, se llena y vuelve a la isla al cerrarse. El cursor encima pausa el tiempo.
5. La tabla de rendimiento cumple los objetivos o explica por qué no.
6. El dock está centrado con el núcleo en medio.
7. La isla de mando muestra la pila, el núcleo, la música, la franja y los interruptores; al escribir en la línea de mando aparecen los mismos resultados que en el launcher; las islas ya no tienen borde blanco.
8. `tests/run-all.sh` en verde y `hyprctl configerrors` vacío.
9. **Lo que no pudiste ver o probar con ratón real, en una lista aparte.**

## 10. Documentación

- Une `docs/handoff-fase-3-claude.md`, `handoff-fase-3-codex.md`, `handoff-fase-4-claude.md` y `handoff-fase-4-codex.md` en `HANDOFF.md` como secciones `8f` (Fase 3) y `8g` (Fase 4), resumidas, sin perder trampas ni contratos. Después borra esos cuatro archivos.
- Esta fase va en `8h`.
- Las capturas que hagas, a 1×, con `oxipng` si está instalado, y nunca con ventanas, historial ni nombres de proyectos del usuario.

Termina con un resumen corto: qué hiciste, qué desviaste del diseño, la tabla de rendimiento y qué debe ver el usuario en pantalla.
