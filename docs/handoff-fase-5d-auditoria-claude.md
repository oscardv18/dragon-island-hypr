# Fase 5d · auditoría de `dragon-files` (Claude Code)

Rama `feat/fase5d-auditoria`, desde `feat/fase5d-archivos-codex` (`09b99a7`), que ya contiene d1–d8. 2026-11-02.
Un commit por hallazgo, cada uno con su prueba en `tests/files/test_audit.py`. Migración **076** (redespliega
los motores en instalaciones por copia). Antes de corregir: `docs/noche/pre-auditoria-d1d3.md` (rama
`feat/fase5e-pulido`). Todas las pruebas usan un HOME temporal. Las operaciones destructivas solo reciben
rutas de ese HOME; las rutas del sistema se comprueban llamando a la función de protección, sin borrar nada.

## Corregido

| # | Área | Problema | Ahora |
|---|---|---|---|
| 1 | papelera | `trash:///..%2F..%2Fx` borraba (`op delete`) o movía (`trash restore`) archivos fuera de la papelera; `trash:///` apuntaba a toda la carpeta | el nombre decodificado es un único componente; todo se valida antes de tocar nada |
| 2 | copiar/mover | una carpeta dentro de sí misma a través de un enlace: unos 1000 niveles de recursión y traceback | `realpath`; `invalid_dest` |
| 3 | borrar | `delete --confirm` borraba `$HOME`, `/`, `~/.config`… | `protected_path` para `/`, el sistema, HOME y sus ancestros, `~/.config`, `~/.local`, `~/.ssh`, `~/.gnupg` y puntos de montaje (en delete, trash y move) |
| 4 | carreras | el conflicto se miraba al principio y `os.replace` publicaba al final: pisaba lo creado entre medias aunque la política fuera skip, rename o ask | `renameat2(RENAME_NOREPLACE)` (con respaldo `link`+`unlink`) y `mkdir`; si el nombre aparece, se vuelve a aplicar la política. Restaurar ya no usa `shutil.move` (que metía el elemento *dentro* de una carpeta con ese nombre) |
| 5 | entre discos | cualquier error de rename caía a copiar y borrar; con overwrite el destino se borraba antes de saber si saldría | solo `EXDEV` copia, a un temporal oculto que se publica al final; el destino antiguo se aparta y se borra tras el éxito o vuelve a su sitio |
| 6 | copiar | una FIFO o un dispositivo colgaban la copia | `special_file` al instante |
| 7 | papelera | desde otro disco: `shutil.move` sin mirar el espacio y con carpetas a medias en `Trash/files` si fallaba | espacio comprobado, copia por temporal, solo con `EXDEV` |
| 8 | ligereza | `watch` releía la carpeta y `devices --watch` lanzaba `lsblk`+`gio` cada segundo aunque hubiera inotify o udev | solo tras un evento (con relectura cada 10 s para GVFS/MTP); sin eventos sigue el sondeo de 1 s |
| 9 | nombres | `--name -borrador` → «expected one argument» (la UI pasa el valor aparte) | las opciones de texto libre se unen a su valor si empieza por guion; pruebas con saltos de línea en ls, copia, papelera y restauración |
| 10 | nombres | nombres de más de ~230 bytes: el temporal superaba 255 | el temporal ya no lleva el nombre |
| 11 | errores | `RecursionError` y otros salían como traceback | `internal_error` en JSON, sin repetir el texto de la excepción, y limpieza de temporales |
| 12 | miniaturas | `ffmpeg` sin formato fijado: un «.png» con una lista HLS/concat podía leer otros archivos locales | `-f image2` para imágenes y lista blanca de contenedores con `-protocol_whitelist file` para vídeo |
| 13 | open-with | `--app ../../x` ejecutaba un `.desktop` de cualquier sitio | solo ids simples |
| 14 | papelera | `Path=` relativo en `.trashinfo` se restauraba contra el directorio actual | vuelve a `HOME/<nombre>` |
| 15 | extracción | publicaba con `os.rename` (pisaba lo aparecido entre medias; con overwrite borraba antes de mover) | `move_item`: error `conflict` o apartar y reponer |
| 16 | cancelar | un SIGTERM entre `mkstemp` y su registro dejaba `.dragon-part` (la prueba existente de cancelación fallaba de vez en cuando) | el nombre se registra antes de crearlo; cancelar un move con overwrite repone el destino apartado |
| 17 | crear ZIP | una FIFO dentro de la selección colgaba `zipfile` | `special_file` |
| 18 | Samba | solo una lista fija de carpetas sensibles: `~/.password-store`, `~/.mozilla`, `~/.aws`, `~/.var`… se podían compartir | ningún componente oculto por debajo de HOME. Invitados apagados salvo `--guest` (con prueba) |

## Revisado y correcto (sin cambios)

- **Extracción segura (d4):**
  - Siempre en `.dragon-extract-*` con una copia inmutable del comprimido.
  - Rutas sin `/` inicial, `..`, `\`, letras de unidad ni controles. Sin enlaces duros, dispositivos ni
    entradas que atraviesen un enlace o archivo. Los enlaces se resuelven contra el árbol final y los enlaces
    ya existentes.
  - Setuid, setgid y sticky se quitan. Espacio comprobado; bomba = > 2 GiB y ratio > 200 (pide
    `--confirm-bomb`); tope de 100 000 entradas; el tamaño real nunca supera el declarado.
  - La batería existente (zip-slip, escape por enlace, setuid, bomba pequeña, sin espacio, cancelación)
    sigue en verde.
- **Contraseñas:**
  - Siempre por stdin: `unlock` → `udisksctl --key-file /dev/stdin`; extracción → libarchive en memoria o `7z`
    por stdin; red → respuestas a `gio mount` por stdin; llavero → `secret-tool store` por stdin.
  - Nunca en argv, entorno, JSON ni archivos. Las URI con contraseña se rechazan y los errores son genéricos.
  - En la UI (rama de pantallas) van por `input` del proceso, y `FileOps` lo vacía al arrancar la tarea.
- **Dispositivos:** sin salir de `/dev/` y sin shell.
- **Gestor predeterminado:** reversible (`--restore-default`), con confirmación y sin tocar Dolphin.

## Sin corregir (decisiones o límites)

1. **Papelera de HOME frente a `gio trash`.** El plan pide la papelera estándar con `gio`, que para otros discos
   usa `$topdir/.Trash-$uid`. Cambiarlo obliga a rehacer también el listado y la restauración, que solo leen
   la papelera de HOME: es un cambio de diseño. Hoy se copia a HOME, con espacio comprobado. **Decisión del
   usuario.**
2. **Copiar una carpeta que contiene una FIFO** deja en el destino la parte ya copiada (el movimiento no, porque
   usa un temporal). Es baja: es una copia, el origen está intacto.
3. **Un `.gz` de un solo archivo** (sin tar) no declara tamaño y la extracción lo rechaza como «tamaño real
   mayor que el declarado». Es una limitación funcional, no de seguridad.
4. **`7z` cifrado con `*`, `?` o `[` en los nombres:** `-i!` los trata como comodines. El tamaño declarado lo
   detecta y falla, pero sin ese error no se puede extraer.
5. **Samba «solo red local»:** `net usershare` no admite `hosts allow`. La herramienta no toca el cortafuegos y
   explica el comando (`ufw` con la subred). Está documentado en la respuesta de `share enable`.
6. **La extracción copia el comprimido** dentro del destino antes de leerlo, así que ocupa el doble de espacio
   mientras dura. Es una decisión de diseño de Codex (instantánea inmutable).
