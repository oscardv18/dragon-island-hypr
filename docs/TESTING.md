# dragon-island — Checklist de pruebas manuales (EndeavourOS)

Todo esto se escribió y validó de forma estática en Windows. Esta lista cubre lo que solo se puede comprobar en la máquina real. Marca cada punto y anota lo que falle (con la salida de `qs log` o `hyprctl configerrors`).

Antes de empezar, abre una terminal y deja corriendo:

```sh
qs log -f                 # errores de Quickshell con archivo:línea
```

## 0. Instalación

- [ ] `./install.sh --dry-run` muestra todas las acciones, no pide sudo y no cambia nada.
- [ ] `./install.sh` termina sin errores. Revisa `~/.local/state/dragon-island/install.log`.
- [ ] Ejecutarlo una segunda vez no hace nada nuevo (sin respaldos nuevos, "Ya enlazado").
- [ ] `~/.config/hypr`, `~/.config/kitty` y `~/.config/quickshell` son enlaces al repo (o copias, si elegiste copia).
- [ ] Si había configuraciones previas, están en `~/.local/state/dragon-island/backups/<fecha>/`.
- [ ] El aviso final no menciona fuentes faltantes ni otros daemons de notificaciones.

## 1. Primer inicio de sesión

- [ ] SDDM muestra la sesión **Hyprland** y **Plasma sigue funcionando** (entra en Plasma una vez y vuelve).
- [ ] En Hyprland se abre la ventana flotante "dragon-island: primer arranque". `hyprpm update` pide la contraseña y compila hyprbars y hyprfocus.
- [ ] Tras cerrarla, las ventanas tienen barra de título: 30 px, botones a la **izquierda** en el orden cerrar (rojo), maximizar (ámbar), flotar (verde).
  - Si el orden sale invertido, cambia el orden de `add_button` en `config/hypr/plugins.lua`.
- [ ] Al cambiar el foco con el teclado, la ventana hace un pequeño "shrink" (hyprfocus).
- [ ] En el segundo inicio de sesión no vuelve a aparecer la ventana del primer arranque.

## 2. Hyprland

- [ ] `hyprctl configerrors` está vacío.
- [ ] El borde activo tiene el degradado magenta → violeta → cian; los huecos son 6/12 y el redondeo 14.
- [ ] Probar cada atajo de [KEYBINDS.md](KEYBINDS.md), en especial SUPER+F, SUPER+V, SUPER+SHIFT+1–5, Print y SUPER+SHIFT+S.
- [ ] El gesto de 3 dedos cambia de escritorio (portátil).
- [ ] Las teclas de volumen y brillo funcionan, también con la pantalla bloqueada.
- [ ] Dolphin y las apps Qt usan el tema de Plasma (`QT_QPA_PLATFORMTHEME=kde`).
- [ ] Una app que pida permisos (p. ej. `pkexec true`) muestra el diálogo de hyprpolkitagent.
- [ ] A los 2,5 min baja el brillo, a los 5 min bloquea (hypridle) y hyprlock acepta tu contraseña.

## 3. Barra

- [ ] La barra flota a 10 px del borde superior y a 14 px de los lados, con dos islas translúcidas con desenfoque.
- [ ] **Clic a través de los huecos:** un clic en el espacio entre islas llega a la ventana o al escritorio de debajo.
- [ ] Las ventanas en mosaico empiezan por debajo de la barra (zona exclusiva).
- [ ] Workspaces: el activo lleva degradado y brillo, los ocupados un punto de color, los vacíos texto tenue. El cambio anima ~200 ms.
- [ ] Ventana activa: icono de la app, clase y título tenue; los títulos largos se recortan sin invadir la isla central.
- [ ] CPU, RAM, Wi‑Fi, Bluetooth, volumen, batería y reloj muestran valores reales (compara con `htop`, `nmcli`, `wpctl status`).
- [ ] El reloj muestra el formato `lun 5 oct  16:23`.
- [ ] Al pasar el ratón por una cápsula, cambia a `surfaceHi` en ~120 ms.

## 4. Dynamic Island

- [ ] **Al arrancar** (o con `qs kill; qs -d`), la isla cae desde arriba con rebote y un leve "aplastamiento" horizontal.
- [ ] **Clic en la isla o SUPER+D:** el dashboard se "derrama" desde el borde superior (pegado arriba, esquinas inferiores redondeadas). El contenido entra con un pequeño retraso.
- [ ] Al abrirse aparece el scrim negro. Un clic fuera, **Esc**, el tirador inferior o SUPER+D lo cierran: primero se desvanece el contenido y después se recoge la forma.
- [ ] Hacer clic en zonas vacías del dashboard **no** lo cierra.
- [ ] Estados temporales, con su duración:
  - [ ] Cambiar el volumen o el brillo: OSD con barra y número durante ~2 s.
  - [ ] `notify-send "Hola" "prueba"`: icono, título y "· app" durante ~4 s.
  - [ ] `notify-send -u critical "Crítica" "x"`: se queda hasta descartarla (clic derecho en la isla o en el centro).
  - [ ] SUPER+2: "Escritorio 2" con puntos durante ~2 s.
  - [ ] Con música (Spotify, mpv con MPRIS): carátula 24×24, título, "· app" y ecualizador animado. Clic central = play/pausa.
  - [ ] Sin nada de lo anterior: reloj con punto de estado (verde; magenta si hay no leídas; gris con No molestar; rojo parpadeante grabando).
- [ ] La prioridad se respeta: con música sonando, subir el volumen muestra el OSD y luego vuelve a la música.
- [ ] Con un vídeo en pantalla completa, la isla cerrada se oculta (excepto OSD y notificaciones).

## 5. Dashboard

- [ ] La cabecera muestra "Buenas tardes, <tu nombre>", fecha · host · tiempo activo, y los botones bloquear / suspender / apagar (este con tinte rojo; abre el menú de energía).
- [ ] La tarjeta de música funciona (anterior, play/pausa, siguiente, progreso). Sin reproductor muestra "Nada en reproducción".
- [ ] Los sliders de volumen y brillo funcionan arrastrando y con la rueda. Sin retroiluminación, el de brillo no aparece.
- [ ] Mosaicos: Wi‑Fi, Bluetooth, No molestar, Luz nocturna (pantalla más cálida), Captura (selección de región) y Grabar.
  - Grabar pide la zona con slurp y muestra el contador. Al pararlo, el archivo queda en `~/Vídeos` (o `~/Videos`) y llega una notificación.
- [ ] El control segmentado cambia el perfil de energía (`powerprofilesctl get`).
- [ ] Las barras de CPU, RAM, temperatura y disco tienen sentido, y aparecen las 3 últimas notificaciones.

## 6. Popovers (cada cápsula)

Comprobar en todos: que aparece 8 px bajo su cápsula, alineado a su borde derecho, con animación de escala y desplazamiento; que solo hay uno abierto; que abrir otro cierra el anterior; y que Esc y clic fuera lo cierran.

- [ ] **Rendimiento:** barras por núcleo, RAM / GPU / Temp, 4 procesos con más CPU (se actualizan) y perfil.
- [ ] **Wi‑Fi:** interruptor, tarjeta de la red actual con banda, velocidad e IP, y la lista con señal y seguridad.
  - Conectar a una red guardada.
  - Conectar a una red nueva con contraseña (y con una contraseña incorrecta: debe pedirla otra vez).
  - "Configuración de red…" abre el editor (nm-connection-editor o el módulo de KDE).
- [ ] **Bluetooth:** interruptor, dispositivo conectado con batería y la lista de vinculados (clic = conectar o desconectar). "Buscar dispositivos" encuentra y vincula uno nuevo.
- [ ] **Sonido:** sliders de salida y micrófono. La lista de salidas marca la activa con un punto magenta y cambiarla mueve el audio. El mezclador por app muestra cada aplicación con su slider.
- [ ] **Batería:** porcentaje grande, tiempo restante, consumo en W, salud, brillo y perfil.
- [ ] **Notificaciones:** No molestar, tarjetas con icono, título, cuerpo, app · tiempo y acciones, y "Borrar todo". Al abrirlo desaparece el punto de no leídas.
- [ ] **Calendario:** reloj con segundos y mes con lunes primero (`L M X J V S D`); hoy lleva degradado. Las flechas y la rueda cambian de mes y al reabrir vuelve al mes actual.

## 7. Lanzador y menú de energía

- [ ] SUPER+Space abre el lanzador centrado con el foco en la búsqueda.
  - Escribir "fire" encuentra Firefox y "trm" encuentra Terminal (búsqueda difusa).
  - `↑ ↓` y `Enter` abren la app y la cierran el lanzador.
  - Las apps más usadas suben en la lista vacía (`~/.local/state/quickshell/.../app-usage.json`).
- [ ] SUPER+Escape: el menú de energía se navega con flechas y `1–5`. Prueba Bloquear y Suspender. Cerrar sesión debe volver a SDDM.

## 8. Notificaciones

- [ ] `for i in $(seq 1 3); do notify-send "n$i" "cuerpo $i"; done`: se apilan hasta 3 popups bajo la isla derecha (solo en el monitor enfocado) y caducan a los ~4 s. Pasar el ratón por encima pausa el tiempo.
- [ ] `notify-send -A ok=Aceptar "Acción" "x"`: el botón "Aceptar" funciona.
- [ ] Con No molestar no salen popups, pero las notificaciones quedan en el centro.
- [ ] **50 notificaciones:** `for i in $(seq 1 50); do notify-send "n$i" "x"; done`. El centro hace scroll con fluidez y "Borrar todo" las elimina.
- [ ] **0 notificaciones:** el centro muestra "Sin notificaciones".
- [ ] Recargar Quickshell (guardar un `.qml`) no vuelve a mostrar popups de notificaciones antiguas.

## 9. Casos límite

- [ ] **Sin batería** (sobremesa o batería retirada): no hay cápsula de batería y el popover lo explica.
- [ ] **Sin reproductor:** isla en modo reloj y tarjeta vacía en el dashboard.
- [ ] **Sin Bluetooth** (`sudo systemctl stop bluetooth` o sin adaptador): la cápsula se oculta, el mosaico queda desactivado y el popover lo explica.
- [ ] **Wi‑Fi apagado:** icono tachado, mosaico apagado y popover sin lista. Con el interruptor de hardware se muestra el aviso.
- [ ] **Solo Ethernet:** icono de cable; el popover muestra "Ethernet" con IP y velocidad.
- [ ] **Varios monitores:**
  - [ ] Barra e isla en cada monitor.
  - [ ] SUPER+D abre el dashboard en el monitor enfocado.
  - [ ] Un popover se abre en el monitor de la cápsula pulsada.
  - [ ] Conectar o desconectar un monitor en caliente recrea la barra y la isla.
- [ ] **Escalado fraccional** (`scale = 1.25`): textos nítidos y nada recortado.

## 10. Rendimiento

- [ ] Con todo cerrado, `top` muestra quickshell con un uso de CPU bajo (sondeos cada 2 s y lectura de brillo cada 300 ms).
- [ ] Las animaciones de la isla van fluidas (sin tirones) a 60/120 Hz.

## Si algo falla

- QML: `qs log` muestra el `archivo:línea`. `qs ipc call debug toggle` abre el panel con el valor en vivo de todos los servicios.
- Hyprland: `hyprctl configerrors` y `$XDG_RUNTIME_DIR/hypr/*/hyprland.log`.
- Plugins: `hyprpm list`, `hyprctl plugin list` y `~/.local/state/dragon-island/firstrun.log`.
