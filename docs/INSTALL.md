# Instalación

> **Requisitos previos: [`pre-instalation.md`](../pre-instalation.md).** Es la guía paso a paso de lo que debes tener hecho
> antes de ejecutar el instalador (sistema, herramientas base, red, driver de video, display manager, acceso al repo).
> `./doctor.sh --pre` los comprueba y, por cada fallo, te remite al paso exacto.

## Resumen

```sh
git clone https://github.com/oscardv18/dragon-island-hypr.git ~/dragon-island-hypr
cd ~/dragon-island-hypr
./doctor.sh --pre        # requisitos previos
./install.sh --check     # conflictos: solo lectura, salida 1 si hay bloqueos
./install.sh --dry-run   # plan completo, sin cambiar nada
./install.sh
```

Distros: **Arch y derivadas (EndeavourOS, Arch, CachyOS)**. En cualquier otra el instalador no instala nada. Para añadir una distro hace falta
que existan como paquetes Hyprland ≥ 0.55 (configuración Lua) y Quickshell ≥ 0.3; después se extiende `detect_distro` (`lib/detect.sh`) y
se aportan las listas de `packages/` con los nombres de esa distro. No se ha inventado soporte que no se pueda probar.

## Qué hace cada módulo

| Módulo | Aplica | Sudo | Revierte |
|---|---|---|---|
| `core` | paquetes de `pacman-core.txt` + `aur-core.txt`; enlaces en `~/.config/{hypr,kitty,ghostty,quickshell}` y `~/.local/bin/dragon-pkg`; servicios NetworkManager, bluetooth, power-profiles-daemon (sistema) y pipewire, wireplumber (usuario); variables NVIDIA solo en `local.lua` | `pacman -S`, `systemctl enable` (cada uno confirmado) | quita los enlaces y restaura los respaldos |
| `shell` | zsh, starship, eza, fzf, zoxide, fd, bat; clones de zsh-autosuggestions / zsh-syntax-highlighting / fzf-tab; UNA línea marcada en `~/.zshrc` | `pacman -S`; `chsh` solo si lo confirmas | quita la línea marcada y los enlaces |
| `editor` | Neovim ≥ 0.12 con tu LazyVim, 49 plugins fijados, Laravel/Blade, frontend, Rust y Go; despliega `config/nvim` por enlace o copia | `pacman -S` para dependencias; plugins sin sudo y con confirmación al primer uso | restaura el respaldo anterior; conserva plugins y datos de Neovim |
| `taller` | Docker, Compose, Buildx, LazyGit y LazyDocker (paquetes de `pacman-taller.txt`); en la fase Servicios habilita `docker.service`. **El grupo `docker` equivale a root:** añadirte exige confirmación explícita (`--docker-group` la da de antemano; `--yes` solo no basta) | `pacman -S`, `systemctl enable --now docker`, y `usermod -aG docker` solo si lo confirmas | no quita paquetes ni el grupo; imprime cómo desactivar el servicio |
| `archivos` | paquetes de Archivos: udisks2, inotify-tools, gvfs (+smb, mtp, nfs), 7zip, libvips, imagemagick, poppler, smbclient, avahi, xdg-utils | `pacman -S` | los paquetes se dejan |
| `theme` | fuentes, iconos Candy + Sweet Folders, `nwg-look`, `hyprqt6engine`, ajustes GTK, fondos | `pacman -S` | quita los ajustes GTK (fuentes e iconos se dejan) |
| `plugins` | `hyprpm update/add/enable` de hyprfocus y hyprglass **en primer plano**, luego `hyprpm reload -n && hyprctl reload` | `hyprpm update` pide la contraseña | `hyprpm disable` de los dos |
| `login` | tema SDDM dragon-core (`sddm/install-theme.sh`); con Plasma Login Manager solo imprime cómo pasar a SDDM | `install-theme.sh` pregunta antes de cada paso | `install-theme.sh --uninstall` |
| `keyring` | portal de secretos, flag de Brave y, en la fase Servicios, (si falta) las líneas `pam_gnome_keyring` de `/etc/pam.d/sddm` mostradas como diff; avisa si `kwallet`/`kwallet-pam` compiten | solo el cambio de PAM, visible siempre y con copia `.bak-dragon` | restaura el `.bak-dragon` |
| `keyboard` | distribuciones (por defecto `us,latam`, us siempre primera) en `local.lua`; `localectl set-x11-keymap` opcional | solo `localectl` | quita el bloque de `local.lua` |
| `boot` | tema de Dragon OS para el gestor de arranque (Limine; GRUB con `--bootloader grub`): papel tapiz, paleta, marca, cuenta atrás de 3 s; **opt-in**, ver `docs/BOOT.md` | todos sus pasos: motor en `/usr/local/lib/dragon-os-boot`, gancho de limine-entry-tool, `limine.conf` o `/etc/default/grub` + `grub-mkconfig`; cada uno se pregunta **aunque uses `--yes`** | `./install.sh --revert-boot` (copias de seguridad con fecha al lado de cada archivo) |
| `extras` | Brave, Proton VPN, herdr (instalador oficial), «Mis apps» (cada uno opcional) | `pacman -S` / `yay -S` | retira la configuración; los paquetes se dejan |

`editor` está seleccionado por defecto junto con core, shell, taller, archivos, theme, plugins y
keyboard. Puedes excluirlo con una lista explícita, por ejemplo
`--modules core,shell,theme,plugins,keyboard`. Para desplegarlo: `./install.sh --modules editor` (el instalador incluye core por contrato). `--copy` conserva el
modo copia. No ejecuta sincronización de plugins durante la instalación.

Al abrir nvim por primera vez, confirma la restauración (180 s y hasta 5 s de
cierre). Sin red o si la cancelas, abre sin plugins; `:DragonNvimRestore` permite
reintentar. Nunca se importan plugins, cachés, shada, swap, undo ni logs de otra
máquina. El detalle de herramientas, límites y pruebas está en [NVIM.md](NVIM.md).

La configuración **ya existente** no se adopta por sorpresa al actualizar:
la migración 150 necesita `DRAGON_NVIM=1` o una confirmación interactiva explícita,
lista los archivos diferentes y respalda antes de crear el enlace. `--yes` no
sustituye ese opt-in. No se ha aplicado al Neovim del usuario en esta revisión.

## Banderas

| Bandera | Efecto |
|---|---|
| `--check` | consulta conflictos sin crear estado ni logs; texto por defecto, salida 1 con bloqueos |
| `--check --json` | informe JSON esquema 1: perfiles, paquetes, comprobaciones y bloqueos |
| `--check --profiles a,b` | inspecciona esos perfiles; requiere `--check`, no aplica cambios |
| `--plain` | texto lineal, sin pantalla (es lo que se usa solo cuando no hay terminal) |
| `--json-events` | una línea JSON por evento (`phase`, `pkg`, `step`, `warn`, `log`, `done`); para pruebas y herramientas |
| `--docker-group` | confirma de antemano añadirte al grupo `docker` (equivale a root) |
| `--dry-run` | imprime el plan completo; no escribe en tu `$HOME` ni pide sudo |
| `--yes`, `-y` | sin preguntas; los pasos con sudo siguen mostrando qué hacen |
| `--modules a,b` | solo esos módulos (core siempre) |
| `--extras a,b` | `brave,protonvpn,herdr,myapps` sin preguntar |
| `--no-sudo` | omite todo lo que necesite sudo e imprime el comando manual |
| `--copy` | copia en vez de enlazar |
| `--update` / `--doctor` / `--uninstall` | equivalen a `update.sh` / `doctor.sh` / `uninstall.sh` |

## Probar en seco

```sh
./install.sh --dry-run --yes --modules core,shell,editor,theme,plugins,keyboard,extras,keyring,login
```

Muestra todo lo que haría, pasa por las mismas comprobaciones que una instalación real y no cambia nada
(`git status` limpio y ningún archivo nuevo en `~/.config`, `~/.local`). En una instalación real el instalador se detiene si falla un requisito;
en seco te lo marca y sigue, para que veas el plan.

## Ajustes por máquina (no se versionan)

- `~/.config/hypr/local.lua`: monitores, escala, variables de GPU (NVIDIA), distribuciones de teclado. `hyprland.lua` lo carga el último.
- `~/.config/dragon-island/local.conf`: `KB_LAYOUTS=us,latam` y similares.

Ambos están ignorados por git. Con la instalación por enlaces, `~/.config/hypr` apunta a `config/hypr` del repo: por eso `local.lua` está en `.gitignore`.

## Revertir

```sh
./uninstall.sh --dry-run
./uninstall.sh --modules login,keyring    # solo esos
./uninstall.sh --remove-packages          # además pregunta, módulo a módulo, si desinstalar sus paquetes
```

Los respaldos y registros quedan en `~/.local/state/dragon-island/`.

## dragon-wifi (pendiente del archivo original)

En I1 no se encontró `~/Descargas/dragon-wifi` ni `~/Downloads/dragon-wifi`.
No se ha creado una implementación sustitutiva. Cuando esté el original, se copiará
sin cambios de lógica a `bin/dragon-wifi`, se desplegará mediante `core` a
`~/.local/bin/dragon-wifi` con respaldo y retirada, y se probará con `nmcli` falso.
Para sistemas ya instalados corresponderá una migración desde la 170, idempotente,
con `backup_copy` y respeto a `DRY_RUN`. Esa entrega sigue pendiente.

## Perfiles y preflight (I1 / I2)

`packages/profiles.json` declara base, keyring, taller, archivos y editor por
defecto; mis-apps, login y boot son opt-in. Taller reúne Docker, Compose, Buildx,
LazyGit y LazyDocker; herdr necesita confirmación aparte. Los navegadores quedan
fuera de base. Las listas personales permanecen desactivadas por defecto.

```sh
./install.sh --check --json
./install.sh --check --profiles base,keyring,taller,archivos,editor
./install.sh --check --modules core,editor
```

El perfil base agrupa core/shell/theme/plugins. La traducción de `--modules` a
perfiles se usa solo al comprobar; por ejemplo `core,editor` inspecciona base y
editor. `--profiles` y `--modules` no se combinan. `--check` no activa servicios,
no autentica sudo, no crea instantáneas ni guarda archivos. Informa qué hay que
resolver y devuelve 0 sin bloqueos, 1 con bloqueos o 2 para selección inválida.
Los avisos también deben revisarse antes de instalar.

Contratos, pruebas, limitaciones y pendientes del preflight en
[handoff-instalador-preflight.md](handoff-instalador-preflight.md); los de la
pantalla y los servicios en [handoff-instalador-tui.md](handoff-instalador-tui.md).

## Ciclo de instalación y pantalla (I3)

`./install.sh` recorre siempre las mismas fases, en una barra visible arriba:
**Preflight · Plan · Paquetes · Despliegue · Servicios · Verificación**.

1. **Preflight** (solo lectura): `doctor.sh --pre` y el preflight de conflictos con los módulos elegidos.
   Si hay bloqueos, se detiene **antes de tocar nada** (ni siquiera crea `~/.local/state/dragon-island`).
   En `--dry-run` informa y sigue, para que veas el plan.
2. **Plan:** tabla de paquetes con su estado (`✔` ya instalado · `↓` a instalar · `◆` AUR · `✖` conflicto),
   tamaño de descarga y los pasos con `sudo` de cada módulo. Una sola confirmación.
3. **Paquetes:** `sudo` se pide una vez; antes de cambiar nada se guarda `pacman -Qqe` y, si hay
   snapper o Timeshift, se crea una instantánea. Después `pacman -Syu` y los paquetes del plan.
4. **Despliegue:** cada módulo enlaza sus configuraciones (con respaldo).
5. **Servicios:** `docker`, el grupo `docker` (solo con tu confirmación explícita) y el desbloqueo de
   gnome-keyring al iniciar sesión (líneas PAM con `sudo` visible, nunca en silencio).
6. **Verificación:** `doctor.sh` completo e informe final con lo que queda manual y cómo volver atrás.

La pantalla se centra según el ancho de la terminal (hasta 78 columnas), funciona desde 60, se redibuja al
cambiar de tamaño y usa la paleta Sweet/Garuda. Solo dibuja eventos; no ejecuta nada. Si falla, el
instalador sigue en texto lineal. Los avisos de la fase Preflight que se repiten (por ejemplo los `plasma-*`
de tu escritorio) salen agrupados.

## Servicios, instantánea y respaldo (I4)

- **Instantánea previa:** snapper (configuración `root`) o Timeshift si existen; si no, solo la lista de paquetes
  explícitos en `~/.local/state/dragon-island/pacman-Qqe-<fecha>.txt`. El informe final trae los comandos para volver:
  `sudo snapper -c root rollback <n>` / `sudo timeshift --restore`, y
  `sudo pacman -S --needed - < <lista>` para reinstalar lo que había.
- **Docker:** `systemctl enable --now docker` con confirmación. El grupo `docker` equivale a root: sin tu «sí» explícito
  (o `--docker-group`) no se añade, y el informe te dice cómo hacerlo después.
- **Llavero:** el diff de `/etc/pam.d/sddm` se muestra siempre, la copia es `.bak-dragon`, y se avisa de `kwallet`/`kwallet-pam`.
  El instalador nunca muestra ni copia contraseñas ni el contenido de ningún llavero.
- **Respaldo de lo tuyo:** `scripts/backup-dragon.sh [--dest DIR] [--dry-run]` copia `dragon.db` (con `sqlite3 .backup`, no `cp`),
  `~/.config/dragon-island` (con `settings.json`) y los llaveros, con una lista de huellas; y **lista sin copiar** lo sensible que
  debes respaldar tú (ssh, gpg, perfiles de navegador, volúmenes de Docker, ramas de git sin subir).
  `scripts/restore-dragon.sh <carpeta> [--with-keyrings] [--dry-run]` verifica las huellas, conserva lo que reemplaza como
  `<ruta>.pre-restore-<fecha>` y no toca los llaveros sin `--with-keyrings` ni con `gnome-keyring-daemon` en marcha.

## CachyOS

Para que el instalador no choque con CachyOS:

- **Instala CachyOS «sin escritorio»** (opción *No Desktop* del instalador de CachyOS). Así no entran `cachyos-hypr-noctalia`
  ni `cachyos-hyprland-settings`, que escriben en `~/.config/hypr` y traen su propia shell sobre Quickshell.
- **fish es el shell por defecto.** El módulo `shell` configura zsh y solo ejecuta `chsh` si lo confirmas; fish no se toca.
- **Btrfs + snapper:** si tienes la configuración `root` de snapper, la instantánea previa es automática (con confirmación de `sudo`).
- **Ayudante AUR:** CachyOS trae `paru`; el instalador usa el que haya y no instala otro.
- **Cabeceras del kernel:** `linux-cachyos-headers` (o la del kernel que uses); `./doctor.sh --pre` imprime el comando exacto.
- **Desmarca al instalar CachyOS:** `cachyos-hello`, `cachyos-kernel-manager`, `cachyos-packageinstaller`, `cachyos-wallpapers`,
  Firefox y sus idiomas, `vlc-plugins-all`. Si ya están, el preflight los avisa; no los quita.
- **Repositorios `cachyos-v3`/`v4`:** pueden servir otra versión de un paquete de `extra`; el preflight muestra el
  repositorio efectivo de cada paquete. **Pendiente de comprobar en una máquina CachyOS real** (ver el handoff de la TUI).
- **KWallet:** si instalaste el escritorio KDE de CachyOS, `kwalletd6` compite con gnome-keyring por `org.freedesktop.secrets`.
