# Handoff instalador: I1 / I2

Fecha: 2026-11-02. Rama única: `installer`, carpeta `dragon-installer`.
No se crearon ramas, worktrees, clones ni PR. No se ejecutó el instalador real,
actualizador, sudo, recargas ni cambios sobre `~/Devs/dragon-island-hypr`.
Al inicio había cambios sin commit en perfiles, tabla y pruebas: se revisaron e
integraron. `/status` no está expuesto como herramienta en esta sesión; sí se
comprobaron directorio, rama y estado de Git al empezar.

## Entregado

- `packages/profiles.json`: perfiles predeterminados base, keyring, taller,
  archivos y editor; login, boot y mis-apps separados y desactivados por defecto.
  `herdr` es opt-in; seahorse, samba y python-gobject constan como opcionales
  donde corresponde. Las dependencias obligatorias existentes, como PyGObject
  del portal, permanecen en base. Los nombres se deduplican al construir el plan;
  cada paquete conserva todos sus perfiles propietarios. Brave queda fuera de
  base y solo aparece en el extras legado, opt-in. Taller agrupa docker,
  docker-compose, docker-buildx, lazygit y lazydocker.
- `packages/base.txt` contiene solo los prerrequisitos manuales comunes y el
  manifiesto la referencia. `doctor.sh --pre` imprime el comando exacto, conserva
  paru/yay y deriva las cabeceras de pkgbase. Compara las rutas del paquete kernel
  instalado para detectar un reinicio pendiente; si falta pkgbase no adivina.
  El ayudante solo entra en el comando pacman cuando `pacman -Si` lo encuentra;
  en otro caso indica la instalación manual desde AUR.
- Tabla de `pre-instalation.md` regenerada con `scripts/gen-package-table.sh`:
  una fila por paquete, mostrando todos los perfiles y los extras legados.
- `lib/preflight.sh` expone `preflight`; el motor Python comparte las lecturas de
  perfiles y prerrequisitos. La entrada `install.sh --check` se despacha antes
  de crear estado/logs, cargar módulos o dibujar la TUI.
- Se comprueban distro/kernel/cabeceras/DKMS, escritorios y Noctalia, KWallet y
  dueño actual de secretos, fish y sobrantes de CachyOS, metadatos oficiales/AUR,
  conflictos en ambos sentidos y por capacidades/versiones, reemplazos,
  dependencias de la simulación pacman, ampliación de compilaciones AUR,
  espacio/red/reloj/sudo/GPU, gestores de acceso y sockets Docker/Podman.
  Se enumeran configuraciones/instantáneas existentes y paquetes explícitos;
  crear la instantánea y guardar la lista corresponde a I4.

## Contrato para I3 / I4

```sh
./doctor.sh --pre
./install.sh --check
./install.sh --check --json
./install.sh --check --profiles base,keyring,taller,archivos,editor --json
./install.sh --check --modules core,editor --json
./install.sh --dry-run --yes
```

`--profiles` y `--json` requieren `--check`; `--profiles` y `--modules` se excluyen
entre sí. Salidas: **0** sin bloqueos (puede haber avisos), **1** con bloqueos,
**2** selección/banderas inválidas. Texto lineal o un documento JSON, sin ANSI.

JSON `schema: 1`: `read_only`, `profiles`, `packages`, `checks`, `blocked`.
Cada check tiene `id`, `level` (`bloqueante`, `aviso`, `informacion`), `message`,
`evidence`, `remedy`. Cada paquete incluye nombre, versión, repositorio efectivo,
origen, perfiles, conflictos, reemplazos, capacidades, dependencias y estado
`installed`/`change`/`install` con `installed_version`. Las dependencias añadidas
por `pacman -Sp` llevan perfil `dependency`. Si falta metadata, se informa un
bloqueo, no se inventa un paquete ni se actualizan bases de datos.

El perfil base agrupa las listas de core/shell/theme/plugins; `--modules` en
`--check` traduce a perfiles, por lo que seleccionar uno de esos módulos incorpora
base completo. La selección explícita de mis-apps se hace con `--profiles mis-apps`.

La TUI y el flujo legado de aplicación permanecen sin cambios. I3 debe consumir
el manifiesto y el JSON, unificar selección/plan/aplicación y ejecutar este
preflight antes de escribir estado. Que keyring sea predeterminado en el
manifiesto **no activa PAM** en el flujo legado. Tampoco hay módulos nuevos que
apliquen Taller/Archivos en este tramo. Mantener las confirmaciones de PAM,
Docker, herdr, chsh, login y boot pertenece a I3/I4.

La comprobación no autentica sudo: informa disponibilidad/grupos; los permisos
sudoers efectivos se validarán al aplicar. Busctl enumera el bus, sin activar el
servicio. KWallet instalado con dueño GNOME no bloquea Plasma; un dueño activo
distinto con GNOME Keyring seleccionado sí bloquea. La compilación/ABI exacto
de plugins se avisa y queda por verificar dentro de la sesión Hyprland.
AUR RPC no sustituye revisar PKGBUILD ni resuelve recursivamente su compilación:
las dependencias aún fuera del plan quedan avisadas antes de confirmar.

No hay migración nueva: solo se añadieron consultas y manifiestos del instalador;
no se cambió configuración ni despliegue de sistemas instalados. La 170 queda
libre. Cualquier despliegue posterior debe usar migraciones desde la 170,
idempotentes, con `backup_copy`, `DRY_RUN` y `ASSUME_YES`.

## dragon-wifi

No estaba ni en `~/Descargas/dragon-wifi` ni en `~/Downloads/dragon-wifi`.
Se documentó en `docs/INSTALL.md`. Pendiente copiar el original a `bin/`, sin
cambiar lógica, desplegar/retirar mediante core, probar con nmcli falso y añadir
la migración correspondiente. No se creó un sustituto.

## Verificación

- 89 nombres oficiales predeterminados validados individualmente con
  `pacman -Si`; también seahorse, samba, python-gobject, prerrequisitos y sddm.
- Ocho paquetes AUR predeterminados consultados mediante AUR RPC en el preflight
  real. La resolución predeterminada produjo 99 paquetes incluyendo dependencias.
- Preflight real de Taller: salida 0. Perfiles predeterminados: salida 1 por
  `nodejs` / `nodejs-lts-krypton` y `rust` / `rustup` presentes en esta máquina.
  Solo se reportaron; no se retiraron ni sustituyeron proveedores del usuario.
  I3 debe presentar una selección compatible antes de aplicar y preservar los
  proveedores existentes cuando corresponda.
- 43 pruebas I1/I2: 4 de perfiles, 5 de prerrequisitos, 34 de preflight.
  Pacman, AUR y busctl simulados; casos de cada conflicto de la sección 2,
  versiones/capacidades, dependencias, sockets, DKMS, errores y selección inválida.
  Pruebas de ejecutables con PATH falso y HOME/XDG aislados, dos pasadas de
  `--check` y `--dry-run`; contenido, permisos, fechas y Git permanecen iguales.
  La telemetría de espacio libre puede variar sin que se haya modificado nada.
- `shellcheck -x`, sintaxis Bash, tabla generada y `git diff --check` limpios.
- Suite completa `tests/run-all.sh`: ejecutada **una sola vez**. Todos los bloques
  pasaron excepto un timeout previo de Kanban en `test_wip_criteria_and_stats`
  (`tests/fase5c/test_services.py`, fase 3). Se repitió **solo** el bloque afectado:
  sus 14 pruebas pasaron en 21,955 s, incluido el caso del timeout, sin cambiar
  código ni límites. Queda registrada esta intermitencia; no se presenta la
  primera ejecución como una pasada limpia. Registro de la repetición:
  `/tmp/dragon-installer-i2-fase5c-repeat-20261102.log`.
  Registro local: `/tmp/dragon-installer-i2-suite-20261102.log`.

## Pendiente en VM CachyOS

Probar una instalación sin escritorio y otra con Noctalia/KWallet/Plasma; verificar
repositorios v3/v4, ayudante incluido y versiones reales de paquetes. Probar un
reinicio pendiente tras actualizar kernel y DKMS con cabeceras ausentes/distintas.
Comprobar el dueño real de secretos dentro de cada sesión, los sockets y múltiples
gestores de acceso; revisar snapper/timeshift con permisos reales. Medir el plan
AUR y revisar PKGBUILD/dependencias. Probar instalación, servicios, instantánea,
respaldo/restauración y segunda ejecución cuando I3/I4 estén integrados.

No se cambió ni se validó visualmente la TUI. En terminal debe verse un informe
lineal con nivel, evidencia y salida propuesta por comprobación; ante bloqueos
termina con `BLOQUEADO` y código 1. Ninguna pantalla gráfica se da por verificada.
