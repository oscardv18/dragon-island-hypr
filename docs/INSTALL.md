# Instalación

> **Un solo comando: `./install.sh`.** Instalador lineal: escanea, instala lo que falta (una llamada a `sudo pacman`, luego `paru`),
> despliega, levanta servicios, configura SDDM y el llavero y verifica con `doctor.sh`. Las opciones de este documento son **avanzadas**.
> [`pre-instalation.md`](../pre-instalation.md) explica cada comprobación.

### Las siete fases

| Fase | Qué hace |
|---|---|
| (antes) | `sudo -v` una sola vez, con mantenimiento en segundo plano que se cierra al terminar; escaneo con `pacman -T` y aviso del preflight |
| 1/7 Paquetes oficiales | `sudo pacman -Syu --needed --noconfirm <faltantes>` en UNA llamada (`--no-update` usa `-S`). Si falla: valida los nombres con `pacman -Si`, repite sin los inexistentes y, si hace falta, instala uno a uno |
| 2/7 Paquetes AUR | `paru -S --needed --noconfirm` (o `yay`); un fallo se anota y sigue. Sin ayudante AUR lo dice y lista el comando exacto |
| 3/7 Despliegue | enlaces y configuración de cada módulo, `backup_copy` de lo existente, bloque marcado en `~/.zshrc` |
| 4/7 Servicios y SDDM | `systemctl enable --now` de los servicios del sistema y de usuario; SDDM se **habilita** (no se arranca: cortaría tu sesión) y su tema |
| 5/7 Llavero y grupos | PAM de gnome-keyring (diff visible, copia `.bak-dragon`), grupo docker (confirmación explícita) |
| 6/7 Arranque | tema de GRUB/Limine: opt-in con su propia pregunta (`--modules boot`) |
| 7/7 Verificación | `doctor.sh`: el recuadro final sale de ahí |

Salida: **0** si todo está en orden (con o sin avisos); **1** si algo esencial falla (paquete que no se instaló, módulo fallido, algo que `doctor.sh`
marca). `--dry-run` no escribe, no pide sudo y termina con «Simulación (dry-run)», nunca con «completa». Sin terminal o con `NO_COLOR` la salida es
texto plano con cajas ASCII. `--tui` abre la interfaz anterior de pantalla alterna (`install-tui.sh`).

## Resumen

```sh
git clone https://github.com/oscardv18/dragon-island-hypr.git ~/dragon-island-hypr
cd ~/dragon-island-hypr
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

## Opciones avanzadas

Ninguna es necesaria para una instalación normal. Sirven para simular, automatizar, probar o acotar lo que se instala.

| Bandera | Efecto |
|---|---|
| `--check` | consulta conflictos sin crear estado ni logs; texto por defecto, salida 1 con bloqueos |
| `--check --json` | informe JSON esquema 1: perfiles, paquetes, comprobaciones y bloqueos |
| `--check --profiles a,b` | inspecciona esos perfiles; requiere `--check`, no aplica cambios |
| `--plain` | texto lineal, sin pantalla (es lo que se usa solo cuando no hay terminal) |
| `--json-events` | una línea JSON por evento (`phase`, `pkg`, `step`, `warn`, `log`, `done`); para pruebas y herramientas |
| `--docker-group` | confirma de antemano añadirte al grupo `docker` (equivale a root) |
| `--dry-run` | imprime el plan completo; no escribe en tu `$HOME`, no pide sudo, no escribe el informe y nunca ejecuta `pacman -Sy` |
| `--choose` | menú de módulos y modo de despliegue (por defecto no hay menús) |
| `--restart` | olvida el progreso guardado (instalación interrumpida por un reinicio) y empieza de cero |
| `--yes`, `-y` | sin preguntas; los pasos con sudo siguen mostrando qué hacen |
| `--modules a,b` | solo esos módulos (core siempre) |
| `--extras a,b` | `brave,protonvpn,herdr,myapps` sin preguntar |
| `--no-sudo` | omite todo lo que necesite sudo e imprime el comando manual |
| `--copy` | copia en vez de enlazar |
| `--update` / `--doctor` / `--uninstall` | equivalen a `update.sh` / `doctor.sh` / `uninstall.sh` |

## Probar en seco (avanzado)

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

## Ciclo de instalación y pantalla

`./install.sh` recorre siempre las mismas fases, en una barra visible arriba:
**Preflight · Plan · Paquetes · Despliegue · Servicios · Verificación**.

1. **Preflight:** diagnóstico (`doctor.sh --pre`) y **preparación** del sistema, con una confirmación y una contraseña de sudo:
   - los prerrequisitos que falten (`git base-devel gum curl unzip pciutils`) y la actualización completa del sistema van en **una**
     transacción (`pacman -Syu --needed …`), así nunca hay una actualización parcial;
   - el ayudante AUR: el que haya; si no, `paru` (CachyOS) o `yay` de los repositorios; si tampoco está, se construye desde AUR
     (`paru-bin` / `yay-bin`, con `git clone` + `makepkg` como tu usuario);
   - si el kernel en uso deja de coincidir con el instalado, **se detiene** con «reinicia y vuelve a ejecutar `./install.sh`» y guarda el progreso en
     `~/.local/state/dragon-island/install-progress`; al volver continúa donde lo dejó (no repite la actualización si es de hace menos de 24 h);
   - después, y solo si el kernel coincide, las **cabeceras** del kernel en uso;
   - por último el preflight de conflictos con los módulos elegidos (solo lectura). Con bloqueos se detiene antes de instalar ningún paquete.
2. **Plan:** la tabla de paquetes (`↓` a instalar · `◆` AUR · `✖` conflicto · y la lista de los ya instalados), el tamaño de descarga,
   **cada incidencia con el paquete, la causa y lo que hará el instalador** (omitir, sustituir, conservar, compilar o bloquear) y los pasos con `sudo`.
   Una sola confirmación: **«Instalar todo»**. Los cambios que merecen su propio «sí» (grupo `docker`, PAM, `chsh`) lo siguen pidiendo.
3. **Paquetes:** antes de cambiar nada se guarda `pacman -Qqe` y, si hay snapper o Timeshift, se crea una instantánea. Después los paquetes del plan.
4. **Despliegue:** cada módulo enlaza sus configuraciones (con respaldo).
5. **Servicios:** `docker`, el grupo `docker` (solo con tu confirmación explícita) y el desbloqueo de
   gnome-keyring al iniciar sesión (líneas PAM con `sudo` visible, nunca en silencio).
6. **Verificación:** `doctor.sh` completo, resumen final y **`~/dragon-informe.txt`**.

Sin gestor de acceso activo (CachyOS sin escritorio), el módulo `login` se añade solo: instala y habilita SDDM. `xorg-server` entra en el
plan porque `sddm` lo exige como dependencia fija; el saludo en Wayland de SDDM no lo evita (sigue declarando esa dependencia), así que no reduce paquetes.

### Qué dice el recuadro final (y el código de salida)

El recuadro sale de **verificar**, no de suponer: los paquetes se comprueban con `pacman` después de instalar y el resultado final lo decide `doctor.sh`.

| Título | Cuándo | Salida |
|---|---|---|
| Instalación terminada | todo instalado y el doctor sin fallos | 0 |
| terminada con avisos | algo se omitió a propósito (p. ej. `--no-sudo`) | 0 |
| **Instalación INCOMPLETA** | un paquete no quedó instalado, un módulo falló o el doctor aún echa algo en falta; se listan con su comando exacto | 1 |
| La instalación se detuvo | falló un requisito, el preflight o la fase de paquetes oficiales: indica el paso y cómo reintentar | 1 |
| Instalación en pausa | hay que reiniciar (kernel nuevo) | 0 |

Cada módulo figura como `ok`, `con avisos`, `fallido` u `omitido (razón)`; nunca en blanco. `./install.sh` de nuevo **continúa donde lo dejó**. Los paquetes AUR que fallen no impiden
desplegar los módulos (el recuadro queda en «INCOMPLETA»); los oficiales sí detienen la instalación. Mientras corre `paru`, `sudo` o cualquier comando interactivo, la pantalla
de la TUI se retira y el terminal es del comando; al terminar vuelve con el estado de las fases.

### El informe `~/dragon-informe.txt`

Se escribe al terminar **o al fallar** (modo 600). Trae: fecha y resultado, la fase y el paso donde se detuvo, versiones (instalador, distro,
kernel, GPU, pacman, ayudante AUR, Hyprland, Quickshell…), el resultado de cada comprobación, las incidencias del plan, los paquetes con problema
y su causa, y la cola del registro. No contiene contraseñas, tokens ni variables de entorno; tu carpeta personal aparece como `~`.
En `--dry-run` no se escribe (una simulación no deja rastro).

La pantalla se centra según el ancho de la terminal (hasta 78 columnas), funciona desde 60, se redibuja al
cambiar de tamaño y usa la paleta Sweet/Garuda. Solo dibuja eventos; no ejecuta nada. Si falla, el
instalador sigue en texto lineal. Los avisos repetidos (por ejemplo los `plasma-*` de tu escritorio o los paquetes AUR) salen agrupados.

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
