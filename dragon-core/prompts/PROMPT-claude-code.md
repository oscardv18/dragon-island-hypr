# Tarea: integrar "dragon-core" (login SDDM + bloqueo Quickshell) en dragon-island

Lee primero los skills `dragon-island`, `quickshell` y `hyprland-plugins`.
En la raíz del repo hay una carpeta `dragon-core/` con código YA ESCRITO Y PROBADO (renderizado
offscreen con mocks, 0 warnings QML). Tu trabajo es integrarlo, no reescribirlo. Cambios visuales: solo si algo falla en mi máquina.

## Reglas
- Nada de sudo sin preguntarme. `sddm/install-theme.sh` es interactivo: NUNCA lo ejecutes tú ni desde update.sh sin `gum confirm`.
- No toques /etc ni Plasma. No borres hyprlock: queda de respaldo.
- Nunca pidas ni guardes mi contraseña.

## Qué contiene dragon-core/
| Ruta | Qué es |
|---|---|
| `shared/NeuralCore.qml`, `shared/CoreIcon.qml` | Componentes QtQuick puros (núcleo animado + iconos). Fuente única. |
| `sddm/dragon-core/` | Tema SDDM Qt6 completo (Main.qml, components/, fonts/ Outfit + JetBrains Mono OFL, theme.conf, preview.png) |
| `sddm/install-theme.sh` | `--test` / instalar / `--uninstall`. Detecta SDDM vs Plasma Login Manager. Pregunta antes de cada sudo. |
| `quickshell/modules/lock/Lock.qml` | WlSessionLock + PamContext + IpcHandler `lock` + layout/Bloq Mayús vía hyprctl |
| `quickshell/modules/lock/LockView.qml` | La UI del bloqueo (QtQuick puro) |
| `quickshell/components/` | Copias de shared/ |
| `test/` | Harness PySide6 para renderizar ambos sin Quickshell/SDDM |

## Pasos
1. **Mover al repo**
   - `dragon-core/sddm/` → `sddm/` en la raíz.
   - `dragon-core/quickshell/modules/lock/*` → `config/quickshell/modules/lock/`.
   - `dragon-core/quickshell/components/*` → `config/quickshell/components/` (si ya existe un `CoreIcon.qml` o `NeuralCore.qml`, avísame).
   - `dragon-core/shared/` → `shared/neural-core/`.
   - Añade a update.sh / install.sh un paso que copie `shared/neural-core/*.qml` a los dos destinos, para que no diverjan. Añade una comprobación `diff` en el check de CI o en el dry-run.
2. **shell.qml**: añade `Lock { id: lock }` una sola vez. Conecta `lock.notifCount` al contador de no leídas del servicio `Notifs` (usa el nombre real del miembro). Si ya existe otro `WlSessionLock` o un módulo lock viejo, quítalo; solo puede haber uno.
3. **PAM**: Lock.qml usa `/etc/pam.d/hyprlock` (lo instala hyprlock: `auth include login`) y cae a `login` si no existe. Verifica con `ls /etc/pam.d/hyprlock`. No crees archivos en /etc.
4. **Binds y hypridle**
   - SUPER+L → `qs ipc call lock lock || hyprlock` (si Quickshell no responde, entra hyprlock).
   - hypridle: `lock_cmd = qs ipc call lock lock || hyprlock`, `before_sleep_cmd = loginctl lock-session`, `after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'` (verifica la sintaxis Lua del dpms contra el ejemplo de 0.56.2).
5. **Recuperación**: si `misc.allow_session_lock_restore` existe en 0.56.2 (compruébalo con `hyprctl getoption misc:allow_session_lock_restore`), actívalo en la config Lua. Documenta en HANDOFF.md cómo recuperarse si el bloqueo muere (pantalla roja):
   - Ctrl+Alt+F3 → login.
   - `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'` (verifica la sintaxis).
   - Ctrl+Alt+F1 para volver.
6. **hyprlock de respaldo**: re-tematiza `config/hypr/hyprlock.conf` con la misma paleta (`#05060c`, magenta `#c50ed2`, violeta `#7c3aed`, cian `#00c1e4`, error `#ed254e`), usando `sddm/dragon-core/preview.png` copiado a `config/hypr/assets/core.png` como fondo, y el input field redondeado y de vidrio oscuro. hyprlock no anima: no lo intentes.
7. **update.sh**: migración run-once `2026-10-dragon-core`.
   1. Enlaza los archivos de Quickshell.
   2. Hace `qs ipc call shell ...` / recarga.
   3. Pregunta con gum: «¿Instalar el tema de login dragon-core? (pide sudo)». Si respondo que sí, ejecuta `sddm/install-theme.sh` en primer plano.
   4. `install.sh --dry-run` lo lista sin ejecutarlo.
8. **Pruebas** (reporta cada una):
   - `qs -p config/quickshell` sin errores.
   - `sddm/install-theme.sh --test` (abre el greeter en una ventana, sin sudo).
   - Bloqueo real, una vez que verifiques que `hyprlock` funciona como respaldo. Prueba:
     - contraseña mala: núcleo rojo, sacudida y pista;
     - Bloq Mayús;
     - clic en la etiqueta US/LATAM;
     - con y sin reproductor;
     - contraseña buena: verde y desbloqueo.
   - Con 2 monitores (si hay): el texto se sincroniza y solo el monitor enfocado anima el núcleo.
   - Rendimiento: si el greeter o el bloqueo van lentos, baja `pointCount` (theme.conf / `LockView.pointCount`) a 160.
9. HANDOFF.md: hecho / verificado / no verificado / cómo revertir (`sddm/install-theme.sh --uninstall`).
