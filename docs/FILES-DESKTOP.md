# Abrir carpetas con Dragon

La migración 074 instala `dragon-files.desktop` y propone asociar `inode/directory`.
Con `ASSUME_YES` acepta esa propuesta; con `DRY_RUN` solo imprime las acciones.
La asociación XDG afecta a todas las sesiones del usuario, incluida Plasma; no se
elimina ni se modifica Dolphin ni Nautilus. Para activarla después:

```sh
dragon-files --set-default
```

Se guarda la asociación anterior una sola vez en
`$XDG_STATE_HOME/dragon-island/files/default.json` (por defecto `~/.local/state`).
Puedes volver a ella con `dragon-files --restore-default`. Si no había asociación
explícita, el comando explica cómo elegir una, por ejemplo:
`xdg-mime default org.kde.dolphin.desktop inode/directory`.

`dragon-files --browse [ruta…]` abre ventanas por IPC `files open`; el `.desktop`
no usa `xdg-open`, por lo que no hay recursión. Las URI locales `file:///` se
convierten a rutas; los recursos remotos se conectan primero en Red.

## FileManager1 opcional

`dragon-files --filemanager1` implementa ShowFolders, ShowItems y
ShowItemProperties con PyGObject (`python-gobject`). No sustituye a otro propietario
de `org.freedesktop.FileManager1`. Si PyGObject falta termina con código 10 y una
indicación; no necesita instalar nada para el resto del explorador. No se registra
activación D-Bus ni autoinicio: arráncalo explícitamente antes de «Mostrar en carpeta».
Se cierra tras 30 s sin peticiones. ShowItems abre la carpeta contenedora y
ShowItemProperties abre la carpeta contenedora; selección y panel de propiedades
por IPC quedan pendientes porque el contrato `files` solo expone `open(ruta)`.

Para detenerlo, usa Ctrl+C en la terminal donde lo arrancaste. Si Dolphin/Nautilus
ya poseen el nombre, debes cerrar su servicio por sus mecanismos normales antes de
arrancar el opcional. El instalador no mata ningún gestor de archivos.
