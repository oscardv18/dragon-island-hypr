# Versiones probadas

Todo lo de esta tabla es lo que está instalado en la máquina donde dragon-island funciona (probado el 2026-10-07).
Si tu sistema trae versiones más nuevas y algo falla, es el primer sitio donde mirar.

| Componente | Versión | Cómo se comprueba |
|---|---|---|
| Distro | EndeavourOS (Arch), UEFI | `. /etc/os-release; echo $PRETTY_NAME` |
| Kernel | 7.2.9-arch1-1 (`linux` + `linux-headers`) | `uname -r` |
| Hyprland | 0.56.2 (commit efb5099, config Lua) | `hyprctl version` |
| hyprpm | 0.56.2-4 (paquete aparte en Arch) | `pacman -Q hyprpm` |
| Quickshell | 0.3.1-1 | `qs --version` |
| Plugin hyprbars | 1.0 (hyprland-plugins, commit fijado por hyprpm para 0.56.x: `7644cec`) | `hyprctl plugin list` |
| Plugin hyprfocus | 1.0 (mismo repo y commit `7644cec`) | `hyprctl plugin list` |
| Plugin hyprglass | 0.9.1 (hyprnux/hyprglass) | `hyprctl plugin list` |
| SDDM | 0.21.0-7 (tema dragon-core) | `pacman -Q sddm` |
| Qt (qt6-declarative, qt6-svg) | 6.12.0-1 | `pacman -Q qt6-declarative` |
| Ghostty | 1.3.1-2 | `ghostty --version` |
| gum | 2.0.2-1 | `gum --version` |
| yay | 13.0.1-1 | `yay --version` |
| GPU | AMD Lucienne (Radeon integrada), driver `amdgpu` | `lspci -k` |
| Mesa / Vulkan | mesa 26.2.4, vulkan-radeon 26.2.4 | `pacman -Q mesa vulkan-radeon` |

## Notas

- **Pins de plugins:** `hyprpm` elige solo el commit adecuado para la versión de Hyprland en marcha; no se puede fijar a mano
  desde este repo. Si Hyprland sube de versión hay que repetir `hyprpm update` (`./update.sh` lo hace). La versión de
  hyprglass sí se comprueba (`scripts/plugins-foreground.sh` avisa si no es la 0.9.1).
- **Quickshell y Qt:** Quickshell 0.3.1-1 se compiló contra Qt 6.11.2 y el sistema ya tiene Qt 6.12.0; Quickshell lo avisa al
  arrancar («must be rebuilt»). Funciona, pero si ves cierres inesperados es la primera sospecha (`docs/TROUBLESHOOTING.md`).
- **`pacman.conf`:** `multilib` habilitado, `ParallelDownloads = 5`, `Color`, `ILoveCandy`. Ninguna es obligatoria para el instalador.
- **Servicios habilitados en la máquina de referencia:** NetworkManager, bluetooth, power-profiles-daemon, systemd-timesyncd,
  sddm; de usuario: pipewire, pipewire-pulse, wireplumber y gnome-keyring-daemon (por socket).
