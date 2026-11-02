# Informe de la noche · 2026-11-01/02 (Claude Code)

Diario completo: `docs/noche/claude.md`. No usé vin.py ni envié teclas a otras terminales. No subí capturas.
No usé `--force` ni borré ramas ni worktrees.

## Resultado

- **Fusionado en `main` y desplegado.** Etiqueta de vuelta: `pre-fase5-final` (= `a7b0b69`). Merge `f764479`,
  subido a `origin/main` junto con la etiqueta y `integracion/fase5-final`.
- `./update.sh --dry-run` salió limpio, y `./update.sh` terminó con exit 0, `hyprctl configerrors` vacío y
  Quickshell vivo (PID nuevo, la IPC responde, sin errores de QML; solo dos avisos que ya había).
- **Después de fusionar encontré un fallo mío**, así que no volví a tocar `main` y dejé la corrección en la rama
  **`fix/udevadm-huerfano`**:
  - Si Quickshell muere de golpe, el `udevadm monitor` del brillo (cambio de esta noche) queda huérfano. No
    gasta CPU y desaparece con el siguiente cambio de brillo.
  - Con `qs kill` (lo que usa `update.sh`) no pasa: lo comprobé. Mis mediciones dejaron 24 huérfanos; ya los
    he borrado.
  - La rama arregla esto con `setpriv --pdeathsig`, más la prueba y la migración 091. Además corrige una prueba
    intermitente mía (`test_send_to_agent`).
  - `run-all.sh` en esa rama: **TODO EN VERDE** (138 ✔, 0 ✘).
  - **Para fusionarla:** `git merge --no-ff fix/udevadm-huerfano && ./update.sh`.
- **Efecto que no esperaba de `./update.sh`.** Sin terminal entra en modo desatendido (`ASSUME_YES=true`,
  `update.sh:59`). La migración 074 respondió «Sí» y **Archivos Dragon es ahora el gestor de carpetas
  predeterminado**. Antes lo era `kitty-open.desktop`, no Dolphin. Para volver atrás:
  `dragon-files --restore-default`. Ningún paso con sudo se ejecutó: los de SDDM se saltaron.

## Qué se fusionó

`integracion/fase5-final` sale de `main` (a7b0b69). Fusiones `--no-ff`, en este orden:

1. **`feat/fase5e-pulido`** (mía, parte 1):
   - punto 8: `.dragon/CONTEXT.md` se exporta solo al cambiar una tarjeta;
   - CPU en reposo: 5,9 → 5,1 %;
   - pre-auditoría de d1–d3.
2. **`feat/fase5d-auditoria`** (mía, parte 2). Incluye `feat/fase5d-herramientas` (d1–d3) y
   `feat/fase5d-archivos-codex` (d4–d8), más 18 correcciones de seguridad y robustez.
3. **`feat/fase5d-pantallas`**: el explorador (QML).
4. **`feat/fase5d-migracion`**: migración 080, que despliega el explorador y sus reglas de ventana.

### Conflictos (todos triviales; ninguno me obligó a parar)

| Fusión | Archivo | Resolución |
|---|---|---|
| auditoría | `tests/run-all.sh` | se conservan todos los bloques (5c y 5d) |
| auditoría | `modules/core.sh` | las dos listas de `*_setup` se suman: `prompt/gate/tokens_setup` + `files_tools_setup` |
| pantallas | `config/quickshell/services/qmldir` | se conservan todos los bloques (5b, 5c, 5d) |
| pantallas | `tests/qml/render-mocks.sh` | se queda la línea de `main`, que copia todos los `*.qml` y `fixtures`: ya incluye lo que pedía pantallas |
| migración | `docs/noche/codex.md` | se conservan los dos diarios de Codex (ramas A y B), uno tras otro |

`pre-instalation.md` se fusionó sin conflicto.

### Commits propios en la rama de integración

- **«Enviar al agente».** `Files.sendToAgent` abre el compositor del Taller con las rutas como bloque `paths`.
  El destino empieza en el portapapeles y nada sale sin pulsar «Enviar». Tiene prueba.
- **`socket` fuera de `files_share`/`files_network`.** La prueba de motores de `main` prohíbe importarlo, y 5d
  nunca había corrido `run-all.sh`. Se cambió por `os.uname().nodename`.
- **Prueba de red de pantallas.** Era intermitente: esperaba a los equipos pero no a los montajes.

## Resultados

- **`tests/run-all.sh` en `integracion/fase5-final`:** **TODO EN VERDE tres veces seguidas**: 138 ✔, 0 ✘,
  349 pruebas unittest, ~470 s cada pasada. Antes hubo dos pasadas rojas, ya corregidas (ver arriba).
- **Parte 1:**
  - `tests/fase5e/`: exportación automática, brillo por eventos (también sin `udevadm`), núcleo con píxeles
    idénticos y «Enviar al agente».
  - CPU medida alternando `main` y la rama en una instancia temporal: **5,9 % → 5,1 %**. Tras el despliegue,
    el Quickshell real da 4,75–5,75 % con agentes trabajando.
- **Parte 2:**
  - `tests/files/test_audit.py`: 18 hallazgos con prueba; cada una falla sin su corrección (comprobado
    revirtiendo).
  - `tests/files` completo: 6 pasadas seguidas con un único fallo, que era de la prueba (temporización con
    la máquina cargada) y está corregido.

## Hallazgos sin arreglar (decisiones tuyas)

1. **CPU en reposo < 3 %.** Bajó a 5,1 % con agentes trabajando (≈ 3,5–4 % sin agentes). Para bajar más hay
   que recortar efectos:
   - el mininúcleo «Pensando…» cuesta ≈ 2 puntos;
   - la respiración del dock oculto, ≈ 1 punto.

   Opciones en `docs/handoff-fase-5e-claude.md`. «Movimiento reducido» ya apaga los dos.
2. **Papelera de HOME frente a `gio trash`.** El plan pide `gio`. Hoy un archivo de otro disco se copia a la
   papelera de HOME (con espacio comprobado y sin copias a medias). Cambiarlo obliga a rehacer el listado y la
   restauración de la papelera.
3. **Límites menores de dragon-files**, detallados en `docs/handoff-fase-5d-auditoria-claude.md`:
   - copiar una carpeta con una FIFO deja lo ya copiado;
   - un `.gz` sin tar no se extrae;
   - un `7z` cifrado con comodines en los nombres no se extrae;
   - Samba no puede limitarse a la red local desde `usershare`.
4. **Exportación de `CONTEXT.md` al añadir decisiones.** Ninguna pantalla crea notas todavía; cuando exista,
   debe llamar a `Mem.exportContext` como hacen las tarjetas.

## Pasos manuales (necesitan sudo o tu decisión)

1. **SDDM (sudo).** Las migraciones 024, 029 y 033 siguen pendientes, porque necesitan confirmación
   interactiva. En una terminal: `./sddm/install-theme.sh` y después `dragon-sddm-sync`. Así llega también al
   login el `Canvas.Immediate` del núcleo de esta noche.
2. **Samba (si quieres compartir carpetas).** Sigue `docs/FILES-SAMBA.md`: grupo `sambashare`, `usershare` en
   `smb.conf`, `smbpasswd`, `systemctl enable --now smb`, y el cortafuegos con tu subred. Nada de esto se ha
   hecho.
3. **Gestor de carpetas.** Ya apunta a Archivos Dragon (ver arriba). Si prefieres lo de antes:
   `dragon-files --restore-default`.
4. **Fusionar `fix/udevadm-huerfano`** cuando lo revises.
5. **Decidir** la CPU < 3 % y la papelera con `gio` (hallazgos 1 y 2).

## Tus pruebas físicas

No las he podido ver: necesitan tus manos y tus ojos.

**Teclas**
1. `SUPER + E` abre el explorador (antes Dolphin).
2. Dentro del explorador:
   - Flechas, `Intro`, `Retroceso`, `Ctrl+L` (migas editables), `/` (buscar) y `Ctrl+H` (ocultos).
   - Pestañas y selección múltiple con `Ctrl`/`Mayús`.
3. `SUPER + T` (Taller): mueve una tarjeta a «En curso». En menos de un segundo debe cambiar la hora de
   `<repo>/.dragon/CONTEXT.md`, y Ajustes › Taller debe mostrar esa exportación.
4. Teclas de brillo: el OSD debe salir **al instante**, antes tardaba ~300 ms.
5. `Bloq Mayús`: el OSD sigue saliendo (no cambió).

**Arrastre**
1. Archivos entre dos pestañas del explorador. Con un nombre repetido debe preguntar.
2. De una ventana del explorador a otra.
3. A una memoria USB: la píldora de progreso y «Cancelar». Al cancelar no debe quedar ningún `.dragon-part-*`
   en el USB.
4. Un comprimido sobre una carpeta: se extrae con el diálogo.

**Blur y ventana real frente a la maqueta 33**
1. La ventana «Archivos · …» debe abrir flotante, centrada, sin barra de título, de 1226×612, con desenfoque
   nativo y una sola región. Compárala con `docs/design/33-archivos-lista.png` y `-cuadricula.png`:
   - barra lateral (Lugares, Dispositivos con barra de espacio y ⏏, Red, Papelera);
   - migas, pestañas, filas alternas y marca git M/A.
2. Contorno: si el contorno global de ventanas está en «nada», el explorador dibuja sus escuadras; si no, no
   (sin doble borde).
3. Extraer, Red y Compartir frente a `33-archivos-extraer.png`, `-red.png` y `-compartir.png`.
4. «Enviar al agente» (panel derecho o menú contextual): abre el Taller con el compositor y un bloque «Rutas»;
   el destino es el portapapeles y nada se envía hasta pulsar «Enviar».

**Efectos que deben seguir igual tras el ajuste de CPU**
1. Con agentes trabajando, el mininúcleo «Pensando…» de la isla gira igual de suave que antes. El cambio de
   `Canvas.Immediate` no debe notarse.
2. El dock oculto respira, y el núcleo del lanzador y el de la barra (al pasar el ratón) se ven igual.
