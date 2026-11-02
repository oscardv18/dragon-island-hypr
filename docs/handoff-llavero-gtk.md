# Handoff llavero y selector GTK

Rama `feat/llavero-portal-gtk`, worktree `/home/oddv/Devs/dragon-island-llavero-gtk`, desde `main` (`053d774`).
Sin sudo, vin.py, push ni fusión. El worktree original tenía cambios en listas de paquetes; quedaron intactos.

## A — Llavero

`login.Locked = false`. SDDM ya integra GNOME Keyring en auth/password/session;
`kwallet-pam` también está instalado y habilitado por PAM, sin prueba de que cause
el aviso. Claude Desktop 4.4212.0-1 viene del paquete `claude-desktop`, usa un wrapper
que admite flags y se lanzaba sin selección de almacén. Su código usa safeStorage
y rechaza `basic_text`: el registro `main.log` del 2026-11-02 10:30:03 confirma `backend=basic_text`.
Se extrajeron solo fecha y enum: la causa es la selección automática bajo Hyprland,
no un llavero bloqueado. No se probaron credenciales.
Migración 120: fuerza libsecret en su archivo de flags con backup, idempotencia y DRY_RUN.
`docs/KEYRING.md` explica la evidencia, las líneas PAM ya presentes y la retirada
manual opcional de kwallet-pam. No se reinicia Claude: falta confirmar el aviso tras
cerrar y abrir la app desde su menú. Prueba automatizada: HOME/XDG temporales,
conservación de opciones/comentarios, reemplazo de almacén, backup, repetición y DRY_RUN.

## B — Selector GTK provisional

Migración 121: conserva los ajustes y CSS del usuario, respalda con `backup_copy`,
desvincula directorios de configuración antes de escribir para no modificar el repo,
configura `prefer-dark` en dconf y `adw-gtk3-dark` en GTK3/GTK4. El valor anterior de
cada clave dconf queda en `~/.local/state/dragon-island/gtk-before-*`.
La importación CSS queda después del CSS de KDE para que no se imponga `colors.css`.
`dragon-palette apply/reset` genera `gtk.css` desde la misma paleta aplicada; los
colores del selector cambian en su siguiente apertura, sin procesos residentes.
El reset de GTK usa Dragon; el reset de terminales mantiene su comportamiento anterior.
La migración actualiza las librerías/plantillas copiadas y reinicia únicamente
`xdg-desktop-portal-gtk.service` cuando hay cambios. Respeta DRY_RUN/ASSUME_YES.
Las instalaciones nuevas también ejecutan el helper en el módulo theme.

`adw-gtk-theme 6.5-1` existe en extra pero no estaba instalado. Añadido a base,
paquetes de theme, comando previo y tabla generada de `pre-instalation.md`.
Para verificar sin sudo se descargó el paquete del mirror oficial, se comprobó
su firma con `pacman-key --verify` y se extrajo **solo** `adw-gtk3-dark` a
`~/.local/share/themes`. No se instaló el paquete en pacman ni se cambiaron archivos
de `/usr`. Para gestionarlo con pacman, ejecuta a mano `sudo pacman -S --needed adw-gtk-theme`;
la copia local puede mantenerse o retirarse después si no has personalizado el tema.
Estos ajustes GTK/dconf son de usuario y también pueden verse en Plasma.

**Verificación visual real:** `zenity --file-selection` sobre un directorio vacío
de `/tmp`; Hyprland confirmó `class=xdg-desktop-portal-gtk`. Captura recortada a esa
ventana: `/tmp/dragon-gtk-verification/chooser.png` (solo local, sin añadir al repo).
Vista inspeccionada: fondo casi negro de la paleta aplicada, texto lavanda,
controles violeta y botón OK violeta deshabilitado al no seleccionar ningún archivo.
Sin avisos CSS en el journal del portal. Se cerró únicamente el Zenity de prueba;
no se cerraron ventanas del usuario. Servicio GTK activo tras su reinicio.
No se validó iniciar sesión de nuevo ni abrir el selector desde Claude.

**Pruebas:** cuatro casos HOME/XDG temporales, incluidos backup, doble ejecución,
DRY_RUN, directorio enlazado, conservación de CSS/INI, apply/reset dinámico.
34 pruebas existentes de paleta pasan. `tests/run-all.sh` se ejecutó **una sola vez**:
los demás bloques pasaron y hubo tres fallos. Uno fue la comparación del estado de
Git, contaminada por mis ediciones concurrentes; `tests/migrations-dry-run.sh`
se repitió con el árbol estable y pasó completo (75 migraciones, DRY_RUN=1/true,
tres escenarios del actualizador y Git intacto). Los otros dos detectaron que una
lectura de gsettings puede crear caché dconf incluso en dry-run y que el helper
reordenaba claves de un INI ya correcto, convirtiendo un enlace en archivo.
Corregido: no se ejecuta gsettings durante simulación y se conservan las líneas
que ya tienen el valor correcto. Repetidos **solo** los bloques afectados:
`tests/idempotency.sh`, `python3 tests/install-dry-run.py` y cuatro pruebas nuevas,
todos OK. Shellcheck de los scripts modificados y `git diff --check`, OK.
`hyprctl configerrors` vacío. Segunda ejecución real de 121 conserva el PID/inicio
del portal (sin reinicios innecesarios).

La comprobación deja `~/.local/bin/dragon-palette` enlazado a este worktree, con
el enlace anterior respaldado por la migración. Conserva el worktree mientras
uses esta revisión instalada; no hubo push ni fusión a main.

## Seguimiento — Telegram seguía mostrando un diálogo blanco

La captura posterior del usuario corresponde al `QFileDialog` interno de Qt,
no al portal GTK comprobado antes. Telegram 7.3.3-1 es Qt6/Wayland; su proceso
hereda `QT_QPA_PLATFORMTHEME=hyprqt6engine`, pero sus mapas de bibliotecas no
incluyen ningún plugin platformtheme. Por tanto, comprobar Zenity no bastaba
para asegurar el selector de Telegram. No se atribuye la falta de carga a un
fallo concreto de hyprqt6engine: `ldd -r` no mostró símbolos sin resolver.
El caso de usar `xdgdesktopportal` está recogido en el
[repositorio de Telegram](https://github.com/telegramdesktop/tdesktop/issues/30692).

Migración **122**, incluida en el commit de B: instala una copia de
`~/.local/bin/dragon-telegram` y un override de
`$XDG_DATA_HOME/applications/org.telegram.desktop.desktop`. Conserva nombre,
icono, asociaciones y acción de salir; usa `DBusActivatable=false` para que el
lanzador no eluda el wrapper por la activación D-Bus del paquete. El wrapper
selecciona `QT_QPA_PLATFORMTHEME=xdgdesktopportal` **solo** en Hyprland; las
otras sesiones heredan su integración normal. No modifica la configuración
Qt general, los datos de Telegram ni su proceso abierto. El módulo theme
aplica también este ajuste si Telegram ya está instalado. Respaldos con
`backup_copy`, DRY_RUN sin escrituras y segunda aplicación sin refrescar de
nuevo el índice de aplicaciones.

**Verificado:** aplicación Qt6 de prueba con `QFileDialog::getOpenFileName`,
una vez iniciada su conexión asíncrona al portal; ventana real con clase
`xdg-desktop-portal-gtk`, fondo oscuro y controles lavanda. Captura solo local:
`/tmp/dragon-gtk-verification/qt-portal.png`. Se cerró solo la prueba propia.
Cinco pruebas HOME/XDG temporales pasan, incluido lanzamiento en Hyprland,
KDE:Hyprland y KDE, argumentos intactos, backup, DRY_RUN=1/true y doble aplicación.
Shellcheck, idempotencia del instalador y dry-run completo del instalador pasan.
No se repitió toda la suite, respetando la única ejecución solicitada.

**Pendiente en Telegram:** salir desde su menú (no solo cerrar la ventana a
la bandeja), volver a abrirlo **desde el lanzador** y probar Adjuntar. Ejecutar
`Telegram` directamente en una terminal no usa el wrapper del `.desktop`.
No se reinició ni cerró Telegram del usuario; el selector dentro de esa app
queda pendiente de esa comprobación tras el reinicio voluntario.

## Resumen (tres líneas)

A: llavero abierto; backend basic_text de Electron confirmado, flags libsecret preparados.
B: selector GTK oscuro y puente Qt de Telegram preparados; dragon-palette, migraciones 121/122.
Manual: reiniciar Claude y Telegram desde sus menús para comprobarlos; PAM/KWallet documentados, sin sudo ejecutado.
