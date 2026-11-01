# Fase 5b · Contenedores y Git

Rama `feat/fase5b-docker-git`, desde `main` con 5a fusionado. 2026-11-01.
Un commit por cada uno de los seis puntos; el último incorpora despliegue y ajustes
hallados con el Engine y Qt reales. No se modifica el handoff global de la fase.

## Implementación

1. **dragon-docker** (`6b509cb`): HTTP sobre AF_UNIX, biblioteca estándar,
   negociación de versión del Engine, Compose por etiquetas, inspección, acciones,
   CPU/memoria/red cada dos segundos, eventos, logs y problemas. Pruebas de socket
   falso en `tests/docker/`.
2. **dragon-git** (`96f9b25`): porcelain v2 con NUL, numstat, diff unificado
   hasta 2.000 líneas, preparación, commit/push/pull de avance rápido, ramas,
   historial, stash, worktrees, hash por contenido y observador. Pruebas con repos
   temporales, sin cambiar la identidad ni escribir configuración Git.
3. **Servicios** (`7a27293`): Docker y Git, registrados en `services/qmldir`;
   `ToolRequest` gestiona respuestas JSON puntuales. Docker mata todas sus lecturas
   y flujos al desactivarse; Git detiene watch. Las operaciones Git explícitas ya
   iniciadas pueden terminar aunque se cierre la pestaña, evitando cortar un commit
   o push en curso. Sus respuestas antiguas no cambian el proyecto nuevo.
4. **Contenedores** (`8a8c367`): agrupación Compose, fallos arriba, miniaturas de
   CPU, banner, tarjetas CPU/memoria/red, filtros y búsqueda en LogView, inspección
   tachada y acciones explícitas. El compositor de prompts pertenece a 5c: su botón
   permanece visible y deshabilitado.
5. **Git** (`d18586b`): preparados/cambios con casillas, DiffView, mensaje editable,
   chips de tipo, comprobación de secretos, commit y commit/push, historial, ramas,
   pull/push y lazygit. UI pura con servicios inyectados; colores y geometría en Theme.
6. **Despliegue**: `lib/taller-tools.sh`, instalación nueva desde `core`, migraciones
   **055** (motores) y **056** (servicios y pestañas). Respaldos e idempotencia en
   modo copia y enlaces, `DRY_RUN` y `ASSUME_YES`. Documentación de preparación y
   teclas de casillas/chips en ambas referencias de atajos.

## Decisiones y detalles de los contratos

- Docker usa `/var/run/docker.sock`; `DRAGON_DOCKER_SOCKET` permite un socket Unix
  temporal en pruebas. Sin Podman, llamadas a modelos ni comunicación con agentes.
  Referencia: [Docker Engine API](https://docs.docker.com/reference/api/engine/version/v1.47/).
- Los reinicios de política se detectan con eventos `start`, además de `restart`;
  no se suman dos veces. La ventana es de diez minutos. El contador vitalicio solo
  sirve si la fecha de creación demuestra que todo ocurrió dentro de esa ventana.
  OOM también se conserva desde eventos recientes, aunque un nuevo arranque haya
  borrado `State.OOMKilled`.
- CPU compara los contadores de muestras consecutivas: `one-shot` puede omitir
  `precpu_stats`. Memoria descuenta caché inactiva; red es delta de bytes/segundo.
- Logs: ERROR/FATAL/panic/Traceback/Exception → error; WARN → aviso; resto → info,
  sin distinguir mayúsculas. Sin ANSI. Solo repeticiones consecutivas se colapsan,
  incluso con filtro. En seguimiento se actualiza la misma fila (`ts`, nivel y texto)
  al subir `count`. Solo memoria, máximo 200 filas en el servicio; nunca disco.
  Hay reconexión con espera de 1 a 10 s y terminación por SIGTERM.
- Secretos: filtro compartido antes de salida; PEM multilínea oculto también en
  logs/diffs. Inspect tapa todos los valores de entorno. Commit lee blobs del
  **índice**, aunque la copia de trabajo ya no tenga el secreto; devuelve archivo,
  línea y tipo, jamás valor. También rechaza `.env` y `.env.*`.
- Unstage solo cambia el índice; funciona antes del primer commit y preserva una
  copia de trabajo posterior. Un worktree con cambios o archivos nuevos no se quita.
  Rutas literales con espacios/Unicode; un enlace no permite leer un archivo externo.
- Git: cinco segundos por operación, 120 s en push/pull; sin force. Si el commit se
  hizo pero falló push, informa `committed:true`: basta reintentar Push. Los mensajes
  fuera de `tipo(ámbito): texto` son avisos. No hay mensaje generado ni envío automático.
- Watch usa inotifywait con antirrebote de 300 ms si está disponible; aquí falta,
  así que se comprobó sondeo de dos segundos y también la ruta inotify con ejecutable
  simulado, incluido su cierre sin hijos huérfanos.
- Docker/Compose/lazygit ya están en `packages/user-pacman.txt` (Mis apps); no se
  añadieron paquetes obligatorios. No se habilita el daemon ni se cambian grupos.
  Shell y lazygit comprueban sus ejecutables antes de abrir Ghostty.

## Verificación

- Nueve pruebas Docker y doce Git; servicios reales de Quickshell, migraciones y
  dos mocks visuales en `tests/fase5b/`. HOME y XDG temporales. Incluyen permisos,
  desconexión/reconexión de logs, SIGTERM, bucles, OOM, TTY y tramas multiplexadas,
  secretos, conflictos, symlinks, worktrees, repos sin commits y diff truncado.
- Mediana de siete arranques fríos: **Docker ps 96,6 ms**; **Git status con
  1.000 archivos 88,8 ms**. Objetivo <150 ms; runner permite 300 ms.
- Compose real con imagen local `python:3.13-slim`, proyecto exclusivo de prueba,
  sin red, puertos ni volúmenes. Worker limitado a 32 MiB: cinco reinicios,
  OOMKilled y salida 137; banner y logs colapsados vistos en Wayland. API: CPU
  ~0,88 %, memoria ~4 MiB; muestras separadas por **1,99 s**. Todos los contenedores
  creados por la prueba se retiraron al finalizar; no se operó sobre los del usuario.
- Vistas reales capturadas con `grim` mediante un shell temporal: OOM, métricas y
  Git con diff de un repo temporal. También se abrió el Taller instalado por IPC.
  Las capturas del escritorio quedan en `/tmp/dragon5b` por contener fondo privado;
  se versionan únicamente los renders sintéticos que se enlazan más abajo.
- Migraciones 055–056 desplegadas manualmente en la instalación enlazada, sin
  sudo ni paquetes. Quickshell se reinició para registrar los tipos. El ledger de
  update.sh queda bajo el control del actualizador (reaplicarlas es idempotente).
- Al cerrar el Taller, comprobación de procesos: no queda dragon-docker ni
  dragon-git watch. Las pruebas también verifican esto con servicios reales.
- Capturas comprimidas con `scripts/optimize-images.sh`; optipng oficial extraído
  temporalmente en `/tmp`, sin instalar paquetes del sistema.
- `tests/run-all.sh`: **tres ejecuciones consecutivas en verde** (317,3 / 335,6 /
  327,0 s). Incluyen shellcheck, Bash/Lua, QML real, regresiones, documentación,
  imágenes, 56 migraciones sin escrituras en dry-run e instalación idempotente.
  Registros locales: `/tmp/dragon5b-suite-final-{1,2,3}.log`.
- Verificación final de sesión: Quickshell carga las pestañas sin errores nuevos
  (solo avisos previos de HerdrHelp y del tema de iconos); `hyprctl configerrors`
  vacío. El Taller queda cerrado, sin procesos de sus motores.
- Ajuste de estado final: al parar un contenedor se descartan sus métricas; tampoco
  se aceptan muestras tardías de un contenedor detenido. Cerrar limpia las series
  en memoria y evita mostrar cifras antiguas al reabrir. Probado con Parar sobre el
  socket falso y el servicio QML real, además de las pasadas completas posteriores.

## Qué debe verse

1. `SUPER+T` → Contenedores: proyectos Compose, errores rojos primero, contenedor
   elegido con sus acciones, problema, gráficas y logs que se actualizan. Todo,
   Errores y Avisos filtran sin volver a ejecutar comandos.
2. Sin Docker o sin permiso: explicación legible, con indicación del grupo docker.
   Cerrar o cambiar de pestaña detiene todos sus procesos.
3. Git, después de seleccionar un proyecto registrado: rama con ↑↓, preparados y
   cambios; seleccionar un archivo muestra diff numerado con fondos verde/rojo.
   Espacio en una casilla prepara o quita del índice; Tab recorre los controles.
4. Mensaje de commit vacío inicialmente y editable; chips solo tras pulsarlos.
   `.env` preparado muestra aviso rojo y el commit se rechaza sin guardar nada.
   Commit correcto limpia el campo. Ramas, historial y lazygit están a la derecha.
5. Sin proyecto: «Selecciona un proyecto»; sin lazygit: indicación de instalarlo.
   Ctrl+Tab cambia pestaña; Esc cierra por el mecanismo existente.

## Límites y decisiones pendientes

- No se probaron teclas/clics físicos, un push/pull real con credenciales ni un shell
  interactivo de contenedor. Los destinos de acciones se probaron con servicios,
  socket falso y repos temporales, sin enviar teclas con vin.py ni cerrar terminales.
- El proyecto de prueba no produce tráfico: el delta de red se verifica con datos
  sintéticos. La reconexión de logs y SIGTERM se probaron con el socket falso.
- No se midió CPU del escritorio en reposo: la aceptación de 5b comprueba ausencia
  de procesos de los motores al cerrar; la medición global de ligereza se conserva
  para el cierre de fase. No se comprobó específicamente multi-monitor.
- No hace falta ninguna decisión del usuario. Kanban, prompts y Revisión continúan
  en 5c; el explorador pertenece a 5d.

## Reproducir

```sh
./tests/run-all.sh
python3 tests/fase5b/bench.py
# Opt-in: usa una imagen local; crea y retira solo su proyecto Docker temporal.
python3 tests/fase5b/real_compose.py --run --visual /tmp/dragon5b
# Renders puros, sin Docker/Git/herdr:
tests/qml/render-mocks.sh /tmp/dragon-mocks
```

Capturas: [Contenedores](screenshots/fase5b/taller-contenedores.png),
[permiso Docker](screenshots/fase5b/taller-docker-sin-permiso.png),
[Git](screenshots/fase5b/taller-git.png),
[secretos](screenshots/fase5b/taller-git-secretos.png),
[sin proyecto](screenshots/fase5b/taller-git-vacio.png).
