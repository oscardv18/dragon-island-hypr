# Portal de escritorio de Dragon — hechos comprobados (Paso 0, fase 6)

Todo lo de aquí se probó en esta máquina el 2026-11-02 (EndeavourOS, Hyprland 0.56.2, `xdg-desktop-portal 1.22.1`,
`xdg-desktop-portal-gtk 1.15.3`, `xdg-desktop-portal-hyprland 1.4.1`, Python 3.14.8), siempre con un bus de sesión propio
(`dbus-run-session`) y `HOME`/`XDG_*` temporales: la sesión real no se tocó. Lo marcado **(no probado)** es lectura de
documentación, no de ejecución.

## 1. ¿Dónde busca `xdg-desktop-portal` los archivos `.portal`?

Con `xdg-desktop-portal -r -v` (modo verboso) se ve el orden de búsqueda:

```
XDP: load portals from $XDG_DATA_HOME/xdg-desktop-portal/portals      ← carpeta del usuario, primera
XDP: loading …/portals/dragon.portal
XDP: portal implementation supports org.freedesktop.impl.portal.FileChooser
XDP: load portals from /usr/local/share/xdg-desktop-portal/portals    ← cada $XDG_DATA_DIRS
XDP: load portals from /usr/share/xdg-desktop-portal/portals
```

**Conclusión: sí se puede registrar en la carpeta de usuario, sin sudo:**
`~/.local/share/xdg-desktop-portal/portals/dragon.portal`.

- `XDG_DESKTOP_PORTAL_DIR` (variable de entorno, aparece en el binario) **sustituye** la carpeta de `.portal`; sirve para
  las pruebas, que así no activan ni el backend GTK ni el de Hyprland.
- Los `.portal` se leen **al arrancar** `xdg-desktop-portal`: tras instalar el nuestro hace falta
  `systemctl --user restart xdg-desktop-portal` (sin sudo) o cerrar sesión. Ese reinicio corta una captura de pantalla en curso,
  por eso las migraciones **no** lo hacen solas (ver el handoff).
- Contenido del archivo (formato igual que `/usr/share/xdg-desktop-portal/portals/gtk.portal`):

```ini
[portal]
DBusName=org.freedesktop.impl.portal.desktop.dragon
Interfaces=org.freedesktop.impl.portal.FileChooser;
UseIn=Hyprland
```

### Qué backend elige para cada interfaz

El archivo del usuario es `~/.config/xdg-desktop-portal/hyprland-portals.conf` (enlace a
`config/xdg-desktop-portal/hyprland-portals.conf` del repo), **no** `portals.conf`: con `XDG_CURRENT_DESKTOP=Hyprland`
`xdg-desktop-portal` busca `hyprland-portals.conf` y, si existe, ya no lee `portals.conf` (`portals.conf(5)`:
«If a desktop-environment-specific configuration file is not found, a non-desktop-specific file … will be read»).
Hoy dice:

```ini
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
```

Hay que añadir `org.freedesktop.impl.portal.FileChooser=dragon;gtk`. Orden de búsqueda de los `*portals.conf`:
`$XDG_CONFIG_HOME`, `$XDG_CONFIG_DIRS`, `/etc`, `$XDG_DATA_HOME`, `$XDG_DATA_DIRS`, `/usr/share`.

> **Importante:** la lista `dragon;gtk` solo decide **qué backend se carga**. Si `dragon` está instalado, `xdg-desktop-portal`
> **no** reintenta con `gtk` cuando una llamada falla en tiempo de ejecución. El respaldo «si el explorador no responde o el servicio
> falla, cae al portal de GTK» tiene que hacerlo el propio `dragon-portal` **llamando él mismo** a
> `org.freedesktop.impl.portal.desktop.gtk` con los mismos argumentos (diseño en el handoff). Si `dragon-portal` ni siquiera
> arranca, la aplicación recibe «respuesta 2» (error) en vez de una ventana blanca de GTK: es el riesgo principal.

## 2. Activación por D-Bus

`$XDG_DATA_HOME/dbus-1/services/` es un directorio de servicios del bus de sesión (`<standard_session_servicedirs/>`).
Probado con `dbus-daemon` (el de `dbus-run-session`): al llamar a `OpenFile`, el bus arrancó solo el servicio

```
Activating service name='org.freedesktop.impl.portal.desktop.dragon' requested by ':1.0' (… comm="/usr/lib/xdg-desktop-portal -r")
Successfully activated service 'org.freedesktop.impl.portal.desktop.dragon'
```

con este `~/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.dragon.service`:

```ini
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.dragon
Exec=/ruta/absoluta/a/dragon-portal serve
```

- `Exec` debe ser una **ruta absoluta**; el bus no expande `~` ni `$HOME`, así que la migración la escribe con el `HOME` real.
- En la sesión real el bus es `dbus-broker` (`dbus-broker-launch --scope user`), no `dbus-daemon`. Lee los mismos
  directorios de servicios; la recarga del archivo nuevo **(no probado)** en un `dbus-broker` ya arrancado se comprueba al instalar
  (`busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ListActivatableNames` debe listar el nombre; si no,
  `ReloadConfig` o volver a iniciar sesión).
- Sin `SystemdService=` el proceso lo lanza el propio bus (hereda su entorno, que puede no tener `WAYLAND_DISPLAY`): el servicio
  **no** necesita Wayland (solo habla con Quickshell por `qs ipc`, que usa `$XDG_RUNTIME_DIR`).
- Un nombre de bus con la ruta de socket de Wayland muy larga (`>108` bytes) rompe `xdg-desktop-portal-hyprland` en las pruebas:
  los tests usan `XDG_RUNTIME_DIR` cortos (`/tmp/dp…`).

### Si el backend no arranca, desaparece el selector de archivos (probado)

`xdg-desktop-portal` crea el proxy de cada backend **al arrancar** (`StartServiceByName`). Con un `dragon.service` que sale con error
(`Exec=/bin/false`) el registro es este y `OpenFile` ya no existe para ninguna aplicación:

```
xdg-desktop-portal-WARNING: Failed to create file chooser proxy: Error calling StartServiceByName for org.freedesktop.impl.portal.desktop.dragon: Process … exited with status 1
$ gdbus call … org.freedesktop.portal.FileChooser.OpenFile …
Error: GDBus.Error:org.freedesktop.DBus.Error.UnknownMethod: No such interface “org.freedesktop.portal.FileChooser”
```

**No hay respaldo a `gtk` en este caso** aunque `portals.conf` diga `dragon;gtk`. Consecuencias para el diseño:

- la migración **solo** instala el `.portal` y la preferencia si `python3 -c 'import gi'` funciona y `dragon-portal serve` arranca de verdad en una
  prueba (ver el handoff);
- `dragon-portal serve` importa lo mínimo, no toca Wayland ni Quickshell al arrancar y sale con 10 (no con una traza) si falta PyGObject;
- marcha atrás sin sudo: quitar `FileChooser=` de `hyprland-portals.conf` (o el `.portal` de usuario) y `systemctl --user restart xdg-desktop-portal`;
  `scripts/portal-rollback.sh` lo hace.

## 3. Biblioteca D-Bus para Python

| Biblioteca | Instalada | Paquete | Uso |
|---|---|---|---|
| **Gio de PyGObject** | sí, 3.58.1 | `python-gobject` | **elegida**: ya la usa `files_filemanager1.py`; trae `GLib.MainLoop`, `bus_own_name`, `register_object` y `Gio.Subprocess` |
| `jeepney` | sí, 0.9.0 | `python-jeepney` | descartada: sin bucle de eventos propio para servidor |
| `dbus-python` | sí, 1.5.1 | `python-dbus` | descartada: en mantenimiento, sin ventaja |
| `dasbus` | **no** | — | no se instala |

No hace falta instalar nada. `python-gobject` hoy llega como dependencia de otros paquetes; el repo lo declara de forma explícita en
`packages/` para instalaciones nuevas (la migración no instala paquetes: eso exigiría sudo).

Como `dragon-files` se lanza con `python3 -S` (sin `site-packages`), `bin/dragon-portal` lanza el servicio **sin** `-S`, igual que
`dragon-files --filemanager1`.

## 4. Probar sin interfaz: `gdbus call` a `org.freedesktop.portal.FileChooser`

`OpenFile` de la interfaz pública: `(parent_window s, title s, options a{sv})` → `o` (la ruta de la petición); el resultado llega después en
la señal `org.freedesktop.portal.Request.Response(u response, a{sv} results)` sobre esa ruta. Prueba real:

```console
$ gdbus call --session --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.FileChooser.OpenFile "" "Titulo" "{'multiple': <true>}"
(objectpath '/org/freedesktop/portal/desktop/request/1_9/t',)
# el backend recibió:
OpenFile('/org/freedesktop/portal/desktop/request/1_9/t', '', '', 'Titulo', {'multiple': True})
```

Para ver el `Response` hay que suscribirse **antes** (`gdbus monitor --session --dest org.freedesktop.portal.Desktop`) o usar un cliente
que lo espere; las pruebas de `tests/portal/` lo hacen con Gio (`signal_subscribe`). La ruta de la petición lleva el nombre único del
llamante (`1_9`) y el `handle_token` (`t`, o el que se pase en `options`).

Opciones útiles para `gdbus`: `a{sv}` se escribe `"{'directory': <true>, 'filters': <[('Imágenes', [(1, 'image/*')])]>}"`.
`current_folder` es `ay` terminado en NUL: `<b'/tmp\x00'>`.

## 5. Contrato de `org.freedesktop.impl.portal.FileChooser` (v4)

Fuente: `/usr/share/dbus-1/interfaces/org.freedesktop.impl.portal.FileChooser.xml`. Los tres métodos reciben
`(handle o, app_id s, parent_window s, title s, options a{sv})` y devuelven `(response u, results a{sv})`:
`response` 0 = aceptado, 1 = cancelado por el usuario, 2 = otro error.

| Método | Opciones | Resultados |
|---|---|---|
| `OpenFile` | `accept_label s`, `modal b`, `multiple b`, `directory b`, `filters a(sa(us))`, `current_filter (sa(us))`, `choices a(ssa(ss)s)`, `current_folder ay` | `uris as` (solo `file://`), `choices a(ss)`, `current_filter`, `writable b` |
| `SaveFile` | `accept_label`, `modal`, `filters`, `current_filter`, `choices`, `current_name s`, `current_folder ay`, `current_file ay` | `uris as` (**exactamente uno**), `choices`, `current_filter` |
| `SaveFiles` | `accept_label`, `modal`, `choices`, `current_folder ay`, `files aay` | `uris as` (uno por nombre, mismo orden), `choices` |

- Un filtro es `(nombre, [(0, glob) | (1, tipo-MIME)])`; los globs distinguen mayúsculas; los tipos MIME admiten `image/*`.
- `handle` es la ruta donde el backend debe exportar `org.freedesktop.impl.portal.Request` (método `Close()`); `xdg-desktop-portal` la llama
  si la aplicación cancela. El servicio exporta ese objeto mientras dure la petición.
- Los URIs que no se puedan normalizar a `file://` se descartan.

## 6. Qué decide el diseño a partir de esto

1. `.portal` y servicio de activación en la carpeta de usuario: **no hace falta sudo**.
2. Único paso manual (sin sudo, pero con efecto en la sesión): `systemctl --user restart xdg-desktop-portal`, o cerrar sesión.
3. PyGObject (`Gio`), ya instalado.
4. Respaldo a GTK dentro de `dragon-portal`, no en `portals.conf`.
5. Pruebas con `XDG_DESKTOP_PORTAL_DIR` + `dbus-run-session` + un backend GTK falso.
