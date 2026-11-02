# Fase 5c · Ajustes de herramientas y despliegue

Rama `feat/fase5c-ajustes`, desde `feat/fase5c-herramientas` (`1711b56`).
Tres puntos, tres commits. Sin editar `config/quickshell/` ni usar vin.py.

1. **Git**: `diff --base RAMA` compara desde la base de fusión con HEAD e incluye
   lo commiteado y el árbol actual; con `--staged`, el índice. Mismo JSON, tachado,
   binarios y límite de 2.000 líneas que antes. `status --base` permite que Gate y
   Revisión detecten ese soporte, según el contrato de Claude.
   `merge-check RAMA` y `merge-check --base RAMA` devuelven
   `{ok:true,conflicts:[rutas]}`; conflictos previstos no son errores de la CLI.
   Usa [git merge-tree](https://git-scm.com/docs/git-merge-tree), sin checkout ni
   cambios de índice, refs o archivos. Los objetos del resultado van a un temporal;
   Git puede refrescar el mtime de objetos existentes al reutilizarlos.
   La **066** renueva el motor copiado con respaldo, sin paquetes nuevos.
2. **Migración 065**: manifiesto de 20 QML/qmldir nuevos o cambiados en la rama de
   Claude, con `backup_copy`, copia/enlace, idempotencia y DRY_RUN=1/true.
   Comprueba todos los archivos antes de desplegar: **en esta rama sale 10 hasta
   fusionar `feat/fase5c-pantallas`**, porque aquí faltan sus QML. No copia archivos
   antiguos sobre una interfaz más nueva. La prueba heredada de 5a se acota a
   043–054; las migraciones posteriores tienen sus pruebas de fase. Después de fusionar, aplicar update y
   reiniciar Quickshell para registrar los tipos nuevos. No reinicia la sesión.
3. **Dry-run**: el bloque final de `tests/run-all.sh` llama a
   `tests/install-dry-run.py`. HOME, CONFIG, STATE, DATA, CACHE y RUNTIME son
   temporales. Compara contenidos, enlaces, modos y mtime de todo el entorno y
   conserva el control de git status; no ignora logs ni actividad. Las escrituras
   del escritorio fuera del entorno temporal no producen falsos positivos.

## Verificación

- 19 pruebas de Git: ramas divergentes, commits/índice/árbol, renombres y borrados,
  rutas Unicode con tabulador/salto de línea, binarios, secretos, recortes, errores,
  worktrees y simulaciones con/sin conflictos que preservan árbol/índice/refs.
- 5 pruebas de la 065 y 4 del comprobador de dry-run, con directorios temporales;
  incluyen respaldo, repetición, fuentes incompletas y actividad externa simulada.
- Instalador real con `python3 tests/install-dry-run.py`: aprobado.
- Suite completa: **TODO EN VERDE**, 220 pruebas unittest, shellcheck,
  Bash/Lua, qmllint, documentación, idempotencia y 62 migraciones en dry-run.
  Log: `/tmp/dragon5c-ajustes-suite-final.log`.

No se ha aplicado la 065 al HOME real ni se ha comprobado visualmente la UI de
Claude. Tras integrar sus QML, Revisión debe incluir cambios commiteados desde la
base y mostrar los conflictos simulados de la rama, sin aplicar una fusión.

Al reanudar hubo objetos vacíos del primer commit propio: se conservaron en
`/tmp/dragon5c-git-recovery-ksqu9040`, se reconstruyó el commit desde los archivos y
`git fsck --no-reflogs` terminó sin errores. No se cambiaron otras ramas.

Reproducir: `python3 -m unittest discover -s tests/git -v`,
`python3 -m unittest discover -s tests/fase5c_ajustes -v`,
`python3 tests/install-dry-run.py` y `./tests/run-all.sh`.
