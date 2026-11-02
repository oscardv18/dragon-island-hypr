# Campana de notificaciones en la isla derecha

Rama `feat/icono-notificaciones`, desde `main` (`053d774`), worktree
`/home/oddv/Devs/dragon-island-icono-notificaciones`. Sin vin.py, push ni fusión.
No se modificó la configuración instalada ni se reinició el Quickshell del usuario.

## Lecturas y decisión visual

Revisados el historial de `RightIsland.qml`, el diff de `8949186`, las capturas
`docs/design/13-capturas.png` (cápsulas y estados de interacción) y
`28-emergentes.png` (campana junto al reloj, superficies y halo), el prompt de
pulido y las secciones 7m/7t/8h del handoff. `8949186` quitó la cápsula y llevó
No molestar/no leídas al reloj; el pulido posterior volvió a separar los paneles
Calendario y Notificaciones, pero no devolvió la campana.

**Se queda el contador de la campana.** Se retiran los puntos de No molestar y
no leídas del reloj; conserva únicamente el punto de actualizaciones y su acceso
al calendario. El acceso a Notificaciones desde el calendario y SUPER+N continúa.
El clic derecho para No molestar se traslada del reloj a la campana.

## Cambios (un commit por punto)

1. `NotificationBell.qml` en `RightIsland`, antes del reloj, incluso en estilo D:
   icono `Icons.bell`/`Icons.bellOff`, estado desde `Toggles.dnd`, contador desde
   `Notifs.unreadCount`. El contador permanece con No molestar, con otro tono;
   se limita a `99+`, y el tooltip conserva el total. Sin contar ni consultar
   notificaciones desde la UI. Tokens nuevos solo en `Theme.qml`; misma Capsule,
   tipografía, hover y halo que las cápsulas vecinas.
2. Clic izquierdo: `island.openPopover` → `Bar.openFrom` →
   `ShellState.toggleAt("notifications", …)` con monitor, borde y centro del haz.
   Segundo clic cierra; sustituye otro panel abierto. Derecho:
   `Toggles.toggleDnd()` sin cerrar/abrir paneles. Se ignora el botón central.
3. Migración 130, pruebas, documentación y comprobación visual. La migración
   renueva Theme, el componente y RightIsland **solo en instalaciones por copia**,
   con `backup_copy`, reemplazo atómico y DRY_RUN=1/true. Conserva enlaces de
   configuración y subdirectorios enlazados; segunda aplicación sale 10 sin
   cambios ni nuevo respaldo. No llama a procesos de la UI ni reinicia el shell.

El espacio del contador está reservado desde cero no leídas: ni la isla cambia
su ancho por el contador ni se modifica el tamaño constante de sus ventanas.
Se añade una cápsula al contenido estático; ContextChips sigue agrupando lo que
no cabe. No hay temporizadores, consultas, procesos ni animaciones permanentes
nuevos; solo los efectos finitos ya existentes de Capsule/tooltip al interactuar.

## Verificación

- Quickshell **0.3.2** real, configuración temporal y servicios inertes desde
  `tests/qml/fixtures/right-island.json`. No se levantó otro NotificationServer.
  `RightIsland`, `NotificationBell`, Theme, Capsule y ShellState son los reales;
  el harness extrae los métodos openFrom/isOpen del Bar real para comprobar
  anclajes sin cargar el resto del escritorio. Entrada por señales de clic de
  Capsule; no se envió teclado ni ratón al escritorio del usuario.
- Cinco pruebas en `tests/bar/`: no leídas 0/3/120, DND con/sin no leídas,
  abrir/cerrar/sustituir calendario, mover a otro monitor **simulado**, halo
  activo, contador estable, 12 combinaciones A/B/C/D × compacta/normal/amplia,
  backup, DRY_RUN=1/true, repetición y protección de enlaces. Integradas en
  `tests/run-all.sh`. Se ejecutó este grupo, no toda la suite ajena al cambio.
- 18 capturas **solo locales**, inspeccionadas sin subir al repo:
  `/tmp/dragon-notifications-321evktq/out/` (empty, unread, dnd, dnd-empty,
  overflow, active y 12 combinaciones). Campana legible, contador lavanda,
  DND tachado y atenuado, halo cian al abrir; D compacta sin recorte ni solape.
- Sesión temporal en reposo con reloj/datos congelados: **0,0 % de un núcleo
  durante 8 s**, medido por `/proc/<pid>/stat`. Es la fixture, no una medida del
  coste global del escritorio. No aparece trabajo periódico añadido en el
  componente. Log: `/tmp/dragon-bell-idle-vtoz4o4v/idle.log`.
- `shellcheck -x migrations/130-notification-bell.sh tests/run-all.sh`, sintaxis
  Bash y `git diff --check`: OK. La carga temporal no muestra errores QML;
  únicamente las advertencias normales del backend offscreen (Wayland heredado
  y máscaras no soportadas).

Pendiente en el escritorio instalado: comprobar con las notificaciones reales,
con un segundo monitor físico y con las cápsulas contextuales reales cargadas.
La migración no se aplicó al HOME real. La sesión de pruebas usó offscreen para
no modificar superficies ni foco del escritorio del usuario.

## Resumen (tres líneas)

Campana con contador y estado No molestar en la isla derecha, también en D; sin duplicado en el reloj.
Clic abre/cierra Notificaciones y derecho alterna No molestar; anclajes y cinco pruebas pasan.
Migración 130 con respaldo y DRY_RUN; 18 capturas locales y fixture en reposo sin CPU medible.
