# Instalación

> **Requisitos previos: [`pre-instalation.md`](../pre-instalation.md).** Es la guía paso a paso de lo que debes tener hecho
> antes de ejecutar el instalador (sistema, herramientas base, red, driver de video, display manager, acceso al repo).
> `./doctor.sh --pre` los comprueba y, por cada fallo, te remite al paso exacto.

## Resumen

```sh
git clone https://github.com/oscardv18/dragon-island-hypr.git ~/dragon-island-hypr
cd ~/dragon-island-hypr
./doctor.sh --pre        # requisitos previos
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
| `theme` | fuentes, iconos Candy + Sweet Folders, `nwg-look`, `hyprqt6engine`, ajustes GTK, fondos | `pacman -S` | quita los ajustes GTK (fuentes e iconos se dejan) |
| `plugins` | `hyprpm update/add/enable` de hyprbars, hyprfocus, hyprglass **en primer plano**, luego `hyprpm reload -n && hyprctl reload` | `hyprpm update` pide la contraseña | `hyprpm disable` de los tres |
| `login` | tema SDDM dragon-core (`sddm/install-theme.sh`); con Plasma Login Manager solo imprime cómo pasar a SDDM | `install-theme.sh` pregunta antes de cada paso | `install-theme.sh --uninstall` |
| `keyring` | portal de secretos, flag de Brave, y (si falta) las líneas `pam_gnome_keyring` de `/etc/pam.d/sddm` mostradas como diff | solo el cambio de PAM, con copia `.bak-dragon` | restaura el `.bak-dragon` |
| `keyboard` | distribuciones (por defecto `us,latam`, us siempre primera) en `local.lua`; `localectl set-x11-keymap` opcional | solo `localectl` | quita el bloque de `local.lua` |
| `extras` | Brave, Proton VPN, herdr (instalador oficial), «Mis apps» (cada uno opcional) | `pacman -S` / `yay -S` | retira la configuración; los paquetes se dejan |

## Banderas

| Bandera | Efecto |
|---|---|
| `--dry-run` | imprime el plan completo; no escribe en tu `$HOME` ni pide sudo |
| `--yes`, `-y` | sin preguntas; los pasos con sudo siguen mostrando qué hacen |
| `--modules a,b` | solo esos módulos (core siempre) |
| `--extras a,b` | `brave,protonvpn,herdr,myapps` sin preguntar |
| `--no-sudo` | omite todo lo que necesite sudo e imprime el comando manual |
| `--copy` | copia en vez de enlazar |
| `--update` / `--doctor` / `--uninstall` | equivalen a `update.sh` / `doctor.sh` / `uninstall.sh` |

## Probar en seco

```sh
./install.sh --dry-run --yes --modules core,shell,theme,plugins,keyboard,extras,keyring,login
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
