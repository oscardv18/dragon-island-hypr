# Fase 5d · Explorador de archivos — pantallas y servicios de Quickshell

Rama `feat/fase5d-pantallas`, desde `main` (5a fusionado); 2026-11-01.
Alcance de este agente: **solo** `config/quickshell/**` (pantallas y servicios del
tramo 5d) y sus pruebas de interfaz. El comando `dragon-files`, sus pruebas
(`tests/files/`), las migraciones, el atajo `SUPER + E`, las reglas de ventana y el
gestor predeterminado (d7) son del agente del comando.

## Qué se hizo (un commit por punto)

| Punto | Commit | Contenido |
|---|---|---|
| d1 | `feat(archivos): listado y navegación…` | `Files`, `FilesRequest`, `FilesWindow`/`FilesPanel`, `Sidebar`, `FileList`, `FileGrid`, `files.js`, IPC `files` |
| d2 | `feat(archivos): cola de operaciones…` | `FileOps`, `OpsBar`, `Preview`, menú contextual, diálogos, arrastrar y soltar, deshacer |
| d3 | `feat(archivos): dispositivos…` | `Devices` (discos, USB, MTP, LUKS) y su sección en la barra lateral |
| d4 | `feat(archivos): comprimidos…` | `Archives`, `ArchiveSection`, `ExtractDialog`, Comprimir… |
| d5 | `feat(archivos): red local…` | red en `Devices`, `NetView` y sección RED |
| d6 | `feat(archivos): compartir…` | `share*` en `Files`, `ShareDialog` |
| d8 | `feat(archivos): pulido…` | papelera, ir al nombre tecleando, estados vacíos, atajos en `Keybinds.qml`, estas notas |

Estructura: `modules/files/` tiene la vista pura (`FilesPanel` y sus piezas, sin
procesos) y la ventana real (`FilesWindow`, `FloatingWindow` normal, varias a la vez).
Los servicios se inyectan, así que `tests/qml/files_mock.qml` dibuja las mismas
pantallas con los datos de `tests/qml/fixtures/files-*.json`.

Tokens propios en `Theme.files.*` (bloque marcado `fase5d`), iconos en un bloque
marcado de `Icons.qml`, tipos en un bloque marcado de `services/qmldir` y bloque
propio en `tests/run-all.sh`.

## Contrato que espera la interfaz (para el agente de `dragon-files`)

Todo según §5.7 del plan. Donde §5.7 no fija la forma exacta, la interfaz asume lo
siguiente; los datos de muestra de `tests/qml/fixtures/` son ejemplos válidos de cada
respuesta y `tests/files_ui/fake_dragon_files.py` es un simulador que cumple este
contrato. **Si el comando decide otra forma, basta con ajustar el servicio; las
vistas no leen la salida del comando.**

Convenciones: todo comando de una sola respuesta recibe `--json` al final y devuelve
`{"ok":true,…}` o `{"ok":false,"error":{"code","message","hint"}}`. Los flujos llevan
`--json-progress` (o son `watch`) y emiten una línea JSON por evento.

| Llamada | Argumentos exactos que envía la interfaz | Respuesta que usa |
|---|---|---|
| ls | `ls <ruta> --sort name --dirs-first --hidden [--git]` | §5.7; en carpetas, **`count`** (elementos dentro) para «12 elem.»; enlaces: `broken`, `link_dir` opcionales. La papelera se lista con `ls trash:///` (cada entrada con `uri`) |
| places | `places` · `places add <ruta> [--label]` · `places rm <ruta>` | `{"places":[{id,label,path,kind,repo,badge}]}` (también acepta `{xdg,projects,bookmarks}`); `kind:"trash"` con `badge` = elementos |
| watch | `watch <ruta>` | cualquier línea = cambio (antirrebote de 300 ms en la interfaz) |
| props | `props <ruta>` | `perms`, `owner`, `mime`, `size`, `mtime`; carpetas `dir_size`, `dir_count`, `truncated`; imágenes `image:{width,height,camera,taken,exposure,lens}` |
| thumb | `thumb <ruta> --size large` | `{"ok":true,"thumb":"/ruta/en/cache.png"|null}` |
| abrir | `open <ruta>` · `open-with <ruta> --list` → `{"apps":[{id,name,default}]}` · `open-with <ruta> --app <id>` · `terminal-here <ruta>` | `ok` |
| op | `op copy|move <rutas…> --dest <dir> --conflict ask` · `op trash <rutas…>` · `op delete <rutas…> --confirm` · `op rename <ruta> --name <n>` · `op mkdir <dir> --name <n>` · `op link <rutas…> --dest <dir>` | progreso `{"t":"progress","pct","file","bps","index","count"}`; **conflicto** `{"t":"conflict","file","dest"}` y espera **una línea por stdin** `{"answer":"skip|overwrite|rename","all":bool}`; fin `{"t":"done","moved":[{"from","to"}]}` (move/rename: lo usa deshacer); error `{"t":"error","error":{…}}` |
| papelera | `trash empty --confirm` · `trash restore <uri…>` | como `op` |
| dispositivos | `devices` · `devices --watch` · `mount|unmount|eject <id>` · `unlock <id> --passphrase-stdin` | lista §5.7 (suelta o `{devices:[…]}`), `hidden:true` para no mostrar; `mount`/`unlock` devuelven `mountpoint` |
| red | `net discover` · `net mounts` · `net saved` · `net shares <equipo>` · `net connect <uri> [--user u] [--password-stdin] [--save]` · `net unmount <uri>` · `net save <uri> [--name]` · `net forget <uri>` | `hosts:[{name,address,protocol,uri,port,kind?}]`; `mounts:[{uri,name,protocol,host,address,path,user,free,total,version}]`; `servers:[{uri,name,protocol,user}]`; `shares:[{name,comment,size?}]`; `connect` → `mountpoint` o error **`auth_required`**/`bad_password` |
| comprimidos | `archive list <a>` · `archive test <a>` · `archive extract <a> --dest <d> --conflict <c> [--own-folder] [--password-stdin] [--confirm-bomb] --json-progress` · `archive create --format <f> --out <a> --paths <…> --json-progress` | `list` según §5.7 más **`method`** opcional; errores que la interfaz entiende: `password_required`, `bad_password`, `bomb_suspected`, `unsafe_paths`, `no_space` |
| compartir | `share status` (todas) · `share status --path <r>` · `share enable --path <r> --name <n> [--rw] [--guest]` · `share disable --path <r> [--name <n>]` | `{shared,name,rw,guest,host,addresses:{smb,unc},size?,firewall?:{needed,command,message}}`; negativas con `forbidden_path` |

Contraseñas: siempre por stdin, primera línea. En `archive extract --password-stdin`
stdin sigue abierto después para las respuestas de conflicto. Ninguna contraseña
aparece en argumentos (las pruebas lo comprueban).

Ampliaciones respecto a §5.7, para que el agente del comando decida: `count` en
carpetas, `places add|rm`, `open-with --app`, `trash empty|restore`, `net saved|save|forget`,
`method` en `archive list`, la pregunta de conflicto por stdin y `moved` en `done`.

## Qué debe ver el usuario (cuando exista `dragon-files` y el atajo)

1. `qs ipc call files open [ruta]` (y `SUPER + E` cuando se cambie el atajo) abre una
   ventana normal sin barra de título, 1226×612, con la maqueta `33-archivos-lista`:
   LUGARES, DISPOSITIVOS (barra de espacio, ⏏, «abrir» en cifrados), RED y Papelera;
   atrás/adelante/subir, migas (clic = editar, `Ctrl+L`), Buscar `/`, Compartir,
   lista/cuadrícula; pestañas; orden y ocultos a la derecha.
2. Lista con tamaño, «hace 3 d», tipo, marca M/A de git y filas alternas; cuadrícula
   con miniaturas de imágenes y vídeos. Si el contorno global de ventanas está en
   «nada», el explorador dibuja sus escuadras; si no, no (sin doble borde).
3. Panel derecho: comprimidos con el contenido sin extraer, método, cifrado,
   integridad y «Extraer aquí / Extraer en… / Probar»; imágenes con vista previa y
   datos de cámara; el resto con propiedades y Abrir, Abrir con…, Terminal aquí y
   Enviar al agente (deshabilitado hasta 5c).
4. Barra de estado: «1 de 12 elementos seleccionado · 48,2 MB», la píldora
   «COPIANDO A KINGSTON · 2/5 ▬ 38 % ×» (ámbar si pregunta por un conflicto, roja si
   falla) y el espacio libre.
5. Extraer, Red y Compartir como sus maquetas (capturas abajo).

Capturas (render de las vistas reales con datos de muestra):
[lista](screenshots/fase5d/archivos-lista.png) ·
[cuadrícula](screenshots/fase5d/archivos-cuadricula.png) ·
[extraer](screenshots/fase5d/archivos-extraer.png) ·
[red](screenshots/fase5d/archivos-red.png) ·
[compartir](screenshots/fase5d/archivos-compartir.png).

## Comprobado

- `tests/files_ui/test_views.py` (11 pruebas, en `run-all.sh`): el mock dibuja 16
  estados y revisa `files.js` (formatos, orden natural, rutas, árbol de comprimidos,
  etiquetas de operaciones), navegación, selección, búsqueda, ocultos, reglas de
  soltar, portapapeles, conflictos, expulsar, contraseñas, extracción, red y
  compartir. Los servicios reales cargan en Quickshell contra el simulador:
  `ls` en dos pasadas, un único `watch` por carpeta compartido y liberado al cerrar la
  ventana, cola con conflicto por stdin y deshacer, cancelar con SIGTERM sin bloquear
  operaciones rápidas, errores visibles, `devices --watch` solo con ventanas visibles,
  contraseñas solo por stdin, red y compartir.
- Comparación visual con `docs/design/33-archivos-*.png` sobre los renders.
- `render-mocks.sh` sigue generando los mocks anteriores además del nuevo.

## No comprobado

- **La ventana real en Hyprland**: no abrí ventanas en la sesión del usuario. Faltan
  ver el tamaño inicial, la ausencia de barra de título, el desenfoque (una región
  con alfa, regla de ventana del agente del comando) y el foco del teclado.
- **Contra el comando real**: no existe aún; todo va contra el simulador.
- Arrastrar con el ratón físico entre ventanas distintas (dentro de una ventana sí
  está cableado y probado por lógica, no con eventos reales de puntero).
- Los glifos nuevos de `Icons.qml` se vieron en los renders; ninguno sale vacío.
- `qs -p config/quickshell` completo no arranca en modo offscreen (la barra necesita
  Wayland); ya pasaba antes de este tramo. Las pruebas cargan un `shell.qml` mínimo.

## Pendiente de otros

- Agente del comando: `dragon-files` con el contrato de arriba, `tests/files/`,
  migraciones (instalación, reglas de ventana y desenfoque, `SUPER + E` → `qs ipc call
  files open`, preparación de Samba), d7 (gestor predeterminado y `FileManager1`).
- Tramo 5c: poner `Files.composerAvailable = true` y conectar
  `Files.agentRequested(paths)` al compositor con un bloque `paths`.
- Quien cierre la fase: `docs/HANDOFF.md`, y la tabla «Teclado dentro de los paneles»
  de `docs/KEYBINDS.md` con el grupo «Explorador de archivos (dentro)» que ya está
  en `services/Keybinds.qml`.

## Decisiones tomadas

- Red y compartir no tienen servicio propio: la red vive en `Devices` y compartir en
  `Files` (el plan solo nombra Files, FileOps, Devices y Archives).
- Soltar: Ctrl copia, Mayús mueve; si no, mueve en el mismo dispositivo y copia entre
  dispositivos. Soltar un comprimido sobre una carpeta pregunta Mover/Copiar/Extraer.
- Las transferencias van una tras otra; renombrar, crear carpeta, enlazar y papelera
  no esperan a una copia larga.
- «Extraer aquí» extrae directamente en una carpeta propia; solo abre el diálogo si
  hace falta contraseña o confirmar una posible bomba.
- Barra de espacio: cian, ámbar desde el 50 % (como la maqueta), rojo desde el 85 %.
- `Retroceso` sube de carpeta; `Alt+←` es atrás.

## Reproducir

```sh
python3 -m unittest discover -s tests/files_ui -v
tests/qml/render-mocks.sh /tmp/dragon-mocks      # files-*.png entre los demás
```
Nota de entorno: en esta máquina Qt manda los mensajes al journal; para ver errores
de `qml6` usa `QT_FORCE_STDERR_LOGGING=1`.
