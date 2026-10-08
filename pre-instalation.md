# pre-instalation — todo lo que hay que hacer ANTES de `./install.sh`

Guía paso a paso para partir de una máquina recién instalada y llegar a ejecutar el instalador de dragon-island.
Está escrita a partir de una instalación real que ya funciona (EndeavourOS + KDE Plasma + SDDM + Hyprland 0.56 +
Quickshell 0.3, GPU AMD); los comandos y los nombres de paquete se comprueban con `tests/check-docs.sh`.

> Comprobación automática de TODO esto: `./doctor.sh --pre`. Cada ✘ te dice qué paso repetir.
> Convención: `$USER` y `$HOME` son tu usuario y tu carpeta personal; no hay que sustituir nada a mano.

## Paso 0 — Resumen y orden

| Paso | Qué haces | Internet | Reinicio | Tiempo aprox. |
|---|---|---|---|---|
| 1 | Instalar EndeavourOS (KDE Plasma mínimo, SDDM) | sí | sí | 20–30 min |
| 2 | Primer arranque: actualizar el sistema y los mirrors | sí | si cambia el kernel | 5–15 min |
| 3 | Herramientas base: `git base-devel curl unzip gum github-cli yay` | sí | no | 2 min |
| 4 | Red y hora (NTP) | sí | no | 1 min |
| 5 | Driver de video (AMD, Intel o NVIDIA; tú eliges UNO) | sí | sí (NVIDIA) | 2–10 min |
| 6 | Display manager y Plasma como segunda sesión | no | solo si lo cambias | 1–5 min |
| 7 | Teclado y locale (opcional) | no | no | 1 min |
| 8 | Acceso al repo y `git clone` | sí | no | 1–5 min |
| 9 | Verificar los requisitos con `./doctor.sh --pre` | no | no | 10 s |
| 10 | Primera ejecución: `./install.sh --dry-run` y luego `./install.sh` | sí | cerrar sesión | 15–40 min |

**Qué hace el script:** instala los paquetes de `packages/`, enlaza las configuraciones en `~/.config` con copia de
seguridad, compila los plugins de Hyprland con `hyprpm`, y (opcional, cada uno con confirmación) el tema del login, el
llavero, el teclado y apps extra. Es idempotente: puedes ejecutarlo dos veces.

**Qué NO hace:**

- No instala drivers de video (Paso 5, lo haces tú).
- No toca Plasma: sigue ahí como segunda sesión.
- No cambia el login ni `/etc` sin preguntarte, y cada paso con `sudo` se explica y se confirma.
- No se ejecuta como root y no pide ni guarda tu contraseña.
- No sobrescribe tus configuraciones sin respaldo en `~/.local/state/dragon-island/backups/<fecha>/`.

## Paso 1 — Instalar EndeavourOS

**Para qué sirve:** tener la base (Arch + EndeavourOS) sobre la que se instala Hyprland, junto a KDE Plasma.
Soportado: Arch y derivadas (EndeavourOS, Arch, CachyOS). Otras distros: el instalador se detiene (ver `docs/INSTALL.md`).

**Qué elegir en el instalador de EndeavourOS (Calamares):**

- Modo **online** (descarga lo último; el offline instala paquetes más viejos y exige una actualización grande después).
- Entorno de escritorio: **KDE Plasma**. Si el instalador ofrece un perfil mínimo, elígelo.
- Display manager: **SDDM** (el tema de login de dragon-island solo funciona con SDDM; ver Paso 6).
- Usuario: el tuyo, con contraseña, y **administrador** (grupo `wheel`, para poder usar `sudo`). No uses el inicio de
  sesión automático (el llavero necesita tu contraseña al entrar).
- Particiones (sugerencia): arranque UEFI, EFI de 512 MB–1 GB, raíz ext4 o btrfs con **40 GB o más** libres,
  swap de 4–8 GB (o igual a tu RAM si quieres hibernar).

**Cómo comprobar que quedó bien:**

```bash
. /etc/os-release && echo "$PRETTY_NAME"
id -nG | tr ' ' '\n' | grep -x wheel
df -h "$HOME" | tail -n 1
```

Salida esperada: `EndeavourOS`, la palabra `wheel` y al menos 5 GB libres.

**Si falla:**

- *No aparece `wheel`:* añádete desde otra cuenta administradora con `sudo usermod -aG wheel "$USER"` y vuelve a entrar. Pide `sudo`.
- *El instalador no arranca en UEFI:* desactiva Secure Boot en la BIOS o usa modo Legacy; para el modo normal activa UEFI.
- *No hay red durante la instalación:* usa cable, o configura el wifi desde el propio instalador antes de continuar.

## Paso 2 — Primer arranque

**Para qué sirve:** partir de un sistema completamente actualizado y con llaves de paquetes válidas. Hyprland 0.56 y
Quickshell 0.3 vienen de los repositorios: un sistema desactualizado te daría versiones viejas.

```bash
sudo pacman -Syu
```

Si los mirrors van lentos (EndeavourOS trae `eos-rankmirrors`; en Arch puro usa `reflector`):

```bash
sudo pacman -S --needed reflector
eos-rankmirrors
```

Si pacman actualizó el kernel (`linux`), **reinicia**:

```bash
sudo reboot
```

**Cómo comprobar que quedó bien:**

```bash
pacman -Qu | wc -l
uname -r
pacman -Q linux
```

Salida esperada: `0` actualizaciones pendientes, y la versión de `uname -r` igual a la de `pacman -Q linux` (con guion en vez de punto, p. ej. `7.2.9-arch1-1` y `7.2.9.arch1-1`).

**Si falla:**

- *`firma no válida` / `signature is unknown trust`:* las llaves están viejas. Renuévalas y repite: `sudo pacman -Sy archlinux-keyring endeavouros-keyring && sudo pacman -Su`. Pide `sudo`.
- *`no se pudo bloquear la base de datos`:* hay otro pacman en marcha. Espera o borra el bloqueo solo si no hay ningún pacman: `ps -e | grep pacman` y, si no sale nada, `sudo rm /var/lib/pacman/db.lck`.
- *Archivos `.pacnew`:* no son un error; revisa `pacdiff` (paquete `pacman-contrib`) cuando tengas tiempo.

## Paso 3 — Herramientas base

**Para qué sirve:** son lo único que el instalador necesita para empezar: `git` (clonar), `base-devel` (compilar paquetes
AUR y plugins), `curl`, `unzip`, `gum` (la interfaz de terminal), `github-cli` y `yay` (ayudante de AUR). Es exactamente
`packages/base.txt`.

```bash
sudo pacman -S --needed git base-devel curl unzip gum github-cli yay
```

(`yay` está en el repositorio de EndeavourOS. En **Arch puro** no está en pacman: compílalo desde el AUR con
`git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si`.)

**Cómo comprobar que quedó bien:**

```bash
command -v git curl unzip gum gh yay
pacman -Q base-devel
yay --version
```

Salida esperada: seis rutas (`/usr/bin/...`), `base-devel` con su versión y `yay v13...` (o superior).

**Si falla:**

- *`target not found: yay`:* no estás en EndeavourOS. Compílalo desde el AUR como se indica arriba.
- *`makepkg` no se ejecuta como root:* ejecútalo con tu usuario, no con `sudo`.
- *`gum` no existe:* está en `extra`; sincroniza con `sudo pacman -Sy` y repite (Paso 2).

## Paso 4 — Red y hora

**Para qué sirve:** el instalador descarga paquetes y clona repositorios; una hora incorrecta rompe HTTPS y las firmas de pacman.

```bash
sudo systemctl enable --now NetworkManager
sudo timedatectl set-ntp true
```

**Cómo comprobar que quedó bien:**

```bash
systemctl is-active NetworkManager
ping -c 2 archlinux.org
timedatectl show -p NTPSynchronized --value
```

Salida esperada: `active`, dos respuestas del ping y `yes`.

**Si falla:**

- *`ping: archlinux.org: Fallo temporal`:* sin DNS o sin red. Con wifi: `nmcli device wifi list` y `nmcli device wifi connect "TU_RED" --ask`.
- *`NTPSynchronized` en `no`:* espera un minuto y repite; si sigue, `sudo systemctl enable --now systemd-timesyncd`. Pide `sudo`.
- *La hora es de otro año:* corrígela con `sudo timedatectl set-time "2026-01-01 12:00:00"` (con tu fecha real) y activa NTP de nuevo.

## Paso 5 — Driver de video

**Para qué sirve:** Hyprland y Quickshell dibujan con la GPU. **El script no instala drivers**: lo haces tú, con UNO de
los tres bloques de abajo, según tu hardware. Identifica primero tu GPU:

```bash
lspci -k | grep -EA3 'VGA|3D|Display'
```

Fíjate en la línea `Kernel driver in use:` (si ya dice `amdgpu`, `i915`, `xe` o `nvidia`, el driver del kernel está cargado).

### 5A — AMD

```bash
sudo pacman -S --needed mesa vulkan-radeon vulkan-tools
```

Opcional, para juegos de 32 bits (necesita `[multilib]` activo en `/etc/pacman.conf`): `lib32-mesa lib32-vulkan-radeon`.

### 5B — Intel

```bash
sudo pacman -S --needed mesa vulkan-intel intel-media-driver vulkan-tools
```

### 5C — NVIDIA

Depende de la generación de la GPU: **Turing (GTX 16xx / RTX 20xx) y posteriores** usan los módulos abiertos; las
anteriores (GTX 10xx y más viejas) necesitan el driver de la rama 580 desde el AUR.

```bash
sudo pacman -S --needed linux-headers nvidia-open nvidia-utils vulkan-tools
```

Si usas otro kernel que no sea `linux` (por ejemplo `linux-lts`), cambia `nvidia-open` por `nvidia-open-dkms` y
instala los headers de ese kernel. GPU anterior a Turing:

```bash
yay -S --needed nvidia-580xx-dkms nvidia-580xx-utils
```

Con NVIDIA añade el parámetro del kernel `nvidia_drm.modeset=1` si tu versión del driver aún no lo activa por defecto
(en GRUB: edita `GRUB_CMDLINE_LINUX_DEFAULT` en `/etc/default/grub` y ejecuta `sudo grub-mkconfig -o /boot/grub/grub.cfg`).
El instalador escribirá las variables de entorno de NVIDIA en `~/.config/hypr/local.lua`; las de AMD/Intel no hacen falta.

**Secure Boot + DKMS:** los módulos DKMS (`nvidia-open-dkms`, `nvidia-580xx-dkms`) no se cargan con Secure Boot activo
a menos que los firmes; lo más sencillo es desactivar Secure Boot en la BIOS.

**Reinicia** tras instalar un driver NVIDIA: `sudo reboot`.

**Cómo comprobar que quedó bien:**

```bash
lspci -k | grep -EA3 'VGA|3D|Display' | grep 'Kernel driver in use'
vulkaninfo --summary | grep -E 'deviceName|driverName'
```

Salida esperada: un `Kernel driver in use:` real (`amdgpu`, `i915`/`xe` o `nvidia`) y tu GPU en `deviceName`
(no `llvmpipe`, que sería render por software).

**Si falla:**

- *`vulkaninfo` muestra `llvmpipe`:* falta el paquete de Vulkan de tu GPU o hay que reiniciar.
- *NVIDIA: pantalla negra al arrancar Hyprland:* revisa `nvidia_drm.modeset=1`, que `nvidia-utils` y el módulo coincidan, y reinicia.
- *`error: no se pudo satisfacer la dependencia` con `nvidia-open`:* el kernel y los módulos no coinciden; actualiza todo (Paso 2) o usa la variante `-dkms`.

## Paso 6 — Display manager y Plasma

**Para qué sirve:** (Plasma queda como segunda sesión.) Hyprland se instala como una sesión MÁS en el login, junto a KDE Plasma. El tema de login de
dragon-island es para **SDDM**. Comprueba cuál tienes activo:

```bash
readlink /etc/systemd/system/display-manager.service
```

Salida esperada: `/usr/lib/systemd/system/sddm.service`. Si Plasma no está instalado como sesión (Paso 1), añádelo:

```bash
sudo pacman -S --needed plasma-desktop dolphin
```

**Si ves `plasmalogin.service` (Plasma Login Manager):** Hyprland funciona igual, pero el tema de login de
dragon-island **no** se aplica con Plasma Login Manager. Para pasar a SDDM (hazlo solo si quieres el tema; el script no
lo ejecuta por ti):

```bash
sudo pacman -S --needed sddm
sudo systemctl disable plasmalogin
sudo systemctl enable sddm
sudo reboot
```

Para volver a Plasma Login Manager: `sudo systemctl disable sddm && sudo systemctl enable plasmalogin`.

**Cómo comprobar que quedó bien:**

```bash
systemctl is-enabled sddm
ls /usr/share/wayland-sessions
```

Salida esperada: `enabled` y, en la lista, `plasma.desktop` (después del instalador también `hyprland.desktop`).

**Si falla:**

- *Pantalla negra al cambiar de display manager:* entra por TTY (`Ctrl+Alt+F3`), repite el `disable`/`enable` y reinicia.
- *No aparece la sesión Plasma:* falta `plasma-desktop` (arriba). Hyprland (`hyprland` en el módulo core) añade su propia sesión.
- *Dos display managers habilitados:* deshabilita el que no uses con `sudo systemctl disable <nombre>`.

## Paso 7 — Teclado y locale

**Para qué sirve:** (paso opcional.) El login y Hyprland usan `us` como distribución principal y `latam` como segunda (para ñ y acentos).
Si te basta, no hagas nada: el módulo `keyboard` del instalador lo configura para Hyprland. Para que el **login** (SDDM y TTY)
también empiece en `us`:

```bash
localectl status
sudo localectl set-x11-keymap us,latam
```

Locale en español de Venezuela (ajusta a tu país si quieres otro): descomenta `es_VE.UTF-8 UTF-8` en `/etc/locale.gen` y genera.

```bash
sudo sed -i 's/^#\(es_VE.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sudo locale-gen
sudo localectl set-locale LANG=es_VE.UTF-8
```

**Cómo comprobar que quedó bien:**

```bash
localectl status | grep -E 'X11 Layout|System Locale'
locale -a | grep -i es_VE
```

Salida esperada: `X11 Layout: us,latam` (o empezando por `us`) y `es_VE.utf8` en la lista.

**Si falla:**

- *`localectl: Could not set...`:* falta `sudo` o no hay sesión de systemd (por SSH sin login). Repite en una sesión normal.
- *Los acentos salen mal en la terminal:* cierra sesión y vuelve a entrar para que se recargue `LANG`.
- *El login escribe en otra distribución:* en el login, el tema fuerza el índice 0 (`us`); si no, repite `set-x11-keymap` y reinicia.

## Paso 8 — Acceso al repo

**Para qué sirve:** descargar el repositorio. Es **público**: para clonar por HTTPS no necesitas cuenta ni llaves.
La autenticación solo hace falta si lo haces fork privado o quieres subir cambios.

Opción A — HTTPS (la más simple):

```bash
git clone https://github.com/oscardv18/dragon-island-hypr.git "$HOME/dragon-island-hypr"
cd "$HOME/dragon-island-hypr"
```

Opción B — con GitHub CLI (permite luego `git push` por HTTPS):

```bash
gh auth login
gh auth setup-git
gh repo clone oscardv18/dragon-island-hypr "$HOME/dragon-island-hypr"
```

Opción C — con llave SSH:

```bash
ssh-keygen -t ed25519 -C "$USER@$(hostname)"
gh ssh-key add "$HOME/.ssh/id_ed25519.pub"
ssh -T git@github.com
git clone git@github.com:oscardv18/dragon-island-hypr.git "$HOME/dragon-island-hypr"
```

**Cómo comprobar que quedó bien:**

```bash
git -C "$HOME/dragon-island-hypr" log --oneline -n 3
```

Salida esperada: tres líneas con commits recientes.

**Si falla:**

- *`Permission denied (publickey)`:* la llave SSH no está añadida a tu cuenta (opción C) o el agente no la ve; usa la opción A, que no necesita llaves.
- *`gh auth login` pide un navegador y no hay:* elige «Paste an authentication token» y usa un token creado en tu cuenta.
- *`ssh_askpass: No such file or directory`:* es el mismo problema de llave; usa HTTPS.

## Paso 9 — Verificar los requisitos

**Para qué sirve:** comprobar de una vez los pasos 1–8. Es solo lectura: no cambia nada.

```bash
cd "$HOME/dragon-island-hypr"
./doctor.sh --pre
```

Salida esperada (cada línea con ✔):

```text
Requisitos previos (pre-instalation.md)
  ✔ No eres root
  ✔ Distro soportada (EndeavourOS)
  ✔ sudo disponible y usuario en wheel
  ✔ Herramientas base: git, curl, unzip, gum, base-devel
  ✔ Ayudante de AUR (yay/paru)
  ✔ Red: archlinux.org alcanzable
  ✔ Hora sincronizada (NTP)
  ✔ Driver de video cargado (...)
  ✔ Display manager activo (sddm)
  ✔ Teclado del login empieza por us
  ✔ Hyprland ≥ 0.55 y Quickshell ≥ 0.3 (instalados o disponibles en el repo)
  ✔ Espacio libre ≥ 5 GB en $HOME
```

Cada línea con ✘ trae debajo `→ ver pre-instalation.md, Paso N`: repite ese paso y ejecuta `./doctor.sh --pre` otra vez.

**Si falla:**

- *`Falta base-devel` aunque lo instalaste:* en Arch es un paquete, no un grupo; comprueba con `pacman -Q base-devel`.
- *`Hyprland … es anterior a 0.55`:* actualiza el sistema (Paso 2); la configuración Lua exige 0.55 o superior.
- *El driver aparece sin cargar:* reinicia tras instalarlo (Paso 5).

## Paso 10 — Primera ejecución

**Para qué sirve:** instalar dragon-island. Primero en seco (no cambia nada ni pide `sudo`), luego de verdad.

```bash
cd "$HOME/dragon-island-hypr"
./install.sh --dry-run
./install.sh
```

**Qué esperar:**

1. Comprobaciones previas: si falla alguna, el instalador se detiene y te dice qué paso de esta guía repetir.
2. Un menú para elegir módulos (`core` es obligatorio; `login`, `keyring` y `extras` vienen desmarcados porque tocan `/etc` o instalan apps) y el **plan completo** antes de aplicar.
3. Los pasos con `sudo` se explican y se confirman uno a uno: actualizar el sistema, instalar paquetes, habilitar servicios, y `hyprpm` (pide tu contraseña para instalar cabeceras).
4. Tarda entre 15 y 40 minutos, sobre todo por los paquetes AUR y los plugins.

**Al terminar:**

```bash
./doctor.sh
```

Después **cierra sesión**, y en el login elige la sesión **Hyprland**. Si el módulo `plugins` se ejecutó fuera de
Hyprland, en tu primer inicio de sesión se abre una terminal que compila los plugins (pide `sudo`): déjala terminar.

Revertir o actualizar: `./uninstall.sh` (por módulo con `--modules`), `./update.sh`.

**Si falla:**

- *Un paquete AUR no compila:* mira el error de `yay`; suele ser una dependencia que falta o un `base-devel` incompleto. Repite `./install.sh --modules core` cuando lo arregles.
- *`hyprpm update` falla:* no lo lances desde autostart ni desde otra herramienta; ejecuta `scripts/plugins-foreground.sh` en una terminal DENTRO de Hyprland.
- *Quieres probar sin riesgo:* `./install.sh --dry-run --yes` muestra todo el plan sin escribir nada.

## Paso 11 — Lo que el script instalará por ti

**Para qué sirve:** comparar con lo que ya tienes. La tabla se genera desde `packages/` (`scripts/gen-package-table.sh`).

<!-- packages:begin (generado por scripts/gen-package-table.sh; no editar a mano) -->
| Paquete | Módulo | Origen |
|---|---|---|
| `git` | (previo, Paso 3) | oficial |
| `base-devel` | (previo, Paso 3) | oficial |
| `curl` | (previo, Paso 3) | oficial |
| `unzip` | (previo, Paso 3) | oficial |
| `gum` | (previo, Paso 3) | oficial |
| `github-cli` | (previo, Paso 3) | oficial |
| `yay` | (previo, Paso 3) | oficial |
| `hyprland` | core | oficial |
| `hyprlock` | core | oficial |
| `hypridle` | core | oficial |
| `hyprpolkitagent` | core | oficial |
| `xdg-desktop-portal-hyprland` | core | oficial |
| `xdg-desktop-portal-gtk` | core | oficial |
| `gnome-keyring` | core | oficial |
| `libsecret` | core | oficial |
| `ghostty` | core | oficial |
| `kitty` | core | oficial |
| `dolphin` | core | oficial |
| `wl-clipboard` | core | oficial |
| `cliphist` | core | oficial |
| `grim` | core | oficial |
| `slurp` | core | oficial |
| `wf-recorder` | core | oficial |
| `hyprsunset` | core | oficial |
| `libnotify` | core | oficial |
| `quickshell` | core | oficial |
| `qt6-svg` | core | oficial |
| `qt6-imageformats` | core | oficial |
| `awww` | core | oficial |
| `mpv` | core | oficial |
| `ffmpeg` | core | oficial |
| `ffmpegthumbnailer` | core | oficial |
| `pacman-contrib` | core | oficial |
| `pipewire` | core | oficial |
| `pipewire-pulse` | core | oficial |
| `wireplumber` | core | oficial |
| `playerctl` | core | oficial |
| `brightnessctl` | core | oficial |
| `networkmanager` | core | oficial |
| `bluez` | core | oficial |
| `bluez-utils` | core | oficial |
| `power-profiles-daemon` | core | oficial |
| `upower` | core | oficial |
| `khal` | core | oficial |
| `ddcutil` | core | oficial |
| `jq` | core | oficial |
| `grimblast-git` | core | AUR |
| `mpvpaper` | core | AUR |
| `zsh` | shell | oficial |
| `starship` | shell | oficial |
| `eza` | shell | oficial |
| `fzf` | shell | oficial |
| `zoxide` | shell | oficial |
| `fd` | shell | oficial |
| `bat` | shell | oficial |
| `ttf-jetbrains-mono-nerd` | theme | oficial |
| `nwg-look` | theme | oficial |
| `ttf-outfit` | theme | AUR |
| `candy-icons-git` | theme | AUR |
| `sweet-folders-icons-git` | theme | AUR |
| `hyprqt6engine` | theme | AUR |
| `sddm` | login | oficial |
| `qt6-declarative` | login | oficial |
| `qt6-svg` | login | oficial |
| `hyprpm` | plugins | oficial |
| `cpio` | plugins | oficial |
| `cmake` | plugins | oficial |
| `meson` | plugins | oficial |
| `ninja` | plugins | oficial |
| `gcc` | plugins | oficial |
| `pkgconf` | plugins | oficial |
| `git` | plugins | oficial |
| `brave-bin` | extras (brave) | AUR |
| `proton-vpn-gtk-app` | extras (protonvpn) | oficial |
| `herdr` | extras | instalador oficial (sin root, ~/.local/bin) |
| `zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf-tab` | shell | git clone |
| `hyprbars`, `hyprfocus`, `hyprglass` | plugins | hyprpm |
| Mis apps: opencode eza zoxide bat btop nautilus telegram-desktop github-cli shellcheck thunar vlc obs-studio obsidian vlc-plugin-ffmpeg genoffice-bin  | extras (myapps) | lo que instalaste desde la Tienda |
<!-- packages:end -->

Lo que ya tengas instalado no se reinstala (`pacman -S --needed`). Los paquetes **no** se desinstalan al revertir salvo que lo pidas
(`./uninstall.sh --remove-packages`).

## Paso 12 — Problemas comunes antes del script

**Para qué sirve:** los fallos más frecuentes de las instalaciones nuevas, antes de ejecutar nada de dragon-island.

- **Sin red:** `nmcli device status` y reconecta (`nmcli device wifi connect "TU_RED" --ask`). Con cable, `sudo systemctl restart NetworkManager`.
- **Mirrors lentos:** `eos-rankmirrors` (EndeavourOS) o `sudo reflector --country Venezuela,Colombia,Brazil --latest 20 --sort rate --save /etc/pacman.d/mirrorlist` (ajusta los países a los tuyos). Pide `sudo`.
- **Fallo de compilación AUR:** lee el error completo que imprime `yay`; limpia con `yay -Sc` y reintenta. Suele ser una dependencia faltante.
- **`base-devel` ausente:** `sudo pacman -S --needed base-devel` (sin él no compila ni `yay` ni los plugins).
- **Espacio en disco:** necesitas al menos 5 GB libres en `$HOME` (el instalador lo comprueba): `df -h "$HOME"`; libera con `sudo pacman -Sc` y `yay -Sc`.
- **Hora incorrecta que rompe HTTPS:** Paso 4. Síntomas: `SSL certificate problem` o `signature is not valid yet`.
- **Conflicto de paquetes:** si pacman dice `están en conflicto`, lee qué paquete choca; no uses `--overwrite` ni `--noconfirm` a ciegas. Un caso típico es tener otro demonio de notificaciones (`mako`, `dunst`, `swaync`): solo debe quedar el de Quickshell.
- **Quickshell avisa de Qt 6.11 → 6.12:** el paquete se compiló contra otra versión de Qt; si algo se cuelga, reconstruye o espera a que el repositorio publique el paquete nuevo (`docs/TROUBLESHOOTING.md`).

**Cómo comprobar que quedó bien:** `./doctor.sh --pre` (Paso 9) con todo en ✔.
