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

## FileManager1

`dragon-files --filemanager1` implementa ShowFolders, ShowItems y
ShowItemProperties con PyGObject (`python-gobject`, paquete del núcleo). Es lo que usan
«Mostrar en carpeta» y «Abrir carpeta» de Brave, Chromium, Firefox o Telegram: no
pasan por el portal ni por la asociación `inode/directory`, sino por el servicio
`org.freedesktop.FileManager1`, que sin esto atendía Dolphin.

El instalador (`files_tools_setup`) y la migración 195 registran su activación D-Bus en
`~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service`, que gana a los de
`/usr/share` (Dolphin, Nautilus): el servicio arranca al pedirlo y se cierra tras 30 s sin
peticiones. Vale para toda la sesión de usuario, también en Plasma. Un archivo de servicio
que no es de Dragon se respeta. No sustituye a un propietario que ya tiene el nombre: si
Dolphin quedó abierto (`dolphin --daemon`), sigue respondiendo hasta que se cierra. El
instalador no mata ningún gestor de archivos. Sin PyGObject termina con código 10 y la
migración se reintenta.

ShowItems y ShowItemProperties abren la carpeta contenedora; selección y panel de
propiedades por IPC quedan pendientes porque el contrato `files` solo expone `open(ruta)`.

Para volver al gestor del sistema: borra ese archivo `.service`.
