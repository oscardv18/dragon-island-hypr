# Handoff instalador: rc1

Fecha: 2026-11-04. Rama única `installer`, etiqueta `instalador-rc1`. Sin migraciones nuevas (solo scripts del repositorio y `plugins.lua`, que es un enlace al repo).
Pruebas con `hyprctl`, `hyprpm`, `notify-send`, `/sys` (`DRAGON_SYSFS`) y `systemctl` falsos; no se ejecutó nada real.

1. **Sin errores rojos en el primer login.** `config/hypr/plugins.lua` solo establece `plugin.hyprfocus.*` si `hl.plugin.hyprfocus` existe. Sin plugins: cero claves desconocidas. Al cargarse (recarga del primer arranque) se aplican.
2. **Primer arranque.** `autostart.lua` lanza `scripts/plugins-foreground.sh` mientras exista `plugins.pending` (esa marca se borra al terminar = marca de hecho; `firstrun.done` queda escrito). El script hace `hyprpm update/add/enable` y `reload`, y avisa: «Compilando plugins…», «Plugins listos» o «Plugins con error» (cualquier salida distinta de 0; queda pendiente y se reintenta). `hyprpm update` pide la contraseña, por eso sigue abriendo una ventana visible. Prerrequisitos (`cmake meson ninja cpio pkgconf git gcc hyprpm`) ya están en `packages/pacman-plugins.txt` (perfil base) y ahora `doctor.sh` los comprueba.
3. **doctor.** `bluetooth activo` se omite («no aplica») si `$DRAGON_SYSFS/class/bluetooth` (por defecto `/sys`) está vacío. El llavero solo se exige con sesión gráfica (Hyprland, `WAYLAND_DISPLAY` o `DISPLAY`). Dentro de Hyprland ya comprobaba `configerrors` vacío y plugins cargados (probado con falsos).
4. **boot.** `boot_confirm` ya no necesita gum ni «confirmar a mano»: pregunta `[s/N]` (por defecto No) en el terminal real, también en el flujo lineal; sin terminal no hace nada. Antes de preguntar genera la vista previa (`dragon-boot preview`, en `~/.local/state/dragon-island/boot-preview.png`, y dice dónde está). El motor ya crea copia de seguridad con fecha de `limine.conf` / `/etc/default/grub`; `--revert-boot` pregunta y lo deshace.

Pruebas: `tests/installer_ux/test_rc1.py` (22). `tests/boot/test_boot.py` ajustado al nuevo mensaje.

## Probar en la VM
`git pull`, `./install.sh`, reiniciar y entrar en Hyprland: sin rojos; llega «Compilando plugins…» y luego «Plugins listos» (o «con error»). Después `./doctor.sh`.

## Suite completa
`tests/run-all.sh`: **TODO EN VERDE**.
