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
