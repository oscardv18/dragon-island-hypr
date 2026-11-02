# Compartir carpetas del explorador

Preparación **manual**, opcional, para un administrador de Arch/EndeavourOS.
La migración 073 solo despliega el comando: no ejecuta sudo, no edita `/etc`,
no arranca servicios ni abre puertos. No hagas estos pasos sin revisar lo que
ya existe en tu equipo. El explorador conserva invitados apagados por defecto.

1. Instala Samba si falta (`sudo pacman -S --needed samba`).
2. Si no existe el grupo: `sudo groupadd --system sambashare`.
3. Crea su directorio: `sudo install -d -m 1770 -o root -g sambashare /var/lib/samba/usershares`.
4. Añade tu usuario: `sudo gpasswd -a "$USER" sambashare`. Cierra sesión y vuelve a entrar.
5. Antes de editar, respalda `/etc/samba/smb.conf` con fecha. Conserva la configuración
   existente y añade bajo su **único** `[global]`:

   ```ini
   usershare path = /var/lib/samba/usershares
   usershare max shares = 100
   usershare allow guests = no
   usershare owner only = yes
   map to guest = Never
   ```

   Usa `sudo testparm -s` para validar; si falla, restaura la copia. `--guest` existe
   para administradores que lo habiliten explícitamente: con esta preparación Samba
   lo rechazará. La herramienta siempre omite invitados salvo petición explícita.
6. Da de alta la contraseña Samba de tu usuario con `sudo smbpasswd -a "$USER"`.
7. Activa el servicio solo si quieres compartir: `sudo systemctl enable --now smb`.
   Para anunciarlo por mDNS, configura Avahi como paso separado según tu red.

Solo se admiten subcarpetas propias de HOME. Se rechazan HOME entero, `/`,
rutas del sistema, `.ssh`, `.gnupg`, `.config`, llaveros y los datos del Taller,
incluso a través de enlaces. Una carpeta que contenga otras credenciales no puede
ser detectada automáticamente: revisa su contenido antes de compartirla.

Ejemplo: `dragon-files share enable --path "$HOME/Compartido" --name Documentos --rw --json`.
Desactivar: `dragon-files share disable --path "$HOME/Compartido" --json`.
No se altera Dolphin, Nautilus ni Plasma.

El cortafuegos se gestiona a mano. Con UFW y una LAN **que hayas verificado**,
por ejemplo 192.168.1.0/24: `sudo ufw allow from 192.168.1.0/24 to any app Samba`.
No uses esa subred si no es la tuya. La respuesta JSON da la plantilla de comando;
no hay una apertura automática a Internet.
