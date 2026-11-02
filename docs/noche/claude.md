# Diario de la noche · Claude Code

Sesión del 2026-11-01/02. Sin vin.py ni teclas a otras terminales. Capturas solo en local
(`/tmp/claude-1000/.../scratchpad`), nunca en el repo.

## Parte 1 · `feat/fase5e-pulido` (worktree `~/Devs/dragon-5e-pulido`, desde `main` a7b0b69)

### (a) Punto 8: exportación automática de `.dragon/CONTEXT.md`
- `Mem` programa una exportación silenciosa del proyecto tras cada cambio de tarjeta con éxito
  (alta, mover, editar, añadir o marcar criterios). Antirrebote de 400 ms: una ráfaga produce una sola llamada.
- `Mem.exports` guarda la última exportación por proyecto; Ajustes › Taller la muestra (antes era estado local
  de la página, así que ahora también refleja las automáticas).
- Prueba nueva `tests/fase5e/test_autoexport.py` (Quickshell y `dragon-mem` reales, HOME aislado): nada antes del
  primer cambio, mover + criterio = 1 exportación, renombrar = 2.ª; el archivo tiene modo 600, < 4 KB y el
  título y criterio nuevos. Sin el cambio en `Mem.qml` la prueba falla (comprobado).
- Migración `090-pulido-ui.sh` (rango propio 090–099 para 5e; 065/070/080 ya ocupados) redepliega los QML tocados
  en instalaciones por copia.
- No exporta al añadir decisiones: hoy ninguna pantalla crea notas (`note add` solo por CLI).

### (b) CPU en reposo
- Medición en instancia temporal (HOME aislado, Hyprland real), alternando main/rama: **5,9 % → 5,1 %**.
  Detalle y reparto en `docs/handoff-fase-5e-claude.md`.
- Hecho: brillo por uevents (`udevadm monitor`, con sondeo de respaldo) y `Canvas.Immediate` en el núcleo (un
  frame por tic en vez de dos; píxeles idénticos, con prueba).
- No forzado: el < 3 % exige recortar efectos (núcleo «Pensando…» ≈ 2 puntos, dock oculto ≈ 1). Queda como
  decisión del usuario.
- Nota: la ventana «pesada» intermitente de las primeras medidas era la isla con agentes trabajando (pares de
  frames cada ~160 ms), no el sondeo de brillo; lo confirmé al mapear ventanas con `WINID`.

### (c) Pre-auditoría d1–d3 (solo lectura)
- `docs/noche/pre-auditoria-d1d3.md`: 3 hallazgos altos (traversal en la papelera, copiar/mover dentro de sí
  mismo vía enlace, `delete` sin rutas protegidas), 5 medios y 6 bajos; casi todos confirmados con sondas en un
  HOME temporal. Una sonda de `trash restore` dejó un archivo de prueba fuera de su carpeta
  (`/tmp/claude-1000/.../keep`), justo por el fallo 1; lo borré.
- La condición de la parte 2 ya se cumplía al terminar la parte 1 (`ESTADO: COMPLETO`).

## Parte 2 · `feat/fase5d-auditoria` (worktree `~/Devs/dragon-5d-auditoria`, desde `feat/fase5d-archivos-codex` 09b99a7)
- Espera: la 1.ª comprobación ya daba `ESTADO: COMPLETO`; no hizo falta esperar.
- 18 hallazgos corregidos, un commit y una prueba cada uno (`tests/files/test_audit.py`); migración 076.
  Detalle en `docs/handoff-fase-5d-auditoria-claude.md`.
- Incidente: la primera versión de la prueba de rutas protegidas pasaba `/` y `/usr` a `op delete --confirm`; el
  clasificador de permisos la bloqueó antes de ejecutarse (bien hecho: si la protección fallaba, borraba el
  sistema). La rehice: la CLI solo recibe rutas del HOME temporal y las del sistema se comprueban llamando a
  `protected_reason()`.
- La prueba existente `test_d2_cancel_copy_cleans_partial_temp_file` fallaba de vez en cuando: era una carrera
  real (SIGTERM entre `mkstemp` y el registro del temporal). Corregida (hallazgo 16).
- Sin corregir por ser diseño: papelera de HOME frente a `gio trash` (decisión del usuario).

## Parte 3 · `integracion/fase5-final` (worktree `~/Devs/dragon-integracion`, desde `main` a7b0b69)
- Fusiones `--no-ff`: pulido → auditoría → pantallas → migración. Hubo conflictos triviales en `run-all.sh`,
  `modules/core.sh`, `qmldir`, `render-mocks.sh` y `docs/noche/codex.md`; los resolví conservando ambos lados
  (en `render-mocks.sh` la línea de main ya cubría lo que pedía pantallas).
- «Enviar al agente» conectado: `Files.sendToAgent` abre el compositor con un bloque `paths`, con destino en
  el portapapeles. Tiene prueba.
- La 1.ª pasada de `run-all.sh` falló en la prueba de motores: `files_share` y `files_network` importaban
  `socket` solo para `gethostname()`. Corregido con `os.uname().nodename`.
- La 2.ª pasada falló en una prueba de red de pantallas que era intermitente (3 de 6): no esperaba a los
  montajes. Corregida (8 de 8).
- Después, `run-all.sh` pasó **tres veces seguidas**: 138 ✔, 0 ✘, 349 pruebas unittest, ~470 s cada pasada.
