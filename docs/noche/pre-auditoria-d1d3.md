# Pre-auditoría de `dragon-files` d1–d3 (solo lectura)

Rama auditada: `feat/fase5d-herramientas` en `0ce93cf` (`dragon-core/dragon_files.py`, 2331 líneas). No se cambió
nada en esa rama. Las sondas ejecutaron el código del worktree contra un HOME temporal en el scratchpad, con
`PYTHONDONTWRITEBYTECODE=1`. «Confirmado» = reproducido con una sonda; el resto sale de leer el código.

Estos hallazgos se corrigen en la parte 2 (`feat/fase5d-auditoria`), cada uno con su prueba.

## Alta

1. **La papelera acepta `..` codificado y sale de su carpeta (confirmado).**
   `op delete 'trash:///..%2F..%2F..%2Fvictim' --confirm` borra `$XDG_DATA_HOME/../victim`.
   `trash restore 'trash:///..%2F..%2F..%2Fkeep'` mueve un archivo cualquiera: sin `.trashinfo`, el destino
   pasa a ser `$HOME/<nombre>`, que también lleva el `..`. Además, `trash:///` sin nombre apunta a `Trash/files`
   entero.
   - El nombre debe ser un único componente: sin `/` tras decodificar y distinto de `.`, `..` y vacío.
2. **Copiar o mover una carpeta dentro de sí misma a través de un enlace simbólico (confirmado).**
   `check_not_inside` compara con `abspath`, no con `realpath`.
   - `op copy ~/a --dest ~/enlace-a-a` recurre ~1000 niveles hasta `RecursionError`. Deja 997 carpetas
     anidadas y escribe un traceback en vez de JSON.
   - `op move`: `os.replace` da `EINVAL` y el código recurre a copiar con el mismo resultado. Con un árbol grande
     puede llenar el disco. Si la copia llegara a terminar, borraría el origen.
3. **`op delete --confirm` no protege nada (confirmado).** Con `--confirm` borra `$HOME`, `/`, `~/.config`… sin
   preguntar más. La confirmación de la UI es la única barrera.
   - Falta una lista de rutas que nunca se borran, como la que el plan ya pide para Samba.

## Media

4. **Carreras al resolver conflictos.** `resolve_conflict` mira `lexists` y bastante después la copia termina en
   `os.replace`, que pisa sin avisar. Un archivo que aparezca entre medias se sobrescribe aunque la política sea
   `skip`, `rename` o `ask`.
   - Lo mismo en `move` (`os.replace`) y en `rename` (comprueba y luego reemplaza).
   - Dos copias en paralelo con `rename` pueden elegir el mismo `nombre (1)`.
   - Hace falta publicar con «no reemplazar»: `os.link` + `unlink` del temporal, o `renameat2(RENAME_NOREPLACE)`.
5. **Mover entre sistemas de archivos.** `except OSError` recurre a copiar y borrar ante *cualquier* error, no
   solo `EXDEV` (por ejemplo `EACCES` o `EINVAL`, el caso 2).
   - Con `overwrite`, el destino se borra **antes** de saber si el movimiento saldrá bien: si falla la copia,
     se pierde el destino.
   - En la papelera pasa lo mismo al restaurar con `overwrite`.
6. **Copiar una FIFO o un dispositivo se cuelga (confirmado: `timeout` a los 4 s).** `copy_single_file` hace
   `open(src, 'rb')` sobre cualquier tipo de archivo. Debe rechazar o recrear lo que no sea archivo normal,
   carpeta o enlace.
7. **Papelera entre sistemas de archivos (confirmado con `/dev/shm`).**
   - `trash_put_one` hace `shutil.move` a la papelera de `$HOME`, que copia el archivo entero a la partición
     de inicio, sin progreso.
   - El plan pide la papelera estándar (`gio trash`, que usa `$topdir/.Trash-$uid`).
8. **Sondeo con el explorador abierto.**
   - `watch` recorre la carpeta cada segundo aunque `inotifywait` funcione.
   - `devices --watch` ejecuta `lsblk` (y `gio mount -l`) **cada segundo** aunque `udevadm monitor` esté
     activo. Va contra el principio «Ligero» y la propia descripción («por eventos»).

## Baja

9. **Nombres que empiezan por `-`.** `op rename … --name -foo` falla con `expected one argument` (confirmado).
   La UI debe pasar `--name=-foo`. Las rutas son siempre absolutas, así que no hay riesgo de inyectar opciones.
10. **Nombres largos.** El temporal `.dragon-part-<nombre>-XXXX` pasa de 255 bytes: copiar un archivo de 250
    caracteres da `File name too long` (confirmado).
11. **Errores no previstos.** `RecursionError` y similares no se capturan: salen como traceback, no como JSON
    `{ok:false}`.
12. **Miniaturas con `ffmpeg` sobre imágenes.** Se lanza con `-i <archivo>` sin fijar el formato. Un «.png» que
    en realidad sea una lista HLS/concat puede hacer que `ffmpeg` lea otros archivos locales y los pinte en la
    miniatura. El impacto es local (lo ve el mismo usuario), pero conviene no usar `ffmpeg` para imágenes o
    fijar `-f image2`.
13. **`open-with --app ../../x`.** El id se une a cada directorio de aplicaciones sin validarlo y puede escapar
    de ellos. Quien llama es la UI: riesgo bajo.
14. **`trash restore` sin validar `Path=`.** Un valor relativo se resuelve contra el directorio actual.

## Lo que está bien

- **`unlock`:** la contraseña llega por stdin y pasa a `udisksctl --key-file /dev/stdin`. Nunca va en argv,
  entorno ni salida.
- **Dispositivos:** `_resolve_block_dev` impide salir de `/dev/`, y los comandos se lanzan sin shell
  (listas de argumentos).
- **Borrado de carpetas:** `rmtree` es seguro frente a enlaces simbólicos, y sobrescribir un enlace reemplaza
  el enlace, no su destino.
- **Nombres con saltos de línea:** salen bien escapados en JSON, en el progreso y en `.trashinfo` (`%0A`).
- **Archivos temporales:** las miniaturas y los temporales de copia se crean con `mkstemp` y modo 600.
