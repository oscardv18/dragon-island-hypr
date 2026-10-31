# Registro de actividad

`dragon-activity` es un comando local Python estándar, sin demonio. La interfaz
lo llama a través de servicios. Se instala con core o `040-activity-install.sh`.

```sh
id=$(dragon-activity add --kind command --name 'cargo build' --start "$(date +%s)")
dragon-activity end "$id" --status ok
dragon-activity range --from 1793400000 --to 1793421600 --json
```

- `add --kind agent|command|focus --name TEXTO --start EPOCH [--end EPOCH]
  [--status ok|fail|blocked]` imprime un ID de 12 caracteres hexadecimales.
- `end ID [--status ok|fail]` cierra una entrada abierta. Repetirlo conserva su
  cierre; un ID desconocido sale con 1 y un mensaje en stderr.
- `range --from EPOCH --to EPOCH --json` devuelve exactamente `{"items":[...]}`.
  Cada entrada tiene `id`, `kind`, `name`, `start`, `end`, `status`; los intervalos
  que tocan los extremos también se incluyen. Orden ascendente por `start`, ID en
  empates; `end:null` significa abierta. Epoch acepta segundos enteros o decimales
  finitos. Un rango invertido o argumentos inválidos salen con 2.

Estado: `$XDG_STATE_HOME/dragon-island/activity.jsonl` (por defecto
`~/.local/state/dragon-island/activity.jsonl`), archivo 0600, bloqueo separado
`activity.jsonl.lock`. Cada línea es una entrada completa y la última versión de
un ID prevalece. Las escrituras anexan bajo `flock` y `fsync`; al superar
1 000 000 bytes se compactan atómicamente, deduplicando y conservando entradas que
se solapan con los últimos 30 días. Los datos recientes no tienen un límite de
número de entradas. JSONL corrupto produce error sin sobrescribirlo.

Al leer o escribir, las entradas abiertas de más de 12 h quedan cerradas en
`start + 12 h` con `status:"unknown"`. La consulta persiste estos cierres bajo el
mismo bloqueo; sin estado devuelve `{"items":[]}` sin crear archivos. `status`
predeterminado de `add` es `ok`; una entrada puede estar abierta y `blocked`.

El nombre pasa por el mismo `engine_common.secret_spans` que `dragon-search cmd`
**antes** de recortarse a 80 caracteres. Si detecta secretos se conserva solo el
primer token (`curl`, por ejemplo); si ese token contiene el secreto, se guarda
`[redacted]`. Espacios y saltos se normalizan. No se guarda el comando completo
en ningún archivo auxiliar ni se ejecuta su contenido.

Pruebas: `python3 -B -m unittest discover -s tests/activity -v` con HOME/XDG
temporales. La prueba de rendimiento incluye el proceso CLI completo y una
fixture de 30 días con 6000 entradas; mide la mediana tras calentar, objetivo
<50 ms. El coste crece con el volumen real del JSONL y el tamaño de la respuesta.
