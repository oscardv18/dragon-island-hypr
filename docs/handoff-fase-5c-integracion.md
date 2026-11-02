# Fase 5c · Integración — `fix/integracion-5c`
Causa: el fallo no venía de `dragon-gate` (la prueba sigue usando el falso y el real cumple §5.4); el `dragon-git` real ya trae `status --base` y `merge-check` (ajustes de 5c), así que «conflictos» sale `ok` y no `unknown`, y el paso 7 esperaba los modos degradados para siempre.
Arreglo: la prueba comprueba ahora el soporte real (todas las puertas en verde ⇒ `ready`) y un caso aparte con un `dragon-git` antiguo simulado mantiene cubierta la degradación (`SIN COMPROBAR` ⇒ `needsConfirm`).
