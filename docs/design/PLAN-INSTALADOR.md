# Plan del instalador de Dragon OS (quirúrgico, sin errores, con TUI)

Documento para los agentes (Claude Code, Codex) y para Oscar. Léelo entero antes de tocar `install.sh`, `lib/`, `modules/` o `packages/`.
Estado de partida: repositorio `oscardv18/dragon-island-hypr`, `main` en la fase 5 integrada (noviembre 2026).

## 0. Lo que pidió Oscar (se anota tal cual, es el contrato)

1. **Quirúrgico:** solo los paquetes necesarios para que todo el sistema funcione. Objetivo: **0 % de errores** en una instalación limpia.
2. **CachyOS:** averiguar qué paquetes pueden **entrar en conflicto** con lo que CachyOS ya trae. Ya le falló una vez porque el instalador detectó cosas ya instaladas por CachyOS.
3. **Fuera de la base** (no los instala el instalador): editores de código (Visual Studio Code, Antigravity…), Android Studio y sus herramientas, **navegadores** (los instala él a mano).
4. **Dentro de la base:** Docker y Docker Compose; **LazyGit y LazyDocker de una sola vez**; GNOME Keyring y todo lo relacionado con él; lo necesario para Taller y Archivos.
5. **Ciclo de instalación** completo y ordenado, con una **TUI profesional**: centrada, flujo visible, listado de paquetes, nada desastroso, trabajada al milímetro.
6. **Lista previa para el usuario:** qué paquetes debe instalar **a mano antes** de ejecutar el instalador (por ejemplo las cabeceras del kernel, «headers») y que el instalador **no** instala por su cuenta. El instalador ayuda a generarla y a comprobarla.

> Interpretación a confirmar: «el header» = las **cabeceras del kernel** (`linux-cachyos-headers` en CachyOS), necesarias para DKMS y para compilar módulos.

## 1. Perfiles de paquetes (un solo manifiesto, sin duplicados)

| Perfil | Por defecto | Contenido |
|---|---|---|
| `prereq` (a mano, antes) | — | `git` `base-devel` `gum` + ayudante AUR (`paru` en CachyOS, `yay` en otras) + **cabeceras del kernel en uso** + `curl` `unzip` |
| `base` (`core`, `shell`, `theme`, `plugins`, `keyboard`) | sí | listas actuales de `packages/pacman-*.txt` y `aur-*.txt`; **retirar Brave** de aquí |
| `keyring` | sí | `gnome-keyring` `libsecret` (+ `seahorse` opcional) y la configuración que lo deja **desbloqueado al iniciar sesión** |
| `taller` | sí | `docker` `docker-compose` `docker-buildx` `lazygit` `lazydocker` (ambos en `extra` de Arch) + `herdr` (instalador oficial, opt-in con aviso) |
| `archivos` | sí | `udisks2` `inotify-tools` `gvfs` `gvfs-smb` `gvfs-mtp` `gvfs-nfs` `7zip` `libvips` `imagemagick` `poppler` `smbclient` `avahi` `xdg-utils`; opcionales: `samba`, `python-gobject` |
| `editor` | sí (separable con `--modules`) | `neovim` ≥ 0.12 + las herramientas que usa la configuración personal (`packages/pacman-editor.txt`); configuración en `~/.config/nvim` con respaldo; plugins en el primer uso **con confirmación y tiempo máximo**; migración 150 **opt-in** (`DRAGON_NVIM=1`) aun con `--yes`; retirada restaura el Neovim anterior y conserva plugins y datos (`docs/NVIM.md`) |
| `login` | opt-in | `sddm` + tema (toca `/etc`) |
| `mis-apps` | opt-in, **fuera de la base** | las listas personales (`user-pacman.txt`, `user-aur.txt`): editores, Android Studio, Telegram, etc. |

**Regla:** cada nombre se valida con `pacman -Si` (o AUR RPC) **al ejecutar el preflight**; no se asumen nombres de memoria (por ejemplo `7zip` frente a `p7zip`).

## 2. Conflictos conocidos en CachyOS (fuentes en la sección 8)

Verificado en documentación pública:
- **`cachyos-hypr-noctalia` / `cachyos-hyprland-settings`:** el segundo está obsoleto y se desaconseja; el primero trae su propia shell (Noctalia, basada en Quickshell), usa **UWSM** y escribe en `~/.config/hypr/config/*.lua` y `/etc/skel`. **Choca con tu `~/.config/hypr` y con tu Quickshell.** Instalar CachyOS con la opción **«sin escritorio»** evita todo esto.
- **KWallet:** la edición de escritorio de CachyOS instala `kwalletd6`/`kwalletmanager`. Dos servicios quieren ser dueños de `org.freedesktop.secrets` (el llavero). Con GNOME Keyring hay que dejar **uno solo**.
- **Shell:** CachyOS usa **fish** por defecto; tu entorno usa zsh (`chsh` solo con confirmación).
- **Paquetes sobrantes del instalador de CachyOS** que conviene desmarcar al instalar: `cachyos-hello`, `cachyos-kernel-manager`, `cachyos-packageinstaller`, `cachyos-wallpapers`, Firefox y sus idiomas, `vlc-plugins-all`.
- **Un paquete que otro necesita no se quita** aunque lo desmarques: el preflight debe explicarlo, no fallar.

**Por verificar en una máquina CachyOS real** (el preflight lo comprueba solo, no se supone):
- repositorios `cachyos-v3`/`v4` que sustituyen a `extra` con otra versión del mismo paquete;
- `paru` frente a `yay` (cuál trae la instalación);
- si `docker`, `lazygit`, `lazydocker`, `quickshell`, `ghostty`, `awww` y `hyprpm` salen de `extra` o de un repo de CachyOS, y que `hyprland` y sus plugins coinciden en versión;
- Btrfs con **snapper**: instantánea previa.

## 3. Preflight de conflictos (solo lectura, `install.sh --check`)

Salida legible en la TUI y en JSON. Cada comprobación es **bloqueante**, **aviso** o **información**.

1. Distro y versión, kernel y **su paquete de cabeceras** (`pkgbase` de `/usr/lib/modules/$(uname -r)/pkgbase` + `-headers`; bloqueante si falta y hay módulos DKMS).
2. Paquetes de escritorio que pisan configuración: `cachyos-hypr-noctalia`, `cachyos-hyprland-settings`, `noctalia*`, `plasma-*`, `gnome-shell` → aviso/bloqueo con la explicación y la salida.
3. **Dueño de `org.freedesktop.secrets`** (`busctl --user`) y presencia de `kwallet*`.
4. Para cada paquete de los perfiles elegidos: existe (`pacman -Si`/AUR), versión, repo de origen, y **`Conflicts With`/`Replaces`/`Provides`** frente a lo instalado y frente al resto del plan (`pacman -Sp --needed` simulado; sin instalar).
5. Un paquete AUR con dependencias que cambien el tamaño del plan se avisa antes (compilación larga).
6. Espacio en disco, red, reloj, `sudo`, GPU y gestor de acceso activo.
7. Servicios en conflicto: dos gestores de acceso habilitados, `docker` frente a `podman` con socket compartido.
8. **Instantánea previa** si hay snapper o timeshift, y copia de `pacman -Qqe`.

## 4. Ciclo de instalación

0. **Prerrequisitos a mano** (`./doctor.sh --pre` imprime la lista exacta para esta máquina, con el comando de `pacman`).
1. **Preflight** (sección 3). Si hay bloqueos, se detiene antes de tocar nada.
2. **Plan:** perfiles, tabla de paquetes (estado: ya instalado / a instalar / AUR / conflicto), tamaño de descarga y pasos con `sudo`.
3. **Instantánea y respaldo** del estado (`pacman -Qqe`, snapper si existe).
4. **Aplicar** por perfil, con `sudo` una sola vez y confirmación visible en cada paso de `/etc`.
5. **Servicios:** `docker` (habilitar; el grupo `docker` equivale a root: pedir confirmación explícita), `gnome-keyring` desbloqueado al login (PAM, con `sudo` visible).
6. **Verificación:** `doctor.sh` completo + `tests` de humo; informe final con lo que queda manual.
7. **Después:** `update.sh` (migraciones), `uninstall.sh`, y recuperación (cómo volver a la instantánea).

## 5. TUI (bash + gum como motor; capa de presentación aparte)

- `lib/tui.sh`: la presentación; el motor emite **eventos** (`phase`, `pkg`, `step`, `warn`, `done`) y la TUI los dibuja. Con `--plain` o sin terminal, se imprime texto lineal; con `--json-events`, líneas JSON (sirve para pruebas).
- Diseño: contenido **centrado** según `tput cols`; cabecera con el nombre y la versión; **barra de fases** (Preflight · Plan · Paquetes · Despliegue · Servicios · Verificación); tabla de paquetes con iconos de estado y barra de progreso; panel de registro con las últimas líneas; resumen final enmarcado. Paleta Sweet/Garuda (la de `install.sh` actual). Sin parpadeo, sin desbordes, se adapta al redimensionar y a 80 columnas.
- Nada ejecuta comandos desde el dibujado: la TUI solo muestra eventos.

## 6. Tramos de implementación

| Tramo | Contenido | Dueño sugerido |
|---|---|---|
| I1 | Manifiesto de perfiles (`packages/`), `doctor.sh --pre` con la lista previa y las cabeceras, retirar Brave de la base, perfil `taller` y `archivos` | Codex |
| I2 | `lib/preflight.sh` + `install.sh --check` (sección 3) con **`pacman` y AUR simulados** en pruebas, un caso por conflicto de la sección 2 | Codex |
| I3 | `lib/tui.sh` y el flujo de la sección 4 con eventos, `--plain`, `--json-events` | Claude Code |
| I4 | Servicios (`docker`, llavero, instantánea) con confirmaciones; respaldo y restauración (`scripts/backup-dragon.sh`) | Claude Code |
| I5 | Documentación (`INSTALL.md`, `pre-instalation.md`, `TESTED-VERSIONS.md`, sección CachyOS) | quien termine primero |
| I6 | **Prueba real:** máquina virtual con CachyOS «sin escritorio» (Oscar) y luego la reinstalación | Oscar |

Criterios de «0 errores»: `--dry-run` y `--check` no escriben nada; una segunda ejecución no cambia nada; pruebas con `pacman`/AUR/`busctl` falsos para cada conflicto; la suite completa en verde; y el **informe de la VM** sin errores antes de reinstalar el equipo real.

## 7. Decisiones abiertas (por defecto si Oscar no dice otra cosa)

- Gestor de acceso: **SDDM** se mantiene (tema ya hecho). `greetd` + Quickshell queda como proyecto futuro.
- Ayudante AUR: usar el que haya (`paru` en CachyOS); no instalar otro si ya hay uno.
- Docker: **instalar y habilitar**; el grupo `docker` solo con confirmación explícita.
- `herdr`: instalador oficial, con confirmación y la URL visible.
- «Mis apps» (editores, Android Studio, Telegram…): **perfil aparte, desactivado**.

## 8. Fuentes consultadas

- CachyOS Wiki, Hyprland: https://wiki.cachyos.org/el/configuration/desktop_environments/hyprland/
- CachyOS Discuss, instalación mínima con Hyprland: https://discuss.cachyos.org/t/looking-for-help-creating-a-minimal-cachyos-install-with-hyprland/35966
- Arch Linux, `lazydocker` y `lazygit` en `extra`: https://archlinux.org/packages/extra/x86_64/lazydocker/ · https://archlinux.org/packages/extra/x86_64/lazygit/
