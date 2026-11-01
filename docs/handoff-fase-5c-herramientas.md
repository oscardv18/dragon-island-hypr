# Fase 5c · Herramientas

Rama `feat/fase5c-herramientas`, worktree `/home/oddv/Devs/dragon-5c-herr`,
desde `main` con 5a y 5b. Solo CLI, plantillas, despliegue y pruebas.
`config/quickshell/`, los atajos y `docs/HANDOFF.md` quedan para la rama de UI.

## Resumen corto del plan

- §5.5: compositor determinista, ocho plantillas editables en español, bloques,
  recortes, secretos, estimación de tokens y entrega explícita.
- §5.4: ejecutar el comando de pruebas del proyecto con límites, progreso JSONL,
  cancelación de su grupo y resultado en la tarjeta.
- §4 / punto 8 de 5c: completar métricas de flujo y exportación corta por proyecto.
- §5.6 opcional: consumo de hoy desde registros locales, solo lectura y sin modelos.
- Cada punto tiene su commit, fixtures sintéticos, pruebas y migración. La UI,
  servicios, Kanban y Revisión siguen en la otra rama.

## Contrato para la rama de pantallas

### Prompts

`dragon-prompt templates [--project slug] --json` devuelve integradas y plantillas
SQLite globales y del proyecto. `build --template id|nombre --project slug
[--card AX-1] [--block tipo:arg] [--off id,id] [--stdin] --json` produce una respuesta
JSON única. No envía nada. El nombre de una plantilla del usuario puede reemplazar
una integrada; también se puede seleccionar por su ID numérico de SQLite.

Las plantillas contienen un array de `{id,type,label,arg,enabled}` en `blocks`.
`arg` es texto, por defecto vacío; `enabled` por defecto true. También se aceptan
bloques de cadena `tipo:arg`. `--block` añade bloques con ID `extra-N` (N es la
posición absoluta, desde 1); `--off` usa IDs, no tipos. Las integradas usan IDs
`instruction`, `card`, `criteria`, `paths`, etc. Bloques desactivados no consultan
fuentes externas.

- `card`, `criteria`, `comments`: tarjeta de `--card`, siempre dentro del proyecto.
- `paths`: rutas separadas por saltos de línea; jamás lee su contenido.
- `diff:ruta`: `dragon-git diff` en el worktree de la tarjeta, o en el proyecto;
  hasta 120 líneas, con aviso de cuántas se recortaron. La fuente puede tener su
  propio límite de 2.000 líneas, indicado por separado.
- `log:id`: últimas 200 líneas mediante `dragon-docker logs`; hasta 40 alrededor
  del primer error (10 anteriores cuando hay espacio), con repetidas colapsadas.
- `note:N`, `decisions:N`: últimas N, por defecto 10, máximo 100.
- `commands`: test_cmd y build_cmd; `text:libre`: instrucciones libres.
- `selection:`: texto de stdin solo con `--stdin`; `selection:clipboard` usa
  `wl-paste --no-newline`. No consulta el portapapeles automáticamente.

El texto contiene solo encabezados `## Etiqueta` y bloques, separados por dos
saltos de línea. `tokens=ceil(bytes_utf8/3.8)` (estimación ±20 %), tanto en cada
bloque como en el texto final; los separadores cuentan en el total. Se tacha antes
de contar. Cada bloque devuelve ID, tipo, etiqueta, tokens, enabled, truncated y
redactions. Los bloques sin datos producen texto vacío.

`send --target herdr:id|clipboard|file:ruta --stdin [--no-enter]
[--project slug] [--card AX-1] [--template nombre]` vuelve a tachar y entrega solo
tras esa invocación explícita. Herdr recibe `prompt id --stdin [--no-enter]`;
portapapeles, `wl-copy`; archivo, reemplazo atómico con modo 600 (su carpeta debe
existir). Respuesta: tokens, body_hash SHA256 y redactions. El texto de stdin tiene
límite de 1 MiB. Errores de entrega no registran un prompt_run.

**Ajuste compartido:** `~/.config/dragon-island/settings.json` (respeta
XDG_CONFIG_HOME), clave **`promptHistory`**, booleano. Solo `true` guarda el texto
ya tachado en `prompt_run.body`; ausente, inválido o false deja NULL. Siempre se
registran tokens, fecha, destino y hash. Pasar proyecto, tarjeta y plantilla en
`send` permite atribuir el historial; el CLI no conserva estado del build anterior.
Los umbrales de color y el presupuesto pertenecen a Ajustes/UI, no alteran la CLI.

### Puerta de pruebas

`dragon-gate run --project slug --cwd ruta [--card AX-1] [--timeout 600] --json`
ejecuta exclusivamente el test_cmd ya registrado por el usuario con `bash -lc`.
No recibe comandos nuevos desde la UI. Si falta, devuelve `no_test_cmd` sin lanzar
nada. Para atribución inequívoca, **pasar --card** desde Revisión/Kanban.

Emite `{ok:true,t:"progress",line:...}` por línea y un último
`{ok,t:"done",exit,seconds,tail,card,truncated}`; tail contiene hasta 30 líneas.
Límite total de 1 MiB y de 16 KiB por línea. Colores ANSI eliminados; PEM protegido
como estado multilínea. Timeout entre 0 y 86.400 segundos, por defecto 600.
Timeout, SIGTERM, SIGINT y exceso de salida terminan el grupo completo (TERM y
KILL para supervivientes), incluso con stdout cerrado o hijos en segundo plano.

Salida de proceso 0 solo con pruebas en verde; 1 en fallos, timeout o cancelación;
2 en uso incorrecto. El último JSON incluye el error estructurado cuando falla,
además del exit real de bash (puede ser negativo por señal).

Sin --card, resuelve una única tarjeta doing/review cuyo worktree coincide con cwd;
para cwd del proyecto, una única tarjeta activa sin worktree. Si hay varias,
`ambiguous_card` antes de ejecutar. Sin tarjeta, se permiten pruebas independientes
con `card:null`, sin inventar un evento ajeno. Con tarjeta se registra un evento
`gate`, también al fallar/cancelar: solo ok, exit, seconds y truncated, nunca logs.

### Memoria

`stats flow --project slug --days 30`: medianas de lead y ciclo sobre tarjetas
terminadas en el período; retrabajo por tarjetas devueltas, no por número de
retornos; throughput de siete días; mediana de esperas cerradas en el período.
Sin muestras, medianas null y conteos/porcentaje cero. Ignora fechas futuras y
valores de duración negativos; days debe ser positivo. Los proyectos se aíslan.

`export --project slug [--out ruta]` escribe por reemplazo atómico, modo 600,
menos de 4 KB en UTF-8, con nombre, convenciones, últimas 10 decisiones y tarjeta
actual doing/review con criterios. Los nombres largos tienen presupuesto propio;
se tacha antes de recortar incluso datos antiguos insertados sin filtro.
Por defecto va a `<repo>/.dragon/CONTEXT.md`; el registro del proyecto ya excluye
`.dragon/` localmente en Git. La UI debe invocar export tras cambiar la tarjeta o
una decisión, según el punto 8 del plan; esta rama no añade observadores.
El esquema sigue en versión 1, sin transformar registros existentes.

### Consumo opcional

`dragon-tokens today --json`: Claude `{in,out,cache}`, Codex `{in,out}` o null
por agente si no hay registros reconocibles. No crea base, caché de consumo ni procesos
persistentes. Cuenta el día del calendario local.

Se inspeccionaron solo estructuras reales de `~/.claude/projects/**/*.jsonl` y
`~/.codex/sessions/**/*.jsonl`, sin volcar conversaciones ni copiar datos privados.
Fixtures escritos desde cero en `tests/fixtures/fase5c/`.

Claude: assistant.message.usage, máximos por message.id para no sumar fragmentos
repetidos; cache es creación + lectura, separado de input_tokens. Codex:
event_msg/token_count.info.total_token_usage, diferencias por sesión, con baseline
anterior a medianoche; eventos repetidos no suman, un reinicio inicia otro tramo.
Input incluye caché y output ya incluye razonamiento; no se suman dos veces.
Los transcripts copiados con el mismo ID se deduplican. Respeta CLAUDE_CONFIG_DIR
y CODEX_HOME. JSONL parcial se ignora; info:null de Codex es un evento sin consumo.
Formatos de uso desconocidos devuelven null, nunca un cero inventado.

La lectura real reconoció ambos formatos; el escaneo de todos los registros de
esta máquina tardó ~5,3 s. Es una lectura bajo demanda: el servicio de UI debe
hacerla de forma asíncrona, sin sondeo con el panel cerrado. No se añadieron
presupuesto, tarjeta ni ajustes visuales en esta rama.

## Instalación y migraciones

- **061**: dragon-prompt y plantillas en `$XDG_CONFIG_HOME/dragon-prompt/templates/`.
- **062**: dragon-gate.
- **063**: renueva dragon-mem con flujo/export; conserva DB y esquema.
- **064**: dragon-tokens y dependencias comunes.

Se dejan **057–060 libres** para la UI. `lib/taller-tools.sh` contiene helpers
separados, llamados por `modules/core.sh` en instalaciones nuevas. Motores en
`$XDG_DATA_HOME/dragon-island/engines/`, comandos en `~/.local/bin/`.
Las migraciones usan deploy_item y sus respaldos; idempotentes en copia/enlace,
DRY_RUN=1/true sin escrituras y ASSUME_YES mediante el entorno común. Se parte de
la base 5a/5b instalada (dragon-mem y motores fuente). Sin paquetes nuevos:
Python estándar, bash y wl-clipboard ya forman parte de core.

## Verificación

- `tests/run-all.sh`: **tres ejecuciones consecutivas en verde**, con HOME/XDG
  temporales también para el runner: **424,8 / 359,4 / 356,3 s**. Cada una incluye
  204 pruebas unittest, shellcheck, Bash/Lua, qmllint, servicios reales con mocks,
  60 migraciones sin escrituras en dry-run, documentación e instalación idempotente.
- 12 pruebas de prompts, incluido el conteo de tachados procedentes de Git/Docker
  y la protección de metadatos de plantillas al guardar historial.
- 8 pruebas de gate, 5 de tokens y 18 de memoria (4 nuevas), siempre con HOME/XDG
  temporales; destinos herdr/clipboard, logs/diffs y comandos simulados.
- Mediana de siete arranques fríos: templates **87,7 ms**, build **90,1 ms**;
  stats flow **89,5 ms** y tokens sobre fixtures **60,1 ms**. Objetivo <150 ms.
  Benchmark reproducible: `python3 tests/prompt/bench.py`.
- Logs de las tres pasadas: `/tmp/dragon5c-tools-isolated-{1,2,3}.log`.
- Antes hubo una pasada verde con HOME real y otra con dos fallos ambientales:
  actividad dio 51,6 ms contra su límite de 50 ms, y el control final observó
  escrituras normales de activity.jsonl y su índice de la sesión real. El bloque
  de actividad repetido dio 36,9 ms; en las pasadas aisladas dio 48,9 / 37,9 /
  34,9 ms. No se modificaron el código ni el límite de actividad. Se aisló el HOME
  del runner para evitar atribuir al instalador escrituras del escritorio.
- `hyprctl configerrors` vacío en la sesión real (consulta de solo lectura).
- Sin cambios en `config/quickshell/`; sin despliegue ni entrada virtual reales.

Para reproducir una pasada completa sin mezclar actividad del escritorio:

```sh
python3 - <<'PYTHON'
import os, subprocess, tempfile
from pathlib import Path
with tempfile.TemporaryDirectory(prefix='dragon5c-suite-') as root:
    base = Path(root)
    env = dict(os.environ, HOME=str(base / 'home'))
    (base / 'home').mkdir()
    for kind in ('CONFIG', 'DATA', 'CACHE', 'STATE'):
        folder = base / kind.lower()
        folder.mkdir()
        env[f'XDG_{kind}_HOME'] = str(folder)
    subprocess.run(['./tests/run-all.sh'], env=env, check=True)
PYTHON
```

## Commits por punto

- `5b197d3`: dragon-prompt, plantillas, fixtures, pruebas y migración 061.
- `a401c23`: dragon-gate, fixtures, pruebas y migración 062.
- `c4b5c75`: métricas/exportación de dragon-mem, fixture, pruebas y migración 063.
- `689d8cc`: dragon-tokens, fixtures, pruebas y migración 064.

## Qué debe verse al integrar con la UI

1. El compositor muestra bloques, texto tachado, recortes y contador al elegir una
   plantilla; quitar un bloque cambia texto y conteo sin consultar su fuente.
2. Nada se entrega hasta pulsar Enviar y elegir destino. El historial viene
   desactivado y no debe mostrar un cuerpo guardado con el ajuste por defecto.
3. Revisión/Kanban muestra progreso y resultado de pruebas; vacío explica cómo
   definir test_cmd. Fallos, timeout y cancelación no habilitan una puerta verde.
4. Las métricas vacías muestran ausencia de muestra; CONTEXT.md conserva los
   criterios dentro del límite; consumo no reconocido muestra «—».

No se ha validado visualmente el compositor, Kanban, Revisión ni Ajustes: son la
responsabilidad de la otra rama. No se enviaron teclas con vin.py, no se tocaron
terminales, ni se ejecutaron pruebas de proyectos reales del usuario. Herdr y
portapapeles se verificaron con ejecutables simulados, sin entregar prompts reales.
No se desplegaron las nuevas migraciones en el HOME real ni se reinició el shell.
No hay decisiones pendientes del usuario.
