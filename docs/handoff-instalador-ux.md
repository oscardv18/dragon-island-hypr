# Handoff instalador: experiencia de un solo comando (UX1)

Fecha: 2026-11-03. Rama única: `installer`, carpeta `dragon-installer`. Etiqueta de cierre: `instalador-ux1`.
Sin otras ramas, worktrees, clones ni PR. No se tocó `~/Devs/dragon-island-hypr`. Sin `vin.py` ni teclas a otras terminales.
Esta tarea cambia la **experiencia**, no el motor de paquetes. No se ejecutó ninguna instalación real en esta máquina
(sin `sudo`, sin `pacman -S`): el flujo real se probó con comandos falsos con estado y, para el diagnóstico, dentro de un contenedor
`cachyos/cachyos` descartable (solo lectura y `--dry-run`).

## Qué se hizo

**A. Un solo comando.** `./install.sh` sin opciones hace el ciclo entero:

1. **Diagnóstico** (`doctor.sh --pre`) y comprobaciones previas con resultado registrado para el informe.
2. **Preparación** (`lib/prepare.sh`), con **una** confirmación («Preparar») y **una** sesión de `sudo` (`sudo -n true`; si pide contraseña,
   `sudo -v` en el terminal real y un mantenimiento en segundo plano): los prerrequisitos que faltan
   (`git base-devel gum curl unzip pciutils`, y `paru`/`yay` si están en los repositorios) y `pacman -Syu` van en **una transacción**
   (`pacman -Syu --needed --noconfirm …`): nunca hay actualización parcial. Sin ayudante AUR y sin `paru` en los repositorios se construye desde
   AUR con `git clone` + `makepkg -si` como usuario. Sin `gum` todo funciona en texto plano (pregunta con `[S/n]`).
3. **Kernel:** si el kernel en uso deja de coincidir con el instalado, se detiene con «Reinicia y vuelve a ejecutar `./install.sh`» (estado `pause`,
   salida 0), guarda `stage=reboot` en `~/.local/state/dragon-island/install-progress` y **continúa donde lo dejó**: no repite `-Syu` si
   la actualización es de menos de 24 h, y entonces instala las cabeceras (`pkgbase` + `-headers`), nunca antes. `--restart` olvida el progreso.
   La detección ya no depende de poder leer `pkgbase`: tras una actualización el directorio de módulos del kernel en uso desaparece.
4. **Plan** (`lib/plan_screen.sh`): tabla en columnas, descarga, **cada incidencia con paquete, causa y acción** (`BLOQUEA`, `SUSTITUYE`, `OMITE`,
   `CONSERVA`, `COMPILA`, `NOTA`, `AVISO`) y los pasos con sudo. Una sola confirmación, **«Instalar todo»**. Los cambios que merecen su propio «sí»
   lo conservan (`confirm_explicit`: PAM del llavero, `chsh`; `confirm_default_no`: grupo `docker`). El teclado del login pasó a nota manual.
5. Instalar, verificar con el doctor, resumen final.
6. **Informe** `~/dragon-informe.txt` (`lib/report.sh`, modo 600) al terminar **o al fallar** (también si el script muere por un error): versiones,
   resultado de cada comprobación, incidencias, paquetes con problema y causa, fase/paso donde se detuvo, cola de 80 líneas del registro.
   Se sanea: sin contraseñas, tokens, `Bearer`, URLs con credenciales ni variables de entorno; `$HOME` aparece como `~`. Imprime su ruta.
   En `--dry-run` **no** se escribe (una simulación no deja rastro).
7. `./doctor.sh` suelto: si Dragon no está instalado comprueba los requisitos previos y termina con «¿Instalar ahora? [S/n]»
   (`--no-ask` para quien lo llama desde `install.sh`). Solo pregunta con terminal.
8. Sin gestor de acceso (CachyOS sin escritorio) el módulo `login` se **añade solo** (instala y habilita SDDM). El menú de módulos pasa a `--choose`.
9. Documentación: `README.md` y `pre-instalation.md` explican solo el comando único; `docs/INSTALL.md` agrupa las opciones en «Opciones avanzadas».

**B. Fallos de la prueba en la VM.**

| # | Causa y arreglo |
|---|---|
| 8 | El volcado salía de `--check` en texto (imprimía la evidencia JSON de cada comprobación). Ahora `--check` resume; JSON solo con `--json`/`--json-events`. |
| 9 | La evidencia de `package:` y `dependency:` era el `pacman -Si` completo. Ahora es `repo/nombre versión`. |
| 10 | El consejo de PKGBUILD era por paquete. Ahora una sola nota `COMPILA · AUR` con la lista y las dependencias de compilación fuera del plan. |
| 11 | El preflight tarda ~25 s sin salida. `installer_preflight.py --progress` emite avance por stderr → `ev_progress`; la TUI muestra «Paquetes · comprobando…», la barra y el paso. |
| 12 | `VERSION` (0.5.0) en lugar de `git describe`. |
| 13 | **Causa real del borde desalineado:** `tui_fit` rellenaba con `printf '%-*s'`, que cuenta **bytes**; cada acento acortaba la fila. Ahora rellena por caracteres. Además `tui_wrap` con sangría francesa, y `LC_ALL=C.UTF-8` si la sesión no es UTF-8. |
| 14 | Título «Simulación terminada (dry-run)»; los módulos figuran como «simulado»; el recuento nunca contradice («N con problema» siempre con la lista y la causa). |
| 15 | Pruebas que comparan el estado antes/después, comprueban que no hay `sudo` ni `pacman -S*` (jamás `-Sy`) y que no se escribe informe ni estado. No pude reproducir la escritura del VM (`pacman-Qqe-*.txt`): en el código `snapshot_create` ya estaba protegido por `$DRY_RUN`; si ocurrió, fue con una versión anterior. |
| 16 | `pciutils` en `packages/base.txt`; `systemd-detect-virt`; GPU sin identificar o sin driver = aviso (`check_*` devuelve 2; el doctor muestra ⚠); sin gestor de acceso = aviso «el módulo login instalará SDDM». «se encontró: display-manager» venía de `readlink -f` (devuelve la ruta aunque no exista): ahora `-e`. |
| 17 | `packages/compatible.json` con los pares `xdg-desktop-portal-*` y `hyprland`/`hyprpm`. |
| 18 | `xorg-server` lo trae **`sddm`** (dependencia fija). Verificado con `pacman -Si` en un contenedor CachyOS: `sddm` depende de `xorg-server`, y ningún paquete de los perfiles lo trae por otra vía. El plan lo anota. Valorado el saludo en Wayland: SDDM sigue declarando esa dependencia, así que **no reduce paquetes**; no se cambió el diseño. |

## Los «24 con problema»: lo que averigüé y lo que no

El contador del recuadro final sumaba los estados `failed` y `conflict`. En `--dry-run` solo puede emitirse `conflict`, que sale de los
`Conflicts With` bloqueantes del preflight. **No pude reproducir 24 conflictos**: ejecuté el preflight real dentro de `cachyos/cachyos`
(repositorios por defecto y con `cachyos-v3`/`core-v3`/`extra-v3`, y con el conjunto típico de «sin escritorio» instalado) y salieron **0
conflictos**, 535 paquetes a instalar (la mayoría dependencias) y solo avisos. Lo que sí encontré y corregí:

- 448 dependencias contadas como **avisos** («La resolución amplía el plan…»): ahora son información y se resumen («+453 dependencias»).
- Un aviso por paquete AUR, por par de `Provides` compatibles y por paquete de Plasma.
- La TUI mostraba solo las últimas líneas del Registro: los bloqueos reales se perdían.

El plan ahora **nombra** cada paquete bloqueado con su causa y la acción, y el informe lo guarda en «Incidencias del plan» y «Paquetes con problema».
**Si en la VM vuelven a salir «N con problema», el informe dirá cuáles son.** Es lo primero que hay que mirar.

## Pruebas

- `tests/installer_ux/test_ux.py` (26): `DryRunPurity` (sin escrituras, sin `sudo`, sin `pacman -S*`), `PlainOutput`, `Preparation`
  (prerrequisitos en una transacción, una sola actualización, kernel que cambia → pausa → segunda ejecución → tras reiniciar continúa sin repetir
  `-Syu` e instala las cabeceras; `paru` del repositorio y construido desde AUR; `--no-sudo`), `Report` (fallo de paquete con causa, bloqueo, cierre
  inesperado; sin secretos aunque el comando falso los imprima), `MachineAwareness` (VM sin GPU ni gestor de acceso), `PlanIncidents`, `RealTerminal`
  (pty 80×30 con una sola confirmación) y `FinalSummary` (versión, borde alineado, texto cortado con «…»).
- Sistema falso con estado: `tests/preflight/fake-command.py` (`FAKE_STATE`, `FAKE_UPDATE_REPLACES_KERNEL`, `FAKE_FAIL_INSTALL`, `FAKE_VIRT`,
  `FAKE_NO_GPU`, `FAKE_NO_DM`, `FAKE_NO_PARU_REPO`). `DRAGON_PREFLIGHT_ROOT` ahora también redirige `detect_distro` y `display_manager`;
  `DRAGON_AUR_HELPERS` fija los candidatos a ayudante AUR; `DRAGON_STOP_AFTER=prepare|plan|packages` es un gancho **solo de pruebas**.
- Ajustados: `test_prereq` (pciutils), `test_preflight` (las dependencias son información), `test_providers` (extrae las funciones de `install.sh`),
  `test_install_modes` (el bloqueo real ahora se cubre en `installer_ux`).
- Suite completa `tests/run-all.sh`: ver el resultado al final de este archivo.
- Un fallo de rendimiento oculto, arreglado: el mantenimiento de `sudo` retenía la tubería de salida hasta 50 s tras terminar (los tests iban 20× más lentos).

## Migraciones

**Ninguna.** Todo lo cambiado son scripts que se ejecutan desde el repositorio (`install.sh`, `doctor.sh`, `lib/`, `modules/`, `sddm/install-theme.sh`):
no hay archivos instalados por copia que renovar ni estado de sistemas ya instalados que transformar. `docs/HANDOFF.md` no se tocó (lo actualiza una sola persona al final).
El rango desde la 190 sigue libre.

## Qué queda por probar en la VM (CachyOS «sin escritorio»)

No pude ver ni probar: **la TUI en un terminal real** (alineación y colores en Ghostty/kitty; solo verifiqué anchos y estructura en un pty) ni **una instalación real**.

1. `./install.sh` en limpio **sin nada preinstalado**: ¿la confirmación «Preparar» y UNA contraseña de sudo bastan? ¿`paru` de los repositorios de CachyOS?
2. Si la actualización cambia el kernel: ¿aparece «Reinicia y vuelve a ejecutar»? Tras reiniciar, ¿continúa sin repetir `-Syu` y con las cabeceras de `linux-cachyos`?
3. La pantalla de **Plan**: ¿se lee bien en 80×24 y ancho? ¿Aparecen las incidencias? **¿Cuáles son los «24»?** (si vuelven, el informe los nombra).
4. `xorg-server` en la nota del plan, `login` añadido solo, SDDM habilitado y el tema aplicado sin preguntas intermedias (`DRAGON_ASSUME_YES=1` en `install-theme.sh`).
5. Que el **grupo `docker`** sigue pidiendo su propio «No» por defecto, y que el **cambio de PAM** (si eliges `keyring`) y `chsh` siguen preguntando tras «Instalar todo».
6. `~/dragon-informe.txt`: ¿trae todo lo necesario? Forzar un fallo (p. ej. cortar la red durante un AUR) y mirar «Paquetes con problema».
7. Segunda ejecución: «Sistema preparado», tabla toda `✔`.
8. Sin `gum` (antes de la preparación) el texto plano pregunta con `[S/n]`; comprobar que sirve en la consola de la VM.
9. `./doctor.sh` suelto: la pregunta «¿Instalar ahora? [S/n]» y que `S` lanza `install.sh` (solo verifiqué que no pregunta sin terminal ni con `--no-ask`).
10. La construcción de `paru-bin` desde AUR si el repositorio de CachyOS no lo trae (usa `paru-bin`, no `paru`: evita compilar Rust; decisión mía).

## Decisiones y límites

- `paru-bin`/`yay-bin` para el ayudante construido desde AUR (el binario precompilado del propio proyecto); se avisa de que su PKGBUILD no se revisa en el momento.
- La actualización guardada se da por válida 24 h (`PROGRESS_MAX_AGE`).
- El plan solo lista como incidencias lo que afecta a paquetes; los avisos de máquina (kernel, reloj, sudo, gestor de acceso…) salen en el diagnóstico.
- La cancelación en «Preparar» o «Instalar todo» (salida 0) solo la probé con el flujo de pty que acepta; la rama «No» no tiene prueba (necesita un `gum` falso que responda 1).

## Resultado de la suite completa

(se completa al cerrar)
