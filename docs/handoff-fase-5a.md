# Fase 5a · Base del Taller

Rama `feat/fase5a-base`, desde `main`; inicio 2026-10-31. En curso.

## 1. Entorno comprobado

| Herramienta | Versión |
|---|---|
| Hyprland | 0.57.0, commit `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426` |
| Quickshell | 0.3.2 (Arch) |
| herdr | 0.9.5, protocolo 22 |
| Docker CLI | 29.9.2 |
| Git | 2.56.0 |

`hyprctl configerrors` vacío. La terminal heredaba una firma antigua; se recuperó
la sesión de `wayland-1` con `lib/hyprland-session.sh`, sin cambiar configuraciones.
El socket de herdr responde a `api snapshot`; el sandbox requiere permiso para acceder.
No se probó aún el daemon Docker (fuera del alcance de 5a).

Herramientas opcionales de §5.7 presentes: `gio`, `udisksctl`, `lsblk`, `7z`,
`bsdtar`, `unrar`, `avahi-browse`, `smbclient`, `net`, `secret-tool`,
`vipsthumbnail`, `magick`, `ffmpegthumbnailer`, `wl-copy`, `xdg-open`.
Ausente: `inotifywait`.

## Decisiones

- El usuario confirma mover Dwindle/Scrolling a `SUPER + CTRL + T`; `SUPER + T`
  queda para el Taller.
- Las maquetas requeridas están en `docs/design/`; `FrameDecor` ya está en `main`.
- No hay ramas locales sin fusionar. El árbol inicial está limpio; `main` tiene
  tres commits por delante de `origin/main` que se conservan.

## 2–3. Filtro y memoria

Filtro único en `dragon-core/secret_filter.py`, compatible con portapapeles,
búsqueda y actividad. 4 pruebas nuevas + 40 de motores + 13 de actividad pasan.
Migración 043 despliega también el filtro en instalaciones por copia.

`dragon-mem`: esquema de §4, WAL, claves concurrentes, WIP, FTS transaccional,
criterios, notas, plantillas, revisión por contenido, comentarios, esperas,
métricas, exportación <4 KB, registro del sistema y 7 respaldos SQLite coherentes.
Migración 044 e instalación nueva comparten `lib/mem.sh`; una base previa se
respalda antes de ampliar el esquema. 13 pruebas con HOME/XDG temporales y
shellcheck en verde. Lectura fría (mediana de 7): 87,7 ms (<150 ms).

## 4. Puente de herdr

`docs/HERDR-API.md` se escribió a partir de las ayudas, el esquema incorporado y
el socket real antes de implementar el adaptador. `dragon-herdr` ofrece probe,
snapshot, watch --record, focus, read, prompt por stdin y start; conserva su
lanzador sin argumentos. Migración 045, instalación base y extra herdr incluyen
las librerías necesarias también en modo copia.

7 pruebas con servidor falso: eventos <2 s, desconexión y reconexión, SIGTERM,
esperas sin duplicados, foco con hyprctl simulado, tachado antes de recortar,
prompts bloqueados rechazados y cruce con worktrees. Snapshot y probe reales
responden; no se enviaron prompts ni se arrancaron agentes reales.

Límites: herdr 0.9.5 no publica relaciones de ayudantes ni timestamps;
`helper_of=null`, `features.helpers=false`, `since` es tiempo observado.

## 5. Servicios QML

`Herdr` consume un único `dragon-herdr watch --record`, mantiene compatibilidad
con las propiedades que usa la barra y registra actividad sin salida de terminal.
Lecturas de paneles solo a demanda y solo en memoria; `Mem` ejecuta consultas y
cambios puntuales. Ambos exponen estado y errores legibles. Se retiraron los
botones antiguos de aprobación/rechazo de IA y Mando, según el contrato de fase 5.
Migración 046 despliega la configuración copiada con respaldo.

Comprobación con Quickshell real offscreen, servidor herdr falso y HOME/XDG
temporales: servicios cargan, SQLite responde y agentes normalizados llegan con
las unidades de tiempo esperadas. Se corrigió `Object.fromEntries`, ausente en
el motor JS de Qt de esta máquina; se usa una iteración simple.

## 6. Estructura del Taller

Panel de 1226×612, cabecera, cinco pestañas, estados vacíos, FrameDecor y tokens
propios en Theme; ventana Overlay desmapeada y contenido descargado al cerrarse.
IPC `taller toggle|open <pestaña>|close|current`, SUPER+T; mosaico ahora
SUPER+CTRL+T como confirmó el usuario. El compositor es del tramo 5c (botón
visible y deshabilitado). Migración 047 incluye reglas de blur por alfa y binds.

Mock puro renderizado offscreen; reiniciado solo Quickshell (las ventanas del
usuario siguen abiertas) para registrar los tipos nuevos; el panel abre y cierra
por IPC. `hyprctl reload` y `configerrors` vacíos. Las migraciones 043–047 se
aplicaron a esta instalación enlazada, sin paquetes ni sudo.

## 7. Agentes

Cola por espacio, prioridad de bloqueados/listos, rama/tarjeta/nota/estado/tiempo,
ayudantes anidados si los datos los incluyen; detalle con lectura bajo demanda,
Ir al panel y Marcar como visto. Los botones de compositor/diff quedan visibles
y deshabilitados hasta 5b/5c. Sin tarjeta de consumo (dragon-tokens es opcional
de 5c, todavía ausente). Teclado: flechas y Enter, Ctrl+Tab y Ctrl+Shift+Tab.

Visto con el herdr real: este agente y su rama. El servidor rechaza leer historial
largo en pantalla alternativa mientras trabaja (`agent_not_idle`); se comprobó
y añadió caída a la salida visible, sin desplazar el terminal. Mock puro con
bloqueado, trabajando, listo, reposo y ayudante renderizado sin errores. Las
pruebas de servicios y vistas pasan. Migración 048 también renueva el puente.

## 8. Atención en la isla

AttentionCard (440×30, recortable al hueco disponible) con Ir ↵; prioridad de
bloqueados y después listos sin ver. SUPER+A usa el mismo servicio y recorre los
pendientes del estado prioritario. Ignorar 10 min por clic derecho en la pastilla
y acción explícita en la pila de Mando; visto/ignorado solo vive en memoria.
La pila conserva reuniones, enfoque, comandos y actualizaciones.

Prueba con servicios QML reales: prioridad bloqueado > listo, ignorar, marcar
visto y vencimiento del silencio. Mock de la pastilla renderiza a 440×30.
Migración 049 despliega el atajo y la interfaz también en instalaciones copiadas.

## 9. Proyectos

Selector en la cabecera y alta explícita (carpeta, nombre y prefijo opcionales).
Registrar llama a `dragon-mem project add`, refresca el selector y cruza de nuevo
los agentes con la memoria; escribir en los campos no produce efectos.
La selección carga las tarjetas de ese proyecto. Errores de ruta/duplicados se
muestran en el formulario. Prueba con servicios reales en HOME temporal: crea
el proyecto, refresca SQLite y conserva la selección. Migración 050.

## 10. Registro de apariencia

Los setters de Ajustes registran en `system_change` los cambios efectivos de
cristal, contorno, estilo/tamaño/contenido/métricas/ocultado de barra, intensidad
del acento y opciones de paleta. No se registra la carga inicial ni repetir el
mismo valor. La UI sigue llamando a Settings; solo el servicio llama a Mem.
Migración 051. Prueba con Settings y Mem reales en HOME temporal: registra
barra/cristal/paleta, ignora un duplicado y un ajuste de energía.

## Ajustes encontrados al validar

- El cliente real usa Ghostty ordinario (`com.mitchellh.ghostty`), con título
  `herdr · dragon-island-hypr`. El foco también sigue los ancestros locales del
  proceso cliente; comprobado con `dragon-herdr focus` real y con prueba aislada.
- Los hashes Git y los IDs de sesión se conservan en los contratos JSON. El
  detector opaco conservador sigue en el portapapeles/historial; las marcas de
  los contratos nuevos usan tipos de secretos reconocidos, incluidas variables
  con claves entre comillas en JSON.
- Los respaldos y lectores cierran sus conexiones SQLite de forma explícita.
  La búsqueda FTS filtra el proyecto antes de aplicar el límite de resultados.
- Migración 052 despliega estos ajustes. La prueba estática anterior de motores
  ahora permite únicamente AF_UNIX en el puente, manteniendo la prohibición de
  red y de evaluación dinámica en los motores.
- Capturas versionadas: solo datos sintéticos en `docs/screenshots/fase5a/`.
  Comprimidas con `scripts/optimize-images.sh`; se usó el binario oficial de
  optipng extraído temporalmente en `/tmp`, sin instalar paquetes del sistema.

## Validación adicional

La suite completa detectó una carrera intermitente al activar WAL por primera
vez desde dos procesos. La inicialización ahora se serializa con un bloqueo de
archivo privado; las transacciones siguen protegidas por SQLite. La prueba crea
ocho bases desde dos procesos concurrentes cada una.

El rechazo de prompts vacíos o excesivos ocurre antes de crear un espacio.
Una prueba de entrada larga detectó coste cuadrático en el patrón de URL sin
credenciales; se acotó el esquema de URL y se evitó el retroceso del usuario.
Se conservan las pruebas anteriores y una entrada de 65 KB se filtra sin pausas.

Prueba de extremo a extremo: evento Unix del herdr falso → observador real
`--record` → servicio QML real → Agentes y prioridad, en menos de 2 segundos.
Todas las pruebas nuevas aíslan HOME y también XDG_RUNTIME_DIR.
Benchmarks independientes (7 ejecuciones frías): memoria 89,9 ms, snapshot de
herdr 91,8 ms; objetivo <150 ms.

CPU de reposo, sin servidor herdr en ambos perfiles, comparando `main` en una
copia temporal con 5a, 15 s de calentamiento + mediana de 7 muestras de 5 s:
11,60 % → 10,60 % de un núcleo (delta −1,00 puntos, sin aumento medible).
Con este agente trabajando las muestras oscilan entre 9,8 % y 19,2 % y no
permiten concluir diferencias de 0,3 puntos. La sesión normal quedó restaurada
con herdr conectado después de las mediciones.
