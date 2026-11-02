# Fase 5e · pulido (Claude Code)

Rama `feat/fase5e-pulido`, desde `main` (a7b0b69). 2026-11-01/02. Migración propia: **090** (rango 090–099).

## (a) Punto 8: `.dragon/CONTEXT.md` automático
- `Mem` exporta en silencio, con antirrebote de 400 ms, tras añadir, mover o editar una tarjeta o sus criterios.
  Una ráfaga de cambios produce una sola llamada a `dragon-mem export`.
- `Mem.exports {slug: {path, bytes, at}}` guarda la última exportación; Ajustes › Taller la muestra (antes solo
  veía las manuales).
- Prueba: `tests/fase5e/test_autoexport.py`. No exporta al añadir decisiones: ninguna pantalla crea notas todavía.

## (b) CPU en reposo de Quickshell

**Cómo se midió.** Instancia temporal de `qs` (HOME aislado con copia de `settings.json`, Hyprland real, 20 s de
calentamiento, mediana de 4–5 muestras de 4 s de `/proc/<pid>/stat`), alternando configuraciones para que la deriva
del sistema afecte a las dos por igual. Mismas condiciones en las dos: agentes de herdr trabajando (esta noche
había otros agentes en marcha) y sin música. Frames por ventana con `qt.scenegraph.time.renderloop` y perfil de
QML con `qmlprofiler` contra `qs --debug`. La sesión del usuario no se tocó.

**Antes → después: 5,9 % → 5,1 % de un núcleo** (cuatro pares alternos: 5,75/5,50 · 6,00/5,00 · 5,50/5,25 · 6,00/5,00).
El objetivo de < 3 % **no se alcanza sin quitar efectos**, así que no se forzó.

Cambios (sin pérdida visual):
1. **Brillo por eventos.** El kernel emite un uevent en cada escritura de `brightness`. Un `udevadm monitor`
   en espera sustituye al sondeo de 300 ms y, si `udevadm` falta o muere, vuelve el sondeo. El OSD de brillo
   ahora reacciona al instante. Ahorro ≈ 0,3 puntos.
2. **Núcleo con `Canvas.Immediate`.** Con `Cooperative` cada tic producía dos frames de la ventana (pintar y
   luego subir la textura); con `Immediate`, uno. La isla con «Pensando…» pasa de ~13 a ~7 frames/s y Hyprland
   recompone la mitad de veces. Prueba de píxeles idénticos en `tests/fase5e/test_core_render.py`. Cambiado
   en `shared/neural-core` y sincronizado (también en la copia de SDDM: se aplica con el próximo
   `dragon-sddm-sync`, que pide sudo). Ahorro ≈ 0,4 puntos.

Reparto de lo que queda (medido quitando cada cosa en la instancia temporal):

| Fuente | Coste aprox. | Por qué sigue |
|---|---|---|
| Mininúcleo «Pensando…» de la isla (agentes trabajando, 6 fps) | ~2 puntos | Es el efecto; ya se bajó de 12 a 6 fps en el pulido anterior. Pintar el `Canvas` en JS es lo caro, no el frame |
| Respiración de los puntos del dock oculto (8 fps) | ~1 punto | Con 4–5 fps el escalón de opacidad (hasta 0,13) se notaría |
| Servicios sin ventanas (SysStats, Bloq Mayús, Hyprland…) | ~0,75 | El sondeo de Bloq Mayús (3 LED × 4/s) no tiene eventos en el kernel |
| Barra (anillos CPU/RAM animados cada 2 s, reloj) | ~0,5–0,75 | Es el efecto |

Si se quiere bajar del 3 % hay que elegir: (i) núcleo «Pensando…» a 3 fps (`fps: 3` → doble = 6; poner
`fps: 2` daría 4), (ii) dock oculto a 5 fps, o (iii) usar «Movimiento reducido» (`Settings.calmMotion`), que ya
apaga los dos. **Decisión del usuario.** Sin agentes trabajando la misma medida da ≈ 3,5–4 %.
