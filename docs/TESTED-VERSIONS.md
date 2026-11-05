# Versiones probadas

Todo lo de esta tabla es lo que está instalado en la máquina de Oscar donde dragon-island funciona (comprobado el 2026-11-03 con
`pacman -Q` y `uname -r`). Si tu sistema trae versiones más nuevas y algo falla, es el primer sitio donde mirar.

| Componente | Versión | Cómo se comprueba |
|---|---|---|
| Distro | EndeavourOS (Arch), UEFI | `. /etc/os-release; echo $PRETTY_NAME` |
| Kernel | 7.2.11-arch1-1 (`linux` + `linux-headers` 7.2.11.arch1-1) | `uname -r` |
| Hyprland | 0.57.0-1 (config Lua) | `hyprctl version` |
| hyprpm | 0.57.0-1 (paquete aparte en Arch) | `pacman -Q hyprpm` |
| Quickshell | 0.3.2-1 | `qs --version` |
| hyprlock | 0.9.6-3 | `pacman -Q hyprlock` |
| xdg-desktop-portal-hyprland | 1.4.1-2 | `pacman -Q xdg-desktop-portal-hyprland` |
| SDDM | 0.21.0-7 (tema dragon-core) | `pacman -Q sddm` |
| Qt (qt6-declarative) | 6.12.0-3 | `pacman -Q qt6-declarative` |
| Ghostty | 1.4.0-1 | `ghostty --version` |
| kitty | 0.49.2-1 | `kitty --version` |
| awww | 0.12.1-1 | `pacman -Q awww` |
| gum | 2.0.2-1 | `gum --version` |
| yay | 13.1.0-1 | `yay --version` |
| Docker / Compose / Buildx | 29.9.2 / 5.6.1 / 0.38.1 | `pacman -Q docker docker-compose docker-buildx` |
| LazyGit | 0.66.2-1 | `lazygit --version` |
| LazyDocker | no instalado en esta máquina (en `extra`; el preflight lo valida) | `pacman -Si lazydocker` |
| gnome-keyring / libsecret | 1:51.1-1 / 0.21.8.2-1 | `pacman -Q gnome-keyring libsecret` |
| Neovim | 0.12.6-1 | `nvim --version` |
| Python / SQLite | 3.14.8-1 / 3.54.0-1 | `pacman -Q python sqlite` |
| mpv / ffmpeg | 1:0.41.0-6 / 2:9.0.2-2 | `pacman -Q mpv ffmpeg` |
| GPU | AMD Lucienne (Radeon integrada), driver `amdgpu` | `lspci -k` |
| Mesa / Vulkan | mesa 1:26.2.6-1, vulkan-radeon 1:26.2.6-1 | `pacman -Q mesa vulkan-radeon` |

Los plugins de Hyprland (hyprfocus, hyprglass) se compilan dentro de la sesión con `hyprpm` contra la versión de Hyprland
en marcha: su revisión exacta no se anota aquí; se ve con `hyprctl plugin list`.

## CachyOS (sin escritorio, fish por defecto, Btrfs)

**Aún no se ha probado en una máquina real.** Es lo que se prepara para la prueba en máquina virtual (tramo I6 del plan):

| Punto | Esperado | Se verifica con |
|---|---|---|
| Instalación | CachyOS con la opción «sin escritorio» (sin `cachyos-hypr-noctalia`) | `./install.sh --check` |
| Shell | fish por defecto; zsh solo si aceptas `chsh` | `getent passwd $USER` |
| Sistema de archivos | Btrfs con snapper (`root`) | `snapper list-configs` |
| Kernel y cabeceras | `linux-cachyos` + `linux-cachyos-headers` | `./doctor.sh --pre` |
| Ayudante AUR | `paru` | `./doctor.sh --pre` |
| Repositorios | `cachyos-v3`/`v4` pueden sustituir a `extra` con otra versión | columna «repositorio» del preflight (`--check --json`) |
| Hyprland y plugins | misma versión de `hyprland` y `hyprpm`; plugins con `hyprpm update` dentro de la sesión | `hyprctl version`, `pacman -Q hyprland hyprpm` |
| Docker, LazyGit, LazyDocker, Quickshell, Ghostty, awww | confirmar de qué repositorio salen | `pacman -Si <paquete>` |

Cuando se pruebe, se sustituye esta tabla por las versiones reales de esa máquina.

## Notas

- **Pins de plugins:** `hyprpm` elige solo el commit adecuado para la versión de Hyprland en marcha; no se puede fijar a mano
  desde este repo. Si Hyprland sube de versión hay que repetir `hyprpm update` (`./update.sh` lo hace). La versión de
  hyprglass sí se comprueba (`scripts/plugins-foreground.sh` avisa si no es la 0.9.1).
- **Quickshell y Qt:** Quickshell 0.3.1-1 se compiló contra Qt 6.11.2 y el sistema ya tiene Qt 6.12.0; Quickshell lo avisa al
  arrancar («must be rebuilt»). Funciona, pero si ves cierres inesperados es la primera sospecha (`docs/TROUBLESHOOTING.md`).
- **`pacman.conf`:** `multilib` habilitado, `ParallelDownloads = 5`, `Color`, `ILoveCandy`. Ninguna es obligatoria para el instalador.
- **Servicios habilitados en la máquina de referencia:** NetworkManager, bluetooth, power-profiles-daemon, systemd-timesyncd,
  sddm; de usuario: pipewire, pipewire-pulse, wireplumber y gnome-keyring-daemon (por socket).
