# Fase 5c · Pantallas (Kanban, compositor y Revisión)

Rama `feat/fase5c-pantallas`, desde `main` con 5a y 5b fusionados. 2026-11-01.
Alcance de esta sesión: **solo Quickshell** (servicios y vistas). Las herramientas
`dragon-prompt`, `dragon-gate` y `dragon-tokens`, sus pruebas y todas las migraciones
son de la otra sesión (`feat/fase5c-herramientas`). Aquí no se tocó ningún `dragon-*`
ni `migrations/`.

## Qué se hizo (un commit por punto)

1. **Servicios `Prompts` y `Gate`** (`1e03753`). `Prompts`: estado del compositor; el
   texto solo sale de `dragon-prompt build` y solo se entrega con `send()`/`copy()`,
   siempre por stdin (`StdinRequest`). `Gate`: las tres puertas de «Hecho» (pruebas,
   archivos vistos por contenido, conflictos con main) y la ejecución de pruebas, solo
   tras una acción explícita.
2. **Compositor** (`cf940ff`): cajón de 456 px (maqueta `32-taller-compositor`) con
   plantillas, bloques como chips (clic = quitar/poner, tachado), vista previa por
   segmentos, contador grande con barra de 30 segmentos y escala 0/1 000/2 000/3 000+,
   secretos tachados, destino, Enviar/Copiar/Guardar plantilla. Entradas: botón de
   cabecera, tecla `P`, `qs ipc call prompt open [plantilla]`, «Preparar prompt» de
   Agentes (destino ese agente, plantilla `libre`) y de Contenedores
   (`error-de-contenedor` + `log:<id>`), «Iniciar con prompt…» y «Componer y enviar».
3. **Kanban** (`0bee592`): métricas de `stats flow`, cinco columnas con `n / WIP`,
   tarjetas con clave, tipo, insignia del agente, barra de criterios y edad; panel con
   criterios marcables y alta de criterios, puertas y botones. Arrastrar y
   `Shift+←/→`; WIP lleno → aviso y confirmación (`--force` solo tras confirmar);
   «Hecho» solo con puertas en verde.
4. **Iniciar con prompt…** (`c0a9df9`): tras «Enviar e iniciar»:
   `dragon-git worktree add` → tarjeta guarda rama y worktree → `dragon-herdr start`
   → `dragon-prompt send --target herdr:<id>` → tarjeta guarda `agent_ref` y pasa a
   «En curso». Nada antes de pulsar. Con WIP lleno avisa antes de crear nada.
5. **Revisión** (`909d61c`): servicio `Review` y pestaña (maqueta `32-taller-revision`).
6. `fix(mem)` (`92502fd`): un refresco pedido durante otro ya no se pierde (la prueba
   del Kanban fallaba 1 de cada 5 veces por esto); `refreshBoard` ignora respuestas viejas.
7. **Consumo de hoy** (`5bedd87`): servicio `Tokens` y tarjeta en Agentes, oculta sin
   `dragon-tokens`; «—» para el agente cuyos registros no se entienden.

Pendiente (último commit, decidido con el usuario): **«Enviar al agente» del
explorador** se conecta cuando `feat/fase5d-pantallas` esté en `main` (`Files.qml` no
existe aún en esta rama): `Files.composerAvailable = true` y
`Files.agentRequested(paths)` → `Taller.openComposer({ template: "libre", blocks: paths.map(p => "paths:" + p) })`.

## Contratos que consumen los servicios (para la sesión de herramientas)

Todo con `--json` al final y la convención `{"ok":…}` de §3.

| Llamada | Quién | Qué espera |
|---|---|---|
| `dragon-prompt templates [--project S]` | Prompts | `{templates:[{id,name,builtin?}]}` |
| `dragon-prompt build --template T --project S [--card K] [--block tipo:arg]… [--off id,id]` | Prompts, Review | §5.5. Si cada bloque trae `text`, la vista previa lo usa; si no, parte `text` por los encabezados `## Etiqueta` en el orden de los bloques activos. Con un bloque `selection` el texto llega por stdin. |
| `dragon-prompt send --target herdr:<id>\|clipboard --stdin` | Prompts | Texto por stdin. No se pasan proyecto/tarjeta/plantilla: si `prompt_run` los necesita, la herramienta debe aceptar opciones nuevas **opcionales** y lo cableo. |
| `dragon-gate run --project S --cwd D --timeout 600` | Gate | Líneas JSON de progreso (`line`/`text`/`msg`) y una final con `exit` (o `ok:false`). Errores conocidos: `no_test_cmd`. |
| `dragon-tokens today` | Tokens | `{claude:{in,out,cache}\|null, codex:{in,out}\|null}`. Ausente = la tarjeta no aparece. |
| `dragon-herdr start --cwd D --kind claude\|codex --name K` | Prompts | Ya existe; se usa **sin** `--prompt-stdin`: el prompt va después por `dragon-prompt send` para que quede su `prompt_run`. |

**Opcionales en `dragon-git`** (acordado con el usuario: si faltan, la UI degrada):
- `status --repo R --base main` → mismo formato que `status`, incluyendo lo commiteado
  desde la base de fusión. Sin él, Revisión y la puerta «vistos» solo ven cambios sin
  commitear y la pestaña lo avisa.
- `diff --repo R --path P --base main` → mismo formato que `diff`.
- `merge-check --repo R --base main` → `{ok:true, conflicts:[ruta,…]}`. Sin él, la
  puerta sale «SIN COMPROBAR» (ámbar) y «Hecho» pide confirmación en vez de bloquear.
- Se detecta «no soportado» por `invalid_usage`/respuesta no JSON y se recuerda.

**Peticiones a `dragon-mem`** (no bloquean):
- `card list` con `criteria_total`/`criteria_done`: hoy el Kanban hace un `card show`
  por tarjeta al abrir (solo las que no tiene en memoria).
- `seen rm <clave> --path`: hoy no se puede desmarcar un archivo visto (se vuelve
  «sin ver» solo si cambia).
- Plantillas de usuario: `template save --blocks` guarda `[{type,label,arg,enabled}]`;
  `dragon-prompt` debería leer ese formato. `paths:<ruta>` puede repetirse (una por
  ruta); conviene que la herramienta las agrupe en un bloque «Rutas (N)».

**Despliegue**: los archivos nuevos (`services/{Prompts,Gate,Review,Tokens,StdinRequest}.qml`,
`modules/taller/{PromptComposer,KanbanTab,KanbanCard,ReviewTab,ReviewDiff,TallerChip}.qml`)
y los cambios en `qmldir`, `Theme.qml`, `Mem.qml`, `Taller.qml` y las pestañas
necesitan la migración de 5c para instalaciones por copia (como la 056 de 5b). Las
instalaciones enlazadas los ven al reiniciar Quickshell (tipos nuevos en `qmldir`).

## Decisiones

- Destino por defecto del compositor: el agente de esa tarjeta si existe y no está
  bloqueado; si no, el **portapapeles**. Un agente bloqueado aparece deshabilitado
  (dragon-herdr rechaza prompts a bloqueados).
- La barra de tokens colorea cada segmento por su posición (verde < 1 500, ámbar
  < 3 000, rojo después) y se llena a 3 000. Los umbrales viven en
  `Prompts.warnAt/highAt` hasta que exista la sección «Taller» de Ajustes.
- Rama de «Iniciar»: `tipo/clave-título` (sin acentos, 32 caracteres); worktree junto
  al repo: `<ruta-del-proyecto>-<clave sin guion>` (como `../arxnet-ax142` de la maqueta).
- Las pruebas del proyecto siguen si se cierra el Taller (acción explícita, como un
  commit en 5b); `■` en la puerta las cancela. Revisión, Kanban y Consumo no dejan
  procesos con el Taller cerrado.
- «Devolver» (Revisión → En curso) además de «A revisión» y «Hecho ✓»; registra
  `returned`, que alimenta la métrica de retrabajo.

## Verificación

- `tests/fase5c/` (bloque propio en `run-all.sh`): 10 pruebas.
  - Servicios con **Quickshell real**, `dragon-mem`/`dragon-git` reales, HOME/XDG
    temporales y herramientas falsas que siguen los contratos (`tests/fase5c/fake/`):
    nada se envía antes de `send()`, tachado y `--off`, puertas y caídas de
    `--base`/`merge-check`, pruebas en curso → OK, WIP y criterios, flujo Iniciar
    completo (worktree real, agente falso, prompt, tarjeta en curso), vistos por
    contenido con cambio posterior detectado en vivo, comentarios marcados como
    enviados, el observador se para al ocultar la pestaña, consumo con y sin herramienta,
    y el panel cableado con todos los singletons reales.
  - Vistas con `qml6` offscreen y datos de `tests/qml/fixtures/taller5c.js` (mocks
    `taller_{kanban,review,prompt,consumo}_mock.qml` y servicios falsos `Mock*.qml`).
  - Seis ejecuciones seguidas en verde tras el arreglo de `Mem`.
- Comparación con las maquetas sobre los renders: Kanban, compositor sobre el Kanban y
  Revisión coinciden en distribución, colores y textos.
- Las pruebas de vistas fijan `QT_FORCE_STDERR_LOGGING=1`: sin ello `qml6` manda los
  mensajes al journal y una comprobación de errores en stderr no ve nada (afecta
  también a `tests/fase5b/test_views.py`, que no lo fija).

## Qué debe ver el usuario

1. `SUPER+T` → **Kanban**: métricas arriba, cinco columnas, «En curso» con borde ámbar
   y `n / WIP`; al elegir una tarjeta, a la derecha sus criterios (clic los marca) y
   las tres puertas con su estado. Arrastrar una tarjeta a «En curso» con el WIP lleno
   muestra «¿Mover … igualmente?» abajo.
2. En una tarjeta de Backlog/Listo, **Iniciar con prompt…** abre el compositor con
   «Implementar tarjeta» y destino «claude · nuevo worktree»; nada ocurre hasta pulsar
   «Enviar e iniciar». Después: worktree junto al repo, agente en herdr y tarjeta en
   «En curso» con su insignia C/X.
3. **P** (o el botón de la cabecera) abre el compositor a la derecha; los chips de
   bloque se tachan al pulsarlos y el contador cambia; «Enviar a:» despliega los
   agentes y el portapapeles. `Esc` cierra primero el compositor.
4. **Revisión**: la tarjeta en revisión o en curso, «Seguir en vivo», `N/M VISTOS`,
   casillas verdes; si el agente cambia un archivo ya visto aparece «● CAMBIÓ DESPUÉS
   DE VERLO». Clic en el margen de una línea → caja de comentario; guardado se ve como
   burbuja lavanda y en la columna de comentarios. «Componer y enviar» abre el
   compositor con «Revisión».
5. **Agentes**: «Preparar prompt» y «Ver cambios» ya funcionan; abajo a la derecha
   «Consumo de hoy» si está instalado `dragon-tokens`.

## Lo que no pude comprobar

- **La sesión real**: no reinicié el Quickshell del usuario ni abrí el Taller por IPC
  desde esta rama (la instalación apunta al repo principal en `main`). Todo se vio en
  renders offscreen y con servicios reales sin Wayland.
- Las herramientas reales `dragon-prompt`, `dragon-gate` y `dragon-tokens` (aún no
  existen): solo contra los falsos. Ni `herdr` real arrancando un agente.
- Teclas y arrastre con ratón físico; la lógica de soltar en columna se probó con
  llamadas directas.
- Sin optimizador PNG en esta máquina: las capturas de `docs/screenshots/fase5c/`
  van sin optimizar (todas < 150 KB).

## Reproducir

```sh
python3 -m unittest discover -s tests/fase5c -v
tests/qml/render-mocks.sh /tmp/dragon-mocks   # incluye los mocks de 5c
```

Capturas: [Kanban](screenshots/fase5c/taller-kanban.png),
[WIP](screenshots/fase5c/taller-kanban-wip.png),
[compositor](screenshots/fase5c/taller-kanban-compositor.png),
[Revisión](screenshots/fase5c/taller-revision.png),
[consumo](screenshots/fase5c/taller-agentes-consumo.png).
