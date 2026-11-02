# Claude y el Secret Service

Diagnóstico local, 2026-11-02 (solo lectura): `login.Locked` devuelve `b false`;
`org.freedesktop.secrets` pertenece a gnome-keyring. No se leyó ni copió ningún llavero.
El portal está configurado en `hyprland-portals.conf`, no en `portals.conf`.

`pacman -Qo /usr/bin/claude-desktop /usr/share/applications/com.anthropic.Claude.desktop`
identifica `claude-desktop 4.4212.0-1`. Tanto la entrada del paquete como la generada en
`~/.local/share/applications` ejecutan `claude-desktop`, también sus acciones.
El wrapper lee `$XDG_CONFIG_HOME/claude-desktop-flags.conf` (por defecto `~/.config`).
No había archivo de flags ni opción `--password-store` en el proceso principal.
El código instalado de Claude consulta `safeStorage` y solo considera válidos
`gnome_libsecret`, KWallet y el llavero de macOS; rechaza `basic_text`.

La causa confirmada es la selección automática de almacén de
Electron en `XDG_CURRENT_DESKTOP=Hyprland`; no es un `login` bloqueado ni la ausencia
de Secret Service. El registro `~/.config/Claude/logs/main.log` del 2026-11-02 a las 10:30:03
confirma `backend=basic_text`. Se extrajeron exclusivamente ese enum y la fecha,
sin mostrar líneas del log, inyectar código ni acceder a credenciales. La migración 120 fuerza
`--password-store=gnome-libsecret` en el archivo que admite el wrapper, preservando
las demás opciones y comentarios y respaldando el archivo anterior con `backup_copy`.
No modifica el `.desktop` generado, que Claude puede regenerar.

Electron documenta la selección por escritorio o por `--password-store`:
[API safeStorage](https://github.com/electron/electron/blob/main/docs/api/safe-storage.md),
[almacenamiento Linux de Chromium](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/password_storage.md).
El portal Secret no selecciona el backend de `safeStorage`.

Para comprobar el arreglo, cierra Claude desde su menú cuando hayas guardado tu trabajo
y vuelve a abrirlo normalmente. Las instancias abiertas conservan sus argumentos;
no se cerraron ni reiniciaron aquí. Confirma que desaparezca el aviso del gestor.
No borres ni recrees llaveros ni archivos de credenciales para probarlo.

## Pasos manuales con privilegios (no ejecutados)

En esta máquina `/etc/pam.d/sddm` **ya** contiene las tres líneas GNOME siguientes,
después de los respectivos `include system-login` (el prefijo `-` indica módulo opcional):

```pam
-auth       optional    pam_gnome_keyring.so
-password   optional    pam_gnome_keyring.so    use_authtok
-session    optional    pam_gnome_keyring.so    auto_start
```

No necesitas duplicarlas. Si faltan en otra instalación, haz primero un respaldo:
`sudo cp -an /etc/pam.d/sddm /etc/pam.d/sddm.bak-dragon`, edita con
`sudoedit /etc/pam.d/sddm` y añádelas en sus secciones. El desbloqueo requiere inicio
con contraseña y que la contraseña de `login` coincida; el autologin no entrega
contraseña a PAM. Ajusta la contraseña desde Seahorse si fuera necesario, sin exportar secretos.

También están instalados `kwallet-pam 6.8.2-1` y sus líneas `auth` y
`session … auto_start` en SDDM. Eso habilita un segundo gestor al iniciar sesión,
pero no prueba que esté causando el aviso: GNOME ya tiene Secret Service y `login`
está abierto. Si deseas retirar esa integración de PAM en ambas sesiones, revisa
antes qué apps Plasma necesitan KWallet y sus dependencias con `pacman -Qi kwallet-pam`;
puedes ejecutar manualmente `sudo pacman -R kwallet-pam` si pacman permite retirarlo.
No uses `-Rdd` ni retires paquetes de Plasma. Revisa después el archivo de SDDM;
comenta sus dos líneas `pam_kwallet5.so` si permanecen, con el respaldo anterior.
No desinstales KWallet ni borres sus llaveros: algunas apps de Plasma pueden usarlos.
Prueba el próximo inicio de sesión manteniendo una vía de acceso alternativa.
