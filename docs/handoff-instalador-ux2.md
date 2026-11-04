# Handoff instalador: UX2 (fallos no se disfrazan de éxito)

Fecha: 2026-11-04. Rama única: `installer`. Etiqueta: `instalador-ux2`. Sin otras ramas, worktrees, clones ni PR; no se tocó
`~/Devs/dragon-island-hypr`; sin `vin.py`. No se ejecutó ninguna instalación real aquí (comandos falsos y pseudo-terminales).

## Causa: lo que encontré y lo que NO pude reproducir

La captura y el informe de la VM no llegaron en el mensaje, así que partí del código y de las tres variantes pedidas
(paru que pide la contraseña en `/dev/tty`, paru que sale con error, paru que no existe) en un pty con comandos falsos.

**Encontrado y confirmado:**

1. **Los números mentían.** El recuadro contaba como «instalados» todo paquete que seguía en estado *a instalar* y solo marcaba problema
   si el motor lo había comprobado. Con paru ausente, con paru saliendo con 0 sin instalar o con una contraseña que fallaba, el resultado era
   «N instalados · 0 con problema». Eso coincide con el «92 ya estaban · 7 instalados · 0 con problema» de la VM mientras los AUR no estaban.
2. **La segunda contraseña (causa probable).** El mantenimiento de `sudo` corría con `stdin` en `/dev/null`. `sudo` guarda un ticket por terminal,
   así que ese bucle renovaba otro ticket y el del usuario caducaba durante una compilación larga: paru lo volvía a pedir a mitad del AUR.
   Ahora el bucle usa `/dev/tty` y `sudo_refresh` renueva (en silencio mientras sea válido) antes de cada paso largo.
3. **Dentro de la TUI no se veía qué pedía paru.** La salida iba a una tubería y la pantalla alterna tapaba el prompt. `run_tty` ahora retira la TUI
   (sale de la pantalla alterna), deja el terminal al comando y la recupera con el estado de las fases intacto.
4. **«?» en los módulos.** Solo puede aparecer si el bucle de Despliegue no se ejecutó (`RESULT` vacío). **No pude reproducir ese salto** en
   ninguna de las tres variantes: en todas, los módulos se ejecutaron. No tengo evidencia de qué lo provocó en la VM. En vez de adivinar:
   el resumen ya no puede imprimir «?» (ok · con avisos · fallido · omitido con razón), una fase que no llegó a ejecutarse deja el recuadro en
   «INCOMPLETA», y cualquier salida inesperada imprime dónde se detuvo y cómo reintentar. Si vuelve a ocurrir, `~/dragon-informe.txt` trae
   la fase y el paso. **Es lo primero que hay que mirar en la VM.**
5. Un ruido real que hubiera ensuciado la salida: `tui_size` disparaba el trap ERR desde una sustitución de procesos sin terminal.

## Qué se corrigió (por tarea)

- **T2** `lib/prepare.sh`: `sudo_start` (mantenimiento en el tty real), `sudo_refresh`, `run_tty`. La contraseña se pide una vez al empezar.
- **T3** `install.sh`: fallo de paquetes oficiales → se detiene («La fase de paquetes falló en: <paso> · Causa · ./install.sh continúa donde lo dejó»,
  salida 1, progreso conservado). Un AUR que falla no impide desplegar: queda «INCOMPLETA». Un módulo que falla no detiene a los demás.
  Los resultados nunca van en blanco. Una salida inesperada lo dice.
- **T4** `verify_packages`: tras instalar, `pacman -T` decide qué quedó instalado; cada falta lleva su causa (error de pacman/paru,
  «no hay ayudante AUR», «omitido: --no-sudo»). Un paru que sale con 0 sin instalar cuenta como problema.
- **T5** el recuadro sale del doctor: «INCOMPLETA» + cada ✘ con su `↳ comando`; salida 1. El informe incluye el paso y la cola del registro.
  Títulos y códigos en `docs/INSTALL.md`. Gancho de pruebas `DRAGON_DOCTOR` (script de diagnóstico alternativo).
- **T6** `doctor.sh`: las pistas usan el ayudante detectado (`paru` en CachyOS).
- **T7** `modules/core.sh` `core_quickshell_reload`: fuera de Hyprland no arranca nada; dentro, reinicia el Quickshell que ya corre.
  `doctor.sh` fuera de Hyprland no marca Quickshell/IPC/llavero como fallo («cierra sesión y entra en Hyprland»); pipewire/wireplumber valen activos o habilitados.

## Pruebas

`tests/installer_ux/test_ux2.py` (14): `ParuCases` (contraseña en el terminal con comprobación de que la TUI cedió la pantalla y volvió; paru con error;
paru ausente e imposible de construir; paru que sale con 0 sin instalar), `Summary` (fallo oficial se detiene antes de los módulos; doctor con fallos →
«incomplete» con los comandos; ejecución limpia → exit 0 sin «?»; sin «?» en el código), `DoctorHints`, `QuickshellReload` (3 casos).
`tests/installer_ux/ptyutil.py`: pty que escribe respuestas cuando aparece un texto. El sistema falso suma `FAKE_PARU_MODE=tty|fail|noop`,
`FAKE_MAKEPKG_NOHELPER`, `FAKE_QS_RUNNING`. Ajustados: el test de informe (un fallo oficial ahora sale con 1) y el de proveedores (extrae desde `# pkg_failure_cause` hasta `# verify_packages`).
Suite completa: ver abajo.

## Migraciones

Ninguna: todo son scripts que se ejecutan desde el repositorio. `docs/HANDOFF.md` no se tocó.

## Qué queda por probar en la VM

1. `./install.sh` otra vez en la VM: ¿se pide la contraseña UNA vez y paru no la repite durante las compilaciones largas? (si `Defaults timestamp_timeout` es 0 en CachyOS, `sudo_refresh` la pedirá en el terminal, con la TUI retirada).
2. Mientras compila un AUR se ve la salida de paru en el terminal normal y, al terminar, vuelve la TUI con las fases.
3. Con los AUR que fallen: recuadro «INCOMPLETA», causa por paquete y salida 1; `./install.sh` otra vez los reintenta sin repetir la actualización.
4. Si vuelven a salir módulos sin resultado: pasar `~/dragon-informe.txt` (fase y paso) — era el síntoma no reproducido.
5. Dentro de Hyprland tras la instalación: `./doctor.sh` completo (IPC shell/lock); fuera, solo la indicación de entrar en la sesión.
6. SDDM habilitado (`systemctl is-enabled sddm`), bluetooth, power-profiles-daemon, pipewire, wireplumber y el llavero tras un reinicio.

## Decisiones

- Los AUR fallidos no bloquean el despliegue (los módulos son configuración y siguen siendo útiles); los oficiales sí detienen, porque el sistema quedaría a medias.
- `--no-sudo`: lo omitido figura como «omitido» (estado «con avisos», salida 0), no como fallo.

## Resultado de la suite completa

(se completa al cerrar)
