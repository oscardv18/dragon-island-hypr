# Fase 6 · Dragon Portal — handoff (rama `feat/fase6-portal`, worktree `../dragon-6-portal`)

Un portal de escritorio propio: `dragon-portal` implementa `org.freedesktop.impl.portal.FileChooser` y abre el explorador de Dragon
como selector de archivos de Brave, Telegram y cualquier app que use el portal. Sin sudo, sin `vin.py`, **sin fusionar a `main`**.
Hechos comprobados del portal: `docs/PORTAL-API.md`.

## Lo que hay (un commit por punto)

| Punto | Archivos |
|---|---|
| Paso 0 · hechos reales | `docs/PORTAL-API.md` |
| Servicio D-Bus + canal + CLI | `dragon-core/portal_core.py` (lógica pura), `dragon-core/dragon_portal.py` (servicio Gio + CLI), `bin/dragon-portal` |
| Modo selector del explorador | `modules/files/{FilesPanel,FilesWindow,FilesState,FilesTab,PickerBar,FileRow,FileTile,Preview}.qml`, `files.js`, `services/{FilePicker,PortalRequest,Files,FilesRequest,qmldir}`, `Theme.qml` (tokens `files.picker*`), `shell.qml` (1 línea), `Keybinds.qml` + `docs/KEYBINDS.md` |
| Pruebas | `tests/portal/` (83 pruebas: 24 núcleo y CLI, 39 con el portal real, 2 de interfaz, 6 del servicio, 12 de migraciones), `tests/qml/files_picker_mock.qml`, bloque en `tests/run-all.sh` |
| Instalación | `lib/portal-tools.sh`, `migrations/100`, `101` (+`101-portal-ui-files.txt`), `102`, `scripts/portal-rollback.sh`, `config/portal/dragon.portal`, línea en `config/xdg-desktop-portal/hyprland-portals.conf`, `python-gobject` en `packages/pacman-core.txt`, `modules/core.sh` |
| Docs | `docs/TROUBLESHOOTING.md` (sección nueva), este archivo |

## Contratos

**D-Bus (hacia `xdg-desktop-portal`)**: nombre `org.freedesktop.impl.portal.desktop.dragon`, objeto `/org/freedesktop/portal/desktop`,
`OpenFile` / `SaveFile` / `SaveFiles` (v4) con `filters`, `current_filter`, `choices`, `multiple`, `directory`, `current_name`,
`current_folder`, `current_file`, `files`, `accept_label` y `modal` (este último se ignora). El objeto `org.freedesktop.impl.portal.Request`
se exporta en el `handle` mientras dura la petición (`Close()` cancela el explorador).

**Canal local (servicio ⇄ explorador)** en `$XDG_RUNTIME_DIR/dragon-portal/` (0700, comprobado: del usuario, no un enlace):
`req/<id>.json` (lo escribe el servicio) y `rep/<id>.json` (lo escribe `dragon-portal reply`), ambos 0600, creados con `O_EXCL` y renombrados
(escritura atómica). `<id>` son 32 hex generados por el servicio: es lo único que llega a una línea de comandos; **las rutas solo viajan
dentro del JSON (stdin)**. El servicio rechaza leer un archivo del canal que no sea del usuario o tenga permisos de grupo/otros.

**Servicio → Quickshell**: `qs ipc call picker open <id>` · `has <id>` (¿sigue abierto?) · `cancel <id>`. `DRAGON_PORTAL_QS` cambia el prefijo
(pruebas). **Quickshell → servicio**, solo por la CLI de siempre (la UI no ejecuta nada; lo hace el servicio `FilePicker`):

```
dragon-portal take <id>     → {"ok":true,"request":{id,kind,title,app_id,accept_label,multiple,directory,filters:[{name,patterns:[{type:glob|mime,value}]}],
                               current_filter,choices:[{id,label,options:[{id,label}],selected}],current_folder,current_name,files,…}}
dragon-portal reply <id>    ← stdin {"response":"accept"|"cancel","paths":["/abs…"],"filter":0,"choices":{"id":"opción"}}  → {"ok":true}
dragon-portal status        → {"ok":true,"gio":bool,"channel":…,"pending":[ids]}
errores                     → {"ok":false,"error":{"code","message","hint"}}   (invalid_id, unknown_request, invalid_json, invalid_reply, unsafe_channel…)
```

**Validación de la respuesta (en el servicio, no se fía de la UI)**: ruta absoluta y normalizada; `open` sin `multiple` → una; `directory` →
carpeta, si no → no carpeta; el elemento existe; `save` → exactamente una, en una carpeta existente y que no sea una carpeta; `save_files`
→ la carpeta elegida + cada nombre de `files`, único (`nombre (1).ext`) también entre los repetidos de la misma llamada. Si algo falla →
respuesta 2. Los nombres de `files` se pasan a nombre plano (`/` → `_`, `.` y `..` fuera).

**URIs**: `file://` + bytes de la ruta con `%`-escape salvo `/` y los no reservados (saltos de línea `%0A`, espacios, `#`, `?`, `%`, bytes no UTF-8);
un `-` inicial no importa en un URI. Probado que `Gio.File.new_for_uri` devuelve la ruta original.

**Varias peticiones a la vez**: cada una tiene su `<id>`, su archivo, su ventana y su respuesta (prueba con 4 a la vez y tiempos cruzados).
Máximo 16 pendientes; la 17ª va directa a GTK.

**Respaldo a GTK** (lo hace `dragon-portal`, **no** `portals.conf`; ver el riesgo 1): el servicio reenvía la llamada original al backend GTK
(`org.freedesktop.impl.portal.desktop.gtk`, sin límite de tiempo) cuando: el comando de apertura falla, el explorador no toma la petición en
`DRAGON_PORTAL_ACK` s (10), deja de contestar a `has` dos veces seguidas (cada 5 s), o hay un error interno. Un diálogo que el usuario deja abierto
**no** cuenta como fallo. `Close()` durante el respaldo llega a GTK. Si GTK también falla → respuesta 2.

## Riesgos (leer antes de fusionar)

1. **Si el servicio registrado no arranca, desaparece el selector de archivos de TODAS las apps** (probado: `xdg-desktop-portal` crea el proxy del
   backend al iniciar y, si falla, no ofrece `FileChooser`; **no** cae a `gtk` aunque `portals.conf` diga `dragon;gtk`). Por eso la migración 102 solo
   registra tras comprobar `python-gobject`, `xdg-desktop-portal-gtk` y **arrancar el servicio en un bus privado**. Marcha atrás sin sudo:
   `scripts/portal-rollback.sh --restart`. Si Python/PyGObject se rompe después (actualización del sistema), el síntoma es ese: sin diálogo.
2. **Reiniciar `xdg-desktop-portal` corta una captura de pantalla/compartición en curso** (el de Hyprland comparte el proceso). Las migraciones no lo
   hacen solas; queda como paso manual.
3. Con el servicio vivo, si Quickshell **se reinicia** a mitad de un diálogo, la ventana desaparece sin responder: el servicio lo nota en unos 10–15 s
   (`has` falla dos veces, cada 5 s) y cae a GTK, así que el usuario ve aparecer el diálogo de GTK de repente.
4. `choices` (listas desplegables del diálogo) se muestran como botones junto a Cancelar y se devuelven; `writable` no se devuelve; `modal` y
   `parent_window` se ignoran (la ventana es flotante y centrada por la regla `dragon-files-window`).
5. El título de la ventana empieza por «Archivos · » para heredar la regla de ventana del explorador; cualquier otra regla que busque ese texto lo verá.
6. Los archivos de la UI que toca esta fase también los tocan otras ramas del explorador (`FilesPanel`, `FileRow`, `Preview`, `Theme.qml`, `shell.qml`):
   espera conflictos al fusionar.

## Pasos manuales (nada requiere sudo)

1. Fusionar la rama a `main` (lo decides tú) y `./update.sh`: ejecuta 100 (herramientas), 101 (solo instalaciones por copia) y 102 (registro con prueba).
   Si `update.sh` avisa de `python-gobject`: `sudo pacman -S python-gobject` (ya está instalado en esta máquina: 3.58.1).
2. Reiniciar Quickshell para cargar `FilePicker` (`qs ipc call picker has 00000000000000000000000000000000` debe contestar `false`).
3. **`systemctl --user restart xdg-desktop-portal`** (o cerrar sesión). Hasta entonces los diálogos siguen siendo los de GTK.
4. Probar: en Brave, `Ctrl+O`; en Telegram, adjuntar. Esperado: ventana «Archivos · <título>» con botones Abrir/Cancelar.
5. Desactivar: `scripts/portal-rollback.sh --restart`.
6. En esta máquina `~/.config/xdg-desktop-portal/` tiene `hyprland-portals.conf` (enlace al repo), no `portals.conf`: con `XDG_CURRENT_DESKTOP=Hyprland`
   el archivo específico gana y `portals.conf` se ignora. La línea `FileChooser=dragon;gtk` está en el del repo.

## Verificado

- `tests/run-all.sh --no-qml`: TODO EN VERDE (shellcheck de todo, Lua, migraciones en dry-run, idempotencia, install --dry-run, y el bloque nuevo).
- `tests/portal/` (`python3 -m unittest discover -s tests/portal -t tests/portal`, ~45 s):
  - **`test_portal.py`**: `xdg-desktop-portal` real (1.22.1) en un bus propio (`dbus-run-session`, `XDG_DESKTOP_PORTAL_DIR`), el `dragon-portal` real activado por el bus,
    un GTK falso y un explorador simulado; llamadas a la interfaz **pública** `org.freedesktop.portal.FileChooser`. Una prueba por opción:
    OpenFile (básico, `multiple`, `multiple=false` con dos, `directory`, archivo↔carpeta, `filters`+`current_filter`, filtro actual con lista vacía,
    `current_folder`, `accept_label`/`modal`, `choices`, cancelar, nombres raros → URIs, ruta relativa/inexistente, `Close`, título largo con salto de línea),
    SaveFile (nombre propuesto, carpeta, exactamente una, filtros, `current_file`, `choices`, cancelar, destino inválido, nombres raros, nombre con `../`),
    SaveFiles (orden, nombres repetidos/existentes, nombres raros, `choices`, cancelar, destino no carpeta), concurrencia y respaldo a GTK (sin tomar la petición,
    apertura que falla, explorador que muere, diálogo largo sin respaldo, Save y SaveFiles reenviados, `Close` durante el respaldo).
  - `test_core.py` (núcleo y CLI: URIs, opciones, permisos del canal, enlaces, ids, errores JSON), `test_picker_ui.py` (panel real en `qml6` offscreen con 6 capturas
    + reglas de cada tipo de diálogo; ayudantes de filtros con `node`), `test_picker_service.py` (Quickshell real + `qs ipc` + CLI real),
    `test_migrations.py` (100/101/102 y rollback: dry-run con `1` y `true`, backup, idempotencia, enlaces, guarda de seguridad).
- **Prueba real en tu sesión de Hyprland** (2026-11-02): bus privado (`dbus-run-session`) con `xdg-desktop-portal` real + `dragon-portal` real + el explorador nuevo en un
  Quickshell mínimo (`qs -p`) **sobre tu pantalla** (no toqué tu `xdg-desktop-portal`, tu Quickshell ni `~/.config`/`~/.local`; HOME e `XDG_RUNTIME_DIR` temporales,
  el compositor real). Llamadas a `org.freedesktop.portal.FileChooser` por D-Bus; resultados:
  - `OpenFile` con `multiple`, filtro «Imágenes» (`image/*`, `*.png`) y `current_folder` → ventana «Archivos · Adjuntar a Telegram» (1226×612 a 70,96) solo con carpetas y PNG, «Abrir»
    desactivado sin selección; al elegir dos: `response 0`, `uris ['file:///…/foto1.png','file:///…/foto2.png']`, `current_filter` devuelto.
  - `SaveFile` con `current_name` → ventana con el campo «informe.pdf» y botón «Guardar»; al escribir «reporte final.pdf»: `file:///…/reporte%20final.pdf`.
  - `OpenFile` `directory` → «Elegir»; cancelar → `response 1`. `SaveFiles` → «Guardar aquí»; cancelar → `response 1`.
  - Sin Quickshell: `OpenFile` → `file:///gtk/fallback` (GTK falso) tras el aviso «usando el portal de GTK (no se pudo abrir el explorador)».
  - `gdbus call` solo devuelve la ruta de la petición: `Response` es unicast y se pierde al salir `gdbus` (documentado en PORTAL-API.md §4); se escuchó con un cliente Gio.
  - Capturas guardadas **solo en local** (`/tmp/dpt1/real/out/*.png`), no están en el repo. Lo que se vio: título de la app arriba, migas de la carpeta, lista filtrada,
    barra inferior con resumen («Elige uno o varios archivos», «Se guardará como «informe.pdf»»), desplegable de filtro, Cancelar `Esc` y botón principal cian.

## No verificado

- Un diálogo real de **Brave o Telegram** (no se reinició el portal de tu sesión; la prueba fue por D-Bus con el contrato de la interfaz pública). Para ti: pasos 1–4.
- La recarga del `.service` nuevo en el `dbus-broker` de tu sesión (en el bus de pruebas fue `dbus-daemon`): si `busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ListActivatableNames`
  no lista `…desktop.dragon` tras la migración, hace falta `ReloadConfig` o volver a iniciar sesión.
- El respaldo con el **GTK real** (las pruebas usan un GTK falso con la misma interfaz): `xdg-desktop-portal-gtk` abriría su ventana.
- Aceptar con el ratón/teclado en la ventana real (se aceptó por IPC de prueba sobre el panel real; los clics, el foco del campo de nombre y `Enter` solo se probaron en el render offscreen y por funciones del panel).
- `choices` con apps reales; varios monitores; `modal` / `parent_window`.
