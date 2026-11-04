# Handoff instalador: simple (lineal, sin motor de eventos)

Fecha: 2026-11-04. Rama única: `installer`. Etiqueta: `instalador-simple`. Sin otras ramas, worktrees, clones ni PR; no se tocó
`~/Devs/dragon-island-hypr`; sin `vin.py`. No se ejecutó ninguna instalación real aquí: todo con `pacman`, `paru`, `sudo`,
`systemctl` y `doctor` FALSOS y con pseudo-terminales. Sin migraciones: son scripts que se ejecutan desde el repositorio.

## Causa real de los fallos anteriores

El motor de `install.sh` (ahora `install-tui.sh`) tenía **tres capas encima de la instalación** (eventos → sumidero TUI/JSON → máquina de
fases con estado guardado) y el resultado del resumen se calculaba **de ese estado**, no de lo instalado. Cada arreglo tocaba una capa y
destapaba el desajuste con otra. Concretamente:

| Síntoma de la VM | Causa | Dónde (en `install-tui.sh` / `lib/`) |
|---|---|---|
| «terminada con avisos · 7 instalados · 0 con problema» con los AUR sin instalar | Los recuentos salían de las filas del *plan* (estado «a instalar» = «instalado») y solo había «problema» si el motor lo había marcado. Corregido en UX2 (`verify_packages`, línea 564) pero el diseño seguía dependiendo del estado | `install-tui.sh:446-451` (recuento del plan), `:564-583` |
| Módulos con «?» | `RESULT[$m]` vacío si el bucle de Despliegue no llegaba a ejecutarse; el resumen imprimía el valor sin comprobarlo. UX2 lo cubrió con `module_result` (`:666`), pero la causa de que el bucle no corriera **no se pudo reproducir** | `install-tui.sh:610-614`, `:666` |
| Salto directo al resumen tras la clave de sudo en la fase AUR | La TUI de pantalla alterna y paru/sudo comparten el terminal: `run_tty` sale de la pantalla alterna con `tui_suspend` y vuelve con `tui_resume` (`lib/tui.sh:119-120`, `install-tui.sh:557`). Cualquier salida inesperada en ese tramo acaba en `finish`. **No lo reproduje** con paru falso en pty; la hipótesis es esa interferencia, no un hecho | `install-tui.sh:557`, `lib/prepare.sh` (`run_tty`) |
| «El preflight no pudo ejecutarse (salida 1)» pero `--check` da exit 0 | Dos rutas distintas: `--check` ejecuta `installer_preflight.py` en texto y sale; la instalación lo ejecutaba con `--json --progress`, con el progreso por stderr mezclado en una tubería, y luego `installer_plan.py`. Cualquiera de los tres fallando (`pf_rc > 1` **o** el plan) daba ese mensaje y **bloqueaba** | `install-tui.sh:413-421` |
| 12 fallos de doctor (AUR, servicios, llavero, DM «none», IPC) | Consecuencia de que el resumen no consultaba a doctor antes de UX2 y de que los servicios dependían de `confirm_sudo` en cada módulo | `modules/core.sh` (bucle de servicios) |

Conclusión: **no se parchea más**. Se sustituye la arquitectura, no el síntoma.

## Qué se reemplazó

- `install.sh` es ahora **lineal** (≈330 líneas, sin `set -e`, sin eventos, sin TUI, sin JSON, sin pantalla alterna, sin leer teclas).
  Cada paso se registra y el siguiente se ejecuta aunque falle. Orden: portada → preflight (solo avisa) → escaneo → una confirmación →
  `sudo -v` una vez → 7 fases → resumen.
- `lib/ui.sh` (nuevo): funciones puras que **solo imprimen** (`ui_banner`, `ui_box`, `ui_phase`, `ui_bar`, `ui_ok/warn/fail/skip`,
  `ui_pkgs`, `ui_summary`). Logo DRAGON OS con degradado Sweet/Garuda, centrado con `tput cols` y ancho máximo 78; con < 80 columnas, versión de una línea;
  sin terminal o con `NO_COLOR` → texto plano y cajas ASCII `+--+` con el mismo contenido.
- `lib/linear.sh` (nuevo): escaneo (`pacman -T` con proveedores), `install_official` (UNA llamada `sudo pacman -Syu --needed --noconfirm`; si falla,
  valida con `pacman -Si`, repite sin los inexistentes y luego uno a uno), `install_aur` (paru/yay; un fallo se anota y sigue; sin ayudante, lo dice y
  lista el comando), `verify_packages` (recuentos con `pacman -T` DESPUÉS de instalar), `run_mod` (un módulo que falla no detiene a los demás),
  `sudo_begin/sudo_ensure/sudo_end` (UNA clave, mantenimiento en el tty real, cierre en el trap), `doctor_verify`, `check_services`, registro `~/dragon-install.log`.
- `lib/manifest.py` (nuevo): lee `packages/profiles.json` → paquetes oficiales y AUR de los perfiles base, keyring, taller, archivos, editor y login.
- El preflight (`lib/preflight.sh`) **solo avisa** en la instalación y no cambia el código de salida; `--check` usa la misma función, de solo lectura.
- `modules/core.sh`: `core_services` separado (la instalación lineal lo ejecuta en su fase 4; `DRAGON_DEFER_SERVICES=1`). `modules/taller.sh`:
  `taller_docker_service` y `taller_group` separados. `lib/common.sh`: con `DRAGON_PKGS_DONE=1` los módulos no reintentan paquetes (ni vuelven a preguntar).
- `VERSION` 0.6.0. Opciones nuevas: `--no-update`, `--tui`.

## Qué se conservó

`install-tui.sh` (el instalador anterior, íntegro) detrás de `--tui` (también `--choose` y `--json-events`); `lib/tui.sh`, `lib/events.sh`,
`lib/prepare.sh`, `lib/plan_screen.sh` y `lib/installer_*.py` (los usa la TUI y `--check`); todos los módulos (`*_apply`, `*_services`, `*_revert`),
las migraciones, `doctor.sh` (pistas con el ayudante AUR detectado, IPC/Quickshell solo dentro de Hyprland), `update.sh`, `uninstall.sh`, `lib/report.sh`
(ahora con «Salida: N»), `snapshot.sh`. `core_quickshell_reload` no arranca Quickshell fuera de Hyprland y lo reinicia si ya corre dentro.

## Decisiones que conviene conocer

- La primera llamada es **`pacman -Syu`**, no `-S` a secas: en una VM recién instalada la base de datos suele estar vieja (404) y un `-S` no actualiza
  el sistema; `-Sy` suelto está prohibido (actualización parcial). `--no-update` da el `-S` literal.
- **SDDM se habilita, no se arranca** (`enable`, sin `--now`): arrancarlo corta la sesión de texto desde la que se está instalando.
- Una pregunta antes de empezar («¿Instalar todo ahora?») cuando hay terminal; `--yes` o sin terminal la omiten. Siguen pidiendo su propio «sí»
  el grupo docker, el cambio de PAM y el tema de arranque.
- Los AUR fallidos no impiden desplegar ni servicios; el resumen sale «Incompleta» con la causa de cada uno y el exit es 1.
- No se reinicia ni se pausa por cambio de kernel (esa lógica era de la TUI): si el kernel en uso ya no existe, el resumen dice «Reinicia».

## Pruebas

`tests/installer_ux/test_simple.py` (13 pruebas, comandos falsos de `tests/preflight/fake-command.py`, ampliado con `FAKE_MISSING_PKG`, `FAKE_SUDO_TTY`
y un `systemctl` con estado): (a) todo ok con los 10 módulos y una sola llamada `pacman -Syu`; (b) paquete oficial inexistente aislado; (c) paru con error y
paru que sale con 0 sin instalar; (d) paru ausente; (e) sudo que pide la clave por `/dev/tty`: exactamente UNA vez; (f) sin terminal; (g) segunda
ejecución idempotente; (h) un módulo que falla (gancho `DRAGON_TEST_FAIL`) no impide los demás; (i) sin «?» y verde solo si doctor pasa; (j) 60/80/120
columnas con y sin color, sin desbordes y con el mismo contenido; (k) `--dry-run` no escribe, no pide sudo y no dice «completa». El preflight roto solo avisa.
Los bloques de la TUI se reapuntaron a `install-tui.sh`.

## Recorrido completo (hecho aquí)

`test_a`: sistema vacío salvo las herramientas base → los 10 módulos (perfiles base, keyring, taller, archivos, editor, login) → 87 oficiales en una llamada,
8 AUR con el ayudante, 7 fases en orden, doctor limpio → «Instalación completa», exit 0, `~/dragon-informe.txt` con «Salida: 0».

## Qué probar en la VM (solo esto)

```sh
git pull
./install.sh
```

Esperado: logo, caja con tu sistema y «faltan N paquetes oficiales · M AUR», una pregunta, UNA clave, y las 7 fases con la salida real de pacman/paru.
Si algo falla, el recuadro rojo «Incompleta» trae el comando de cada punto; repetir `./install.sh` solo hace lo que falta. Si no cuadra, pasa
`~/dragon-informe.txt` (incluye fase, paso, código de salida y la cola del registro).

## Resultado de la suite completa

Ver el último apartado (se rellena al cerrar).
