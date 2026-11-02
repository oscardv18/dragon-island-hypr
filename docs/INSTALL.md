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
| `theme` | fuentes, iconos Candy + Sweet Folders, `nwg-look`, `hyprqt6engine`, ajustes GTK, fondos | `pacman -S` | quita los ajustes GTK (fuentes e iconos se dejan) |
| `plugins` | `hyprpm update/add/enable` de hyprfocus y hyprglass **en primer plano**, luego `hyprpm reload -n && hyprctl reload` | `hyprpm update` pide la contraseña | `hyprpm disable` de los dos |
| `login` | tema SDDM dragon-core (`sddm/install-theme.sh`); con Plasma Login Manager solo imprime cómo pasar a SDDM | `install-theme.sh` pregunta antes de cada paso | `install-theme.sh --uninstall` |
| `keyring` | portal de secretos, flag de Brave, y (si falta) las líneas `pam_gnome_keyring` de `/etc/pam.d/sddm` mostradas como diff | solo el cambio de PAM, con copia `.bak-dragon` | restaura el `.bak-dragon` |
| `keyboard` | distribuciones (por defecto `us,latam`, us siempre primera) en `local.lua`; `localectl set-x11-keymap` opcional | solo `localectl` | quita el bloque de `local.lua` |
| `boot` | tema de Dragon OS para el gestor de arranque (Limine; GRUB con `--bootloader grub`): papel tapiz, paleta, marca, cuenta atrás de 3 s; **opt-in**, ver `docs/BOOT.md` | todos sus pasos: motor en `/usr/local/lib/dragon-os-boot`, gancho de limine-entry-tool, `limine.conf` o `/etc/default/grub` + `grub-mkconfig`; cada uno se pregunta **aunque uses `--yes`** | `./install.sh --revert-boot` (copias de seguridad con fecha al lado de cada archivo) |
| `extras` | Brave, Proton VPN, herdr (instalador oficial), «Mis apps» (cada uno opcional) | `pacman -S` / `yay -S` | retira la configuración; los paquetes se dejan |

`editor` está seleccionado por defecto junto con core, shell, theme, plugins y
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

I3 conectará estos perfiles con la selección, TUI y aplicación. En este tramo
el flujo de aplicación existente conserva sus módulos y confirmaciones:
`--profiles` aún no sirve para instalar, ni selecciona PAM por defecto. I4
creará la instantánea y guardará `pacman -Qqe` antes de aplicar. Contratos,
pruebas, limitaciones y pendientes en
[handoff-instalador-preflight.md](handoff-instalador-preflight.md).
