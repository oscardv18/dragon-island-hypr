# Problemas conocidos

Los fallos que ya tuvimos, con su causa y cómo resolverlos. Para saber en qué estado está todo: `./doctor.sh`
(y `./doctor.sh --pre` para los requisitos previos de [`pre-instalation.md`](../pre-instalation.md)).

## hyprpm falla («no se puede escribir en /var/cache/hyprpm» o se queda esperando)

`hyprpm update` instala las cabeceras de Hyprland en `/var/cache/hyprpm/<usuario>` con un ayudante de root y **pide la contraseña**:
falla si se lanza sin terminal (autostart, `gum spin`, otro script). Ejecútalo siempre en una terminal visible dentro de Hyprland:

```sh
scripts/plugins-foreground.sh
```

El instalador lo hace así (módulo `plugins`); `autostart.lua` solo ejecuta `hyprpm reload -n && hyprctl reload`. Tras **cada** actualización de Hyprland
hay que repetir `hyprpm update` (`./update.sh` lo hace cuando cambia la versión). Si Hyprland falla justo después de actualizar:
desde un TTY, `hyprpm disable hyprbars hyprfocus hyprglass`, y luego `hyprpm update`.

## Plugins: «unknown config key plugin:hyprbars:…» en `hyprctl configerrors`

Hasta que `hyprpm reload` carga los plugins, todas las claves `plugin:*` son desconocidas. Por eso `config/hypr/plugins.lua` y `glass.lua` están
**protegidos** (`if loaded("hyprbars") then …`), y tras cargar los plugins se hace `hyprctl reload`. Si ves el error: comprueba `hyprctl plugin list`;
si el plugin no aparece, `scripts/plugins-foreground.sh`; si aparece, `hyprctl reload`.

## `misc.vfr` o `decoration.blur.variant` dan error de configuración

Hyprland 0.56.2 estable no tiene `misc.vfr` (pasó a `debug.vfr`, activo por defecto) ni `decoration.blur.variant` / `blur.glass.*` (solo en la versión git).
Quita esas claves; para cristal real se usa el plugin hyprglass. Toda clave nueva se comprueba contra `.agents/skills/dragon-island/resources/hyprland-0.56.2-example.lua`.

## Proton VPN no recuerda la sesión / Brave pide la contraseña del llavero

Un único llavero: **gnome-keyring**. Comprueba:

```sh
busctl --user status org.freedesktop.secrets | grep -E '^(PID|Comm)='   # debe ser gnome-keyring-d
./doctor.sh                                                             # «Llavero login desbloqueado»
```

- El llavero `login` debe tener **la misma contraseña que tu usuario** (Seahorse → clic derecho → *Cambiar contraseña*).
- Sin inicio de sesión automático (sin contraseña escrita, PAM no puede abrir el llavero).
- KWallet no debe ofrecer el servicio de secretos: `kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false` y cierra sesión.
- Brave: exporta tus contraseñas **antes** del primer arranque con `--password-store=gnome-libsecret` (README → Llavero).
- Falta `pam_gnome_keyring` en `/etc/pam.d/sddm`: `./install.sh --modules keyring` (muestra el diff y hace copia `.bak-dragon`).

## El login / sudo escribe en otra distribución de teclado

La contraseña se teclea con la distribución activa. El tema de login fuerza el índice 0 (`us`) y la sesión de Hyprland tiene `us,latam` con `us` primera.
Si el login arranca en otra: `sudo localectl set-x11-keymap us,latam` (o `./install.sh --modules keyboard`). En la TTY: `sudo localectl set-keymap us`.
Si ya iniciaste sesión, `Alt+Shift` o `SUPER + ALT + Space` cambian de distribución; la cápsula `US`/`LA` de la barra también.

## El bloqueo se queda trabado (la pantalla no responde al desbloquear)

> Procedimiento **no verificado** en esta máquina (ver `docs/HANDOFF.md`); es el camino habitual de los bloqueos `ext-session-lock`.

1. Cambia a una TTY: `Ctrl+Alt+F3` e inicia sesión.
2. Reinicia la shell para recrear el bloqueo: `pkill quickshell` y vuelve a la sesión gráfica (`Ctrl+Alt+F1` o `F2`), donde la pantalla sigue bloqueada.
3. Como respaldo existe **hyprlock** (`config/hypr/hyprlock.conf`): desde la TTY, `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr | head -n1) hyprctl dispatch exec hyprlock`, y desbloquea con él.
4. Último recurso: `loginctl terminate-session <id>` (`loginctl list-sessions`); pierdes las ventanas abiertas.

## Plasma Login Manager vs SDDM

El tema de login `dragon-core` es para **SDDM**. Con Plasma Login Manager (`plasmalogin.service`) Hyprland funciona igual, pero el tema no se aplica y `./install.sh --modules login` solo
imprime cómo pasar a SDDM. Comprueba cuál tienes: `readlink /etc/systemd/system/display-manager.service`. Cambiar (no lo ejecuta el instalador):

```sh
sudo systemctl disable plasmalogin && sudo systemctl enable sddm && sudo reboot
```

Volver: `sudo systemctl disable sddm && sudo systemctl enable plasmalogin`.

## Quickshell se queda con la configuración vieja tras actualizar

Quickshell recarga en caliente, pero si la recarga ocurre mientras se mueven o borran archivos, falla («X is not a type») y se queda con lo anterior. Reinicia la shell:

```sh
qs kill; qs -d
```

`./update.sh` lo hace al final. Mira el motivo con `qs log` (o `./doctor.sh`).

## Quickshell avisa de que fue compilado contra otra versión de Qt

«Quickshell was built against Qt 6.11.2 but the system has updated to Qt 6.12.0» significa que el repositorio actualizó Qt sin reconstruir el paquete.
Funciona en la máquina de referencia, pero si hay cierres inesperados: `sudo pacman -Syu` (puede que ya esté el paquete nuevo) o reconstruye Quickshell.

## `git fetch`/`git push` fallan con «Permission denied (publickey)»

La llave SSH no está en tu cuenta de GitHub. Usa HTTPS: `gh auth setup-git` y `git remote set-url origin https://github.com/<usuario>/dragon-island-hypr.git`
(o la opción A del Paso 8 de `pre-instalation.md`).

## `./install.sh` se detiene al empezar

Es el comportamiento esperado cuando falta un requisito: el mensaje dice qué falta y el paso de `pre-instalation.md` que lo resuelve.
Comprobación completa: `./doctor.sh --pre`. Con `--dry-run` el instalador muestra los fallos y continúa para enseñar el plan.
