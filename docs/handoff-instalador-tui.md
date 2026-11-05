# Handoff instalador: I3 / I4 (TUI, ciclo de instalación, servicios, respaldo)

Fecha: 2026-11-03. Rama única: `installer`, carpeta `dragon-installer`. Sin ramas, worktrees, clones ni PR.
No se tocó `~/Devs/dragon-island-hypr`. Etiqueta de cierre: `instalador-i4`.
No se ejecutó ninguna instalación real (ni `sudo`, ni `pacman -S`, ni `snapper`, ni `docker`): todo lo
comprobado es `--dry-run`, `--check`, bloqueos y comandos simulados. Eso es lo principal que queda por probar.

## Entregado

- `lib/events.sh`: el motor emite `phase`, `pkg`, `step`, `warn`, `log`, `done`. Tres salidas: texto lineal (`--plain`, y automático sin terminal),
  una línea JSON por evento (`--json-events`) y la TUI. Si la TUI falla una vez, se cierra y se sigue en texto.
- `lib/tui.sh`: solo dibuja. Cabecera con nombre y versión, barra de fases, tabla de paquetes con iconos
  (`✔` instalado, `↓` a instalar, `◆` AUR, `✖` conflicto, `…` en curso), barra de progreso, panel de registro y resumen
  final enmarcado. Centrada según el tamaño real (máx. 78 columnas, funciona desde 60; por debajo de lo que cabe, la barra de fases
  se reduce a la fase actual `n/6`), un solo `write` por cuadro, limitado a ~20 cuadros por segundo, redibuja con SIGWINCH,
  pantalla alternativa que se devuelve al salir, paleta Sweet/Garuda. Sin color si `NO_COLOR` o `TERM=dumb`.
- `install.sh` reescrito por fases: Preflight (`doctor.sh --pre` + `lib/installer_preflight.py` con los módulos elegidos) →
  Plan (tabla, descarga, pasos con sudo, una confirmación) → Paquetes (sudo una vez, `pacman -Qqe`, instantánea, `-Syu`,
  paquetes oficiales con eventos por paquete, AUR uno a uno) → Despliegue (módulos) → Servicios → Verificación (`doctor.sh`) →
  informe con lo manual y la recuperación. Con bloqueos del preflight en una ejecución real se detiene **antes de crear
  `~/.local/state/dragon-island`** (el registro es un temporal hasta entonces); en `--dry-run` informa y sigue.
- Módulos nuevos `taller` (Docker, Compose, Buildx, LazyGit, LazyDocker) y `archivos`; ambos van en la selección por
  defecto. `keyring` sigue siendo opt-in (toca `/etc`).
- Servicios: `docker.service` con confirmación; el grupo `docker` (equivale a root) **solo** con «sí» explícito (pregunta con «No»
  por defecto) o `--docker-group`; `--yes` solo no basta. El desbloqueo de gnome-keyring por PAM pasó de `keyring_apply` a
  `keyring_services` (diff visible, copia `.bak-dragon`, aviso de `kwallet`/`kwallet-pam`). Nada imprime ni copia secretos.
- `lib/snapshot.sh`: lista `pacman -Qqe` en `~/.local/state/dragon-island/pacman-Qqe-<fecha>.txt` y, si hay snapper
  (configuración `root`) o Timeshift, instantánea previa con confirmación. El informe final trae los comandos para volver.
- `scripts/backup-dragon.sh` y `scripts/restore-dragon.sh` (`--dry-run`): `dragon.db` con `.backup` (probado con WAL vivo, que `cp`
  perdería), `~/.config/dragon-island` (con `settings.json`), llaveros, huellas `MANIFEST.sha256`; lista sin copiar ssh, gpg, perfiles de
  navegador, volúmenes de Docker y ramas de git sin subir. La restauración verifica las huellas, conserva lo reemplazado
  (`.pre-restore-<fecha>`) y no toca llaveros sin `--with-keyrings` ni con `gnome-keyring-daemon` en marcha.
- Documentación: `docs/INSTALL.md` (ciclo, servicios, respaldo, CachyOS, banderas), `pre-instalation.md`,
  `docs/TESTED-VERSIONS.md` (versiones reales de esta máquina, 2026-11-03, y tabla de CachyOS pendiente de probar).
- Migraciones: **ninguna**. No cambia configuración de sistemas ya instalados (solo el flujo del instalador y scripts nuevos).
  El rango desde la 190 queda libre.

## Pruebas

- `tests/tui/test_tui.py` (12): terminal simulada (60 a 240 columnas), centrado, sin desbordes ni cuadros más altos que la terminal,
  iconos, progreso, secuencias ANSI saneadas, JSON válido por línea, caída de la TUI a texto, resumen en 80 columnas.
- `tests/tui/test_install_modes.py` (8, ~3 min): `install.sh` con pacman/AUR/sudo/gum simulados: JSON de `--dry-run`
  (seis fases en orden, `done` final), texto sin ANSI, grupo docker solo con la bandera, preflight bloqueante (salida 1, nada
  escrito, sin `sudo`), y un **pty real** a 80×24 y 200×50 (pantalla alternativa, redibujos, ninguna línea más ancha que la terminal,
  resumen final, HOME/XDG y `git status` intactos).
- `tests/backup/test_backup.py` (10): HOME temporal, base SQLite con WAL sin volcar, dry-run sin escrituras, modos 700/600, lista sin
  copiar ni revelar secretos, destino no vacío, ida y vuelta, `.pre-restore`, llaveros solo con bandera, respaldo manipulado.
- Suite completa `tests/run-all.sh`: ver el resultado al final de este archivo.

## Lo que NO he podido ver ni probar

- **La pantalla en un terminal real.** Verifiqué la salida bruta en un pty (secuencias, anchos, alturas) y el cuadro como texto,
  no su aspecto en Ghostty/kitty. Hay que mirar: alineación, colores, que el panel de registro se lea bien, y el cuadro al
  redimensionar la ventana con la instalación en curso.
- **Una instalación real** (sin `--dry-run`): el flujo de `pacman -S` con eventos por paquete (se analiza «(n/m) installing X»),
  AUR uno a uno, `sudo -v` con la TUI suspendida, los avisos de `gum confirm` sobre el terminal real, la instantánea con snapper y
  Timeshift, `systemctl enable --now docker` y el cambio de PAM. Solo se ejecutaron contra comandos simulados o en `--dry-run`.
- **Aquí el preflight bloquea** (`nodejs`/`nodejs-lts-krypton`, `rust`/`rustup`: proveedores propios ya instalados). Una instalación
  real en esta máquina se detendría. No se retiró ni sustituyó nada. En una máquina limpia (la VM) no debería ocurrir.

## Pendiente en la máquina virtual (CachyOS «sin escritorio», fish, Btrfs)

1. `./doctor.sh --pre` y `./install.sh --check` en limpio: ¿cero bloqueos? ¿qué repositorio efectivo sale (`cachyos-v3`/`v4`)?
2. `./install.sh` completo con terminal real: mirar la TUI a 80 columnas y ancha; redimensionar durante «Paquetes».
3. `paru` en lugar de `yay` (CachyOS): el flujo AUR llama a `$AUR_HELPER -S --needed --noconfirm <paquete>`.
4. Instantánea previa con snapper sobre Btrfs: ¿existe la configuración `root`? ¿pide la contraseña sin romper la pantalla?
5. Docker: `docker.service` habilitado; negar y aceptar el grupo; comprobar el aviso de «cierra sesión».
6. Llavero: diff de PAM correcto con SDDM en CachyOS; `kwallet-pam` ausente en «sin escritorio».
7. Segunda ejecución: no debe cambiar nada (tabla toda `✔`, sin pasos de `sudo` de paquetes).
8. `scripts/backup-dragon.sh` y `restore-dragon.sh` con datos reales; recuperar con `snapper rollback` y con `pacman -S --needed - < lista`.
9. Un fallo forzado de paquete: debe quedar `✖` en la tabla, aviso en el informe y salida con «con avisos».

## Notas de diseño y límites

- Los avisos de módulos que escriben con `echo` (no con `log_info`) se muestran **al terminar ese módulo** (se capturan y
  se reproducen como eventos de registro); los de `log_info`/`log_warn` salen al momento.
- El motor instala por perfil las listas de `base, keyring, taller, archivos, editor`; `login`, `boot` y `mis-apps`
  los instala su propio módulo con su confirmación.
- `doctor.sh --pre` se muestra en el registro y los requisitos duros se deciden con las comprobaciones de `lib/checks.sh`: la red se
  consulta dos veces (unos segundos de más). Un dry-run completo tarda ~20–30 s.
- `tests/run-all.sh` añade ~3 min por los pty y las ejecuciones de `install.sh`; `--only tui|modes|backup` ejecuta cada parte.
- `dragon-wifi` sigue pendiente (ver `docs/INSTALL.md`): no se encontró el original.

## Resultado de la suite completa

`tests/run-all.sh` ejecutada una vez: todos los bloques en verde salvo `tests/activity`
(`test_range_cli_under_50ms_with_30_days`: 57,7 ms frente al límite de 50 ms, medida de latencia sensible a la carga de la
máquina). Se repitió solo ese bloque, sin cambiar código ni límites: pasa (mediana 37,8 ms). No se presenta la primera
ejecución como pasada limpia; es una intermitencia ajena a este tramo.
