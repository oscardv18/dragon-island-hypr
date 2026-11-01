# dragon-island — Fase 5: Taller de ingeniería agéntica + explorador de archivos

Plan completo y autosuficiente. Está escrito para que lo ejecute un agente de código (Codex con GPT) **sin ayuda de Claude Code**, que volverá más adelante a revisar y pulir. Léelo entero antes de tocar nada.

---

## 0. Cómo trabajar con este documento

**Orden de lectura obligatorio** (antes del primer commit):
1. `AGENTS.md` y `.agents/skills/dragon-island/SKILL.md`. Mandan sobre este plan en cualquier conflicto de reglas del proyecto.
2. `docs/HANDOFF.md` completo (sobre todo las últimas secciones 8: pulido, ajuste de ventanas, tokens de `Theme`, regiones de blur). Si hay ramas de Claude Code sin fusionar (por ejemplo `feat/ajuste-ventanas`), pregunta al usuario si ya están en `main` antes de depender de ellas.
3. `docs/KEYBINDS.md`, `migrations/README.md`, `lib/common.sh`, `tests/run-all.sh`.
4. Las maquetas de la sección 2.
5. El código de los motores que ya existen (`dragon-search`, `dragon-usage`, `dragon-clip`, `dragon-activity`): **tus herramientas nuevas siguen su mismo patrón** (lenguaje, ubicación en el repo, cómo se despliegan con migraciones, cómo se prueban). Si son Python, usa solo la biblioteca estándar salvo donde este plan diga otra cosa.

**Reglas que no se rompen** (resumen de `AGENTS.md` más lo propio de esta fase):
- La UI nunca ejecuta comandos: todo pasa por servicios de `config/quickshell/services/`, que llaman a las herramientas CLI y leen JSON.
- `Theme.qml` es la única fuente de colores, tamaños, duraciones y curvas. Nada literal en los módulos.
- Una región de desenfoque por ventana. `hyprctl keyword` no sirve en Lua: usa `hyprctl eval`.
- Nunca cierres ventanas del usuario (`pkill ghostty` está prohibido) ni envíes teclas con herramientas de entrada virtual a la terminal donde corres: te interrumpes a ti mismo. Cierra paneles con `qs ipc call …`.
- Todo cambio sobre sistemas instalados lleva migración idempotente en `migrations/`, con copia de seguridad (`backup_copy`), respetando `DRY_RUN` y `ASSUME_YES`. Mira cuál es el siguiente número libre antes de crear cada una.
- Un commit por punto. Mensajes que dicen qué y por qué.
- Si algo no es viable tal cual, **para y pregunta**; no cambies el diseño por tu cuenta.
- Las pruebas usan HOME y XDG temporales. Nada de tocar el HOME real en tests.
- Cada paquete de sistema nuevo se anota en `pre-instalation.md` y en el instalador (hay una prueba que cruza ambos).

**Ramas y reparto.** Un tramo = una rama desde `main` (nombres en la sección 7). Si hay dos sesiones, la sesión A hace 5a → 5b → 5c y la sesión B hace 5d. Ambas añaden bloques propios y marcados en `tests/run-all.sh`, `qmldir` y `Theme.qml` (la B solo bajo `Theme.files.*`); en un conflicto se conservan los dos bloques. Las notas van en `docs/handoff-fase-5<x>.md`; `docs/HANDOFF.md` lo actualiza al final una sola persona (sección 9 de este plan).

**Cómo comprobar lo visual.** No des por buena una pantalla que no has visto. Abre con IPC, captura con `grim` (una captura por comando, con `timeout`) y compara con las maquetas. Si no puedes ver la pantalla, di en el resumen qué debe ver el usuario, punto por punto. Para probar sin herdr, Docker ni red, cada panel debe poder abrirse con servicios simulados (`tests/qml/*_mock.qml`, como ya se hace con `sddm_mock.qml`).

---

## 1. Visión y principios

El escritorio es el **panel de control de la ingeniería agéntica**: ves qué hacen tus agentes, decides qué necesita tu atención y actúas, sin salir del entorno. No es un IDE ni un entorno de *vibe coding*: **el humano dirige y revisa**, la IA ejecuta.

Principios que mandan sobre cualquier decisión:
1. **Ahorrar tokens.** Nada se inyecta automáticamente en ningún agente. Los prompts salen de plantillas y bloques que el usuario ve, mide (contador de tokens) y envía. **Ninguna herramienta de esta fase llama a un modelo.**
2. **herdr es la fuente de verdad de los agentes.** El escritorio lo lee; no lo sustituye.
3. **Datos por proyecto, locales y simples.** Un SQLite. Nada de memoria general persistente.
4. **Práctico antes que completo.** Lo cotidiano en gráfico; lo avanzado, un botón que abre la herramienta de terminal (lazygit, shell).
5. **Privacidad.** Secretos tachados antes de mostrar, medir o enviar nada. La salida de los paneles de los agentes no se guarda.
6. **Ligero.** Nada en segundo plano si la ventana está cerrada, salvo el observador de herdr (por eventos, no por sondeo).

---

## 2. Referencias de diseño

Maquetas del lienzo (artefacto «Rediseño Hyprland · Gravedad»). El usuario las exporta a `docs/design/` a 1× (1366 px de ancho; `tests/check-images.sh` rechaza imágenes de más de 1,5 MB). Si faltan, pídelas antes de empezar el tramo que las usa.

| Maqueta | Archivos en `docs/design/` | Tramo |
|---|---|---|
| 32 · Taller (5 pestañas + compositor + tarjeta de isla) | `32-taller-agentes.png`, `32-taller-kanban.png`, `32-taller-contenedores.png`, `32-taller-git.png`, `32-taller-revision.png`, `32-taller-compositor.png` | 5a–5c |
| 33 · Explorador de archivos | `33-archivos-lista.png`, `33-archivos-cuadricula.png`, `33-archivos-extraer.png`, `33-archivos-red.png`, `33-archivos-compartir.png` | 5d |
| 29 · Paneles HUD (estilo de popover) | `29-paneles-*.png` | estilo |
| 31 · Isla de mando | `31-isla-mando*.png` | isla |

Las maquetas **20–23** (Kanban con WIP, historia con IA, planificación, métricas) son anteriores a esta decisión: **la 32 las sustituye**. Se descarta la generación de historias con IA (el compositor de prompts la reemplaza) y se aplaza la planificación Shape Up (apuesta, mapa, colina). De la 23 solo se aprovechan las métricas de flujo.

Lenguaje visual (ya existe, reutilízalo): panel HUD de 22 px de radio, fondo ahumado, línea superior lavanda→cian, escuadras cian en las cuatro esquinas (el componente `FrameDecor` y los tokens `Theme.frame.*` del ajuste de ventanas; **si aún no existen en `main`, reutiliza el borde y las escuadras de `PopoverFrame.qml` sin duplicar valores, y deja una nota para unificarlos después**), tipografías Outfit y JetBrains Mono, semáforo: ámbar = atención/bloqueado, cian = trabajando, verde = listo/ok, lavanda = estructura, rojo suave `#FB7185` = error. **Añade a `Theme.qml`**: `danger` (`#FB7185`), `diffAdd`/`diffDel` (fondos a baja opacidad), `tokenOk`/`tokenWarn`/`tokenHigh` y los tokens de espaciado de lista que falten. No reutilices valores de otros módulos.

---

## 3. Arquitectura

```
herdr (demonio, socket) ─► dragon-herdr ─┐
docker.sock ────────────► dragon-docker ─┤
repos y worktrees ──────► dragon-git ────┤
dragon.db (SQLite) ─────► dragon-mem ────┼─► services/*.qml ─► modules/taller · modules/files · isla
plantillas y bloques ───► dragon-prompt ─┤
comandos de prueba ─────► dragon-gate ───┤
registros locales ──────► dragon-tokens ─┤
gio · udisks2 · 7z ·
avahi · samba ──────────► dragon-files ──┘
```

**Convenciones comunes de todas las herramientas** (`dragon-*`):
- Orden de argumentos estable, salida **JSON por la salida estándar** con `--json` (siempre en lo que consume la UI). Los eventos en flujo son **líneas JSON** (una por línea, `flush` inmediato).
- Éxito: `{"ok":true, …}`. Error: `{"ok":false,"error":{"code":"snake_case","message":"texto humano en español","hint":"qué hacer"}}` y código de salida 1 (uso incorrecto: 2).
- Lectura rápida: **menos de 150 ms** en frío para `status`, `ps`, `snapshot`, `ls` de 1000 entradas (mide la mediana de 7 ejecuciones como en `tests/engines/bench.py`; el límite en `run-all.sh` es 300 ms).
- Los flujos largos (`watch`, `stats --stream`, `logs --follow`) se paran limpiamente con SIGTERM y reconectan solos (retroceso 1 s → 10 s).
- Nunca imprimen secretos. Todo texto que pueda contenerlos pasa por el **filtro de secretos compartido** (extrae el que ya usan `dragon-search cmd` y `dragon-activity` a un módulo común si aún no lo es, sin romper sus pruebas): variables `*_KEY|*_TOKEN|*_SECRET|*_PASSWORD`, `Bearer …`, URL con credenciales, claves privadas PEM, claves tipo `AKIA…`/`ghp_…`/`sk-…`. Marca: `[oculto:tipo]`.
- Despliegue: migración que instala el comando en `~/.local/bin/` igual que `040-activity-install.sh`.

**Servicios de Quickshell** (`config/quickshell/services/`, registrados en `qmldir` como singleton): `Herdr`, `Mem`, `Docker`, `Git`, `Prompts`, `Gate`, `Tokens`, `Files`, `FileOps`, `Devices`, `Archives`. Cada uno: propiedad `status` (`ok|loading|unavailable|error`) con mensaje, **procesos largos solo mientras la ventana que los usa está visible**, y estados vacíos con texto claro («Docker no disponible: añade tu usuario al grupo docker»). Excepción: `Herdr` mantiene su observador siempre (la isla lo necesita).

**Módulos**: `modules/taller/` (`TallerPanel`, `AgentsTab`, `KanbanTab`, `ContainersTab`, `GitTab`, `ReviewTab`, `PromptComposer`, `DiffView`, `LogView`) y `modules/files/` (`FilesWindow`, `Sidebar`, `FileList`, `FileGrid`, `Preview`, `ExtractDialog`, `ShareDialog`, `NetView`, `OpsBar`). En la isla: `modules/island/AttentionCard.qml` integrada en `services/Priority.qml`.

**IPC y atajos** (comprueba `docs/KEYBINDS.md` antes de fijarlos y documenta los reales):
- `qs ipc call taller toggle` / `open <agentes|kanban|contenedores|git|revision>` → `SUPER + T`.
- `qs ipc call prompt open [plantilla]` → `P` dentro del Taller.
- `qs ipc call files open [ruta]` → `SUPER + E`.
- «Ir al agente que necesita atención» → `SUPER + A` (salta al siguiente bloqueado; si no hay, al siguiente «listo sin ver»).

**Tipo de ventana.** El Taller es un **panel superpuesto** (como el launcher): se abre, se usa y se cierra con `Esc`; 1226×612 centrado. El explorador es una **ventana normal** (`FloatingWindow` de Quickshell, varias instancias, con su sitio en los workspaces de Hyprland), sin barra de título. Si el contorno global de ventanas está activo, el explorador **no dibuja el suyo** (evita el doble borde); si está en «nada», usa `FrameDecor`.

---

## 4. Datos: `dragon-mem` (SQLite por proyecto)

Archivo `~/.local/share/dragon-island/dragon.db` (permisos 600; WAL; `PRAGMA foreign_keys=ON`; versión en `PRAGMA user_version`; migraciones de esquema numeradas dentro de la herramienta, idempotentes). Búsqueda de texto con FTS5, **sin embeddings** y sin llamadas a modelos. Todo se escribe a mano o por eventos mecánicos (movimientos de tarjeta, commits, cambios de configuración).

```sql
CREATE TABLE project(id INTEGER PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL, path TEXT NOT NULL,
  key_prefix TEXT NOT NULL, next_num INTEGER NOT NULL DEFAULT 1, compose_file TEXT, test_cmd TEXT, build_cmd TEXT,
  wip_limit INTEGER NOT NULL DEFAULT 3, herdr_space TEXT, created_at INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0);
CREATE TABLE card(id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  key TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL DEFAULT 'feat' CHECK(kind IN('feat','fix','chore','docs')),
  col TEXT NOT NULL DEFAULT 'backlog' CHECK(col IN('backlog','ready','doing','review','done')),
  pos REAL NOT NULL DEFAULT 0, branch TEXT, worktree TEXT, agent_ref TEXT, session_ref TEXT,
  created_at INTEGER NOT NULL, started_at INTEGER, review_at INTEGER, done_at INTEGER, UNIQUE(project_id,key));
CREATE TABLE criterion(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL REFERENCES card(id) ON DELETE CASCADE,
  text TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, pos INTEGER NOT NULL DEFAULT 0);
CREATE TABLE card_event(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL REFERENCES card(id) ON DELETE CASCADE,
  ts INTEGER NOT NULL, kind TEXT NOT NULL, data TEXT NOT NULL DEFAULT '{}');   -- moved, started, returned, gate, note
CREATE TABLE note(id INTEGER PRIMARY KEY, project_id INTEGER REFERENCES project(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK(kind IN('decision','note','convention')), title TEXT NOT NULL, body TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE prompt_template(id INTEGER PRIMARY KEY, project_id INTEGER REFERENCES project(id) ON DELETE CASCADE,
  name TEXT NOT NULL, blocks TEXT NOT NULL, created_at INTEGER NOT NULL);       -- blocks = JSON
CREATE TABLE prompt_run(id INTEGER PRIMARY KEY, project_id INTEGER, card_id INTEGER, template TEXT, target TEXT,
  tokens_est INTEGER NOT NULL, sent_at INTEGER NOT NULL, body_hash TEXT NOT NULL, body TEXT);  -- body solo si el ajuste lo permite
CREATE TABLE review_seen(card_id INTEGER NOT NULL, path TEXT NOT NULL, blob_hash TEXT NOT NULL, seen_at INTEGER NOT NULL,
  PRIMARY KEY(card_id,path));
CREATE TABLE review_comment(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL,
  text TEXT NOT NULL, created_at INTEGER NOT NULL, sent INTEGER NOT NULL DEFAULT 0);
CREATE TABLE agent_wait(id INTEGER PRIMARY KEY, agent_id TEXT NOT NULL, card_id INTEGER, blocked_at INTEGER NOT NULL, resumed_at INTEGER);
CREATE TABLE system_change(id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, key TEXT NOT NULL, old TEXT, new TEXT, source TEXT NOT NULL);
CREATE VIRTUAL TABLE search_fts USING fts5(kind, ref, title, body, tokenize='unicode61 remove_diacritics 2');
```
(Mantén `search_fts` sincronizada en la misma transacción que cada escritura de `card`/`note`/`prompt_template`.)

**`seen` por contenido:** `review_seen.blob_hash` es el hash del archivo en el momento de marcarlo. Si el hash actual difiere, el archivo vuelve a «sin ver» (maqueta: «CAMBIÓ DESPUÉS DE VERLO»).

**CLI** (`dragon-mem … --json`):
- `project add --path <ruta> [--slug] [--name] [--prefix AX] [--test-cmd …] [--compose …]` (crea el proyecto, detecta el repo, añade `.dragon/` a `.git/info/exclude` —local, no `.gitignore`—) · `project list|show|set|archive`.
- `card add --project <slug> --title … [--kind] [--body]` (genera la clave `AX-142` con el contador) · `card list [--project] [--col]` · `card show <clave>` · `card set <clave> [--title|--body|--kind|--branch|--worktree|--agent-ref|--session-ref]` · `card move <clave> --to <col>` (registra evento; **respeta el límite WIP** y devuelve `wip_limit_reached` si `doing` ya está lleno, salvo `--force`) · `card criteria add|toggle|rm`.
- `note add|list|show|rm` · `search "<texto>" [--project]` (FTS5, resultados con fragmento).
- `template list|save|rm`.
- `seen set <clave> --path … --hash …` · `seen list <clave>` · `comment add|list|clear|mark-sent`.
- `wait start|end` (lo usa `dragon-herdr watch --record`).
- `stats flow --project <slug> --days 30` → `{"lead_time_median_h","cycle_time_median_h","rework_pct","throughput_7d","approval_wait_median_h"}` (lead = `created→done`; ciclo = `started→done`; retrabajo = tarjetas devueltas de `review` a `doing` ÷ terminadas; espera = mediana de `agent_wait`).
- `export --project <slug> [--out <repo>/.dragon/CONTEXT.md]` → Markdown **de menos de 4 KB**: nombre, convenciones, últimas 10 decisiones, tarjeta actual con sus criterios; cabecera «generado por dragon-mem; no editar».
- `system log add --key … --old … --new … --source …` · `system log list`.
- `backup` (copia el `.db` a `…/backups/` con fecha; conserva 7) · `path`.

Pruebas (`tests/mem/`): esquema y migraciones, clave de tarjeta, WIP, FTS, exportación con límite de tamaño, concurrencia (dos procesos escribiendo), `seen` con cambio de contenido, `stats` con datos sintéticos, permisos 600.

---

## 5. Contratos de las herramientas

### 5.1 `dragon-herdr` (puente con herdr) — tramo 5a

**Primer paso: descubrir, no suponer.** Tu herdr es el 0.9.5; la app nativa y `herdr-core` son de finales de octubre de 2026 y no está confirmado que tu versión tenga todo lo siguiente. Ejecuta `herdr --help`, `herdr agent --help`, `herdr pane --help`, `herdr agent explain` y mira el socket. Escribe lo que **realmente** existe en `docs/HERDR-API.md` (comandos, formato JSON, eventos, cómo enfocar un panel). Después implementa el contrato de abajo sobre eso. Si algo falta (por ejemplo no hay evento de suscripción), usa el mejor sustituto (sondeo del socket cada 2 s solo si hay agentes) y apúntalo; si una pieza esencial es imposible, **para y pregunta**.

Contrato propio (normalizado, independiente de cómo lo exponga herdr):
- `dragon-herdr probe --json` → `{"version","socket","features":{"list":bool,"events":bool,"focus":bool,"prompt":bool,"read":bool,"helpers":bool}}`.
- `dragon-herdr snapshot --json` → `{"ok":true,"source":"herdr|screen|none","agents":[{"id","kind":"claude|codex|other","state":"blocked|working|done|idle|unknown","since":<epoch>,"space","tab","pane","cwd","branch","helper_of":null|"<id>","card":null|"AX-142"}],"spaces":[{"name","state"}]}`. `card` se resuelve cruzando `cwd` con `card.worktree` en `dragon-mem`. Si herdr no corre: `source:"none"` y listas vacías (**nunca** un error).
- `dragon-herdr watch [--record]` → primero un `{"t":"snapshot",…}` y luego `{"t":"agent","op":"add|update|remove",…}`; latido `{"t":"ping"}` cada 30 s; reconecta solo. Con `--record` escribe en `agent_wait` cuando un agente pasa a y sale de `blocked`.
- `dragon-herdr focus <id>` → enfoca el panel en herdr **y** trae al frente la ventana del cliente con `hyprctl dispatch focuswindow` (localiza la ventana por su clase/PID; si hay varias, la que muestra ese espacio). Código 1 con mensaje si no la encuentra.
- `dragon-herdr read <id> [--lines 8]` → últimas líneas del panel, **tachadas y recortadas; nunca se guardan**.
- `dragon-herdr prompt <id> --stdin [--no-enter]` → escribe el texto en la entrada del agente (y pulsa Intro salvo `--no-enter`). Solo lo invoca una acción explícita del usuario.
- `dragon-herdr start --cwd <ruta> --kind claude|codex --name <texto> [--prompt-stdin]` → crea espacio/pestaña y arranca el agente (lo usa «Iniciar con prompt…»).
- **Sin aprobar desde el escritorio:** no hay comando para responder a permisos. Solo se navega hasta el agente.

Pruebas: un **herdr falso** (script que habla el mismo protocolo y emite estados) para `snapshot`, `watch`, reconexión, `focus` con `hyprctl` simulado, `source:"none"`.

### 5.2 `dragon-docker` — tramo 5b
Habla con la API de Docker por el socket Unix (`/var/run/docker.sock`) con la biblioteca estándar. Docker con Compose; sin Podman en esta versión.
- `ps --json` → `{"containers":[{"id","name","project","service","image","state":"running|restarting|exited|paused|created|dead","health":"healthy|unhealthy|starting|none","exit_code","oom_killed","restart_count","ports":["3000->3000"],"started_at","working_dir"}]}` (agrupa por la etiqueta `com.docker.compose.project`).
- `stats --stream [--ids …]` → una línea cada 2 s por contenedor: `{"id","cpu_pct","mem_bytes","mem_limit","net_rx_bps","net_tx_bps"}`.
- `logs <id> [--tail 200] [--since 10m] [--follow] [--level all|warn|error]` → líneas `{"ts","level","msg","count"}`: sin colores ANSI, **líneas consecutivas idénticas colapsadas** (`count`), nivel por heurística documentada (`ERROR|FATAL|panic|Traceback|Exception` → error; `WARN` → warn; resto info).
- `issues --json` → problemas detectados: `oom`, `restart_loop` (≥3 reinicios en 10 min), `unhealthy`, `exit_nonzero`; cada uno con `container`, `detail`, `since`.
- `events --follow` (die, oom, restart, health_status).
- `action <id> start|stop|restart` · `inspect <id> --json` (**valores de variables de entorno tachados**) · «Shell» no es una operación de la herramienta: el servicio abre la terminal con `docker exec -it <id> sh`.
- Si el socket da «permiso denegado»: `error.code:"docker_permission"` con el hint «añade tu usuario al grupo docker y vuelve a iniciar sesión».
Pruebas: **servidor de socket falso** con respuestas de Docker grabadas; colapso de repetidos; detección de OOM y bucle de reinicios; tachado de entorno.

### 5.3 `dragon-git` — tramo 5b
Envuelve `git` (sin dependencias). Nunca escribe `git config`; la identidad es la del repo. Tiempo máximo por operación: 5 s (más en push/pull). **Nunca `--force`**.
- `status --repo <ruta> --json` → `{"branch","upstream","ahead","behind","staged":[{"path","status":"M|A|D|R","add","del"}],"changes":[…],"untracked":[…]}` (`status --porcelain=v2 -z --branch` + `diff --numstat`).
- `diff --repo --path <f> [--staged] --json` → `{"path","add","del","binary","truncated","hunks":[{"header","lines":[{"o","n","t":"ctx|add|del","text"}]}]}` (máximo 2000 líneas).
- `stage|unstage --repo --paths …` · `commit --repo -m "<mensaje>" [--push]` · `pull --ff-only` · `push` · `checkout <rama>` · `stash push|pop|list` · `branches` · `log --repo -n 30` (`hash`, `subject`, `author`, `ts`, `refs`, `parents`).
- **Antes de commitear:** revisa lo preparado. Si encuentra secretos (claves privadas, `.env`, tokens) devuelve `error.code:"secrets_found"` con archivo, línea y tipo (**nunca el valor**) y no commitea. El mensaje se valida contra `tipo(ámbito): texto` solo como **aviso** (`warnings`), no como error.
- `worktree add --repo --branch <b> --path <dir> [--from <base>]` · `worktree list` · `worktree remove` (se niega si hay cambios sin guardar).
- `watch --repo` → `{"t":"changed","files":[{"path","status","add","del","hash"}]}` con antirrebote de 300 ms (inotify si existe `inotifywait`; si no, sondeo de 2 s). `blob-hash --repo --path` para `review_seen`.
Pruebas: repos temporales; secretos; rutas con espacios y Unicode; worktrees; `diff` truncado; repo sin commits; fusión con conflictos (la herramienta informa, no resuelve).

### 5.4 `dragon-gate` — tramo 5c
`dragon-gate run --project <slug> --cwd <ruta> [--timeout 600] --json` ejecuta `project.test_cmd` (definido **por el usuario** para su proyecto) con `bash -lc` en el directorio indicado, emite progreso por líneas, y devuelve `{"ok":true,"exit":0,"seconds":41,"tail":["…últimas 30 líneas tachadas…"]}`. Límite de salida y de tiempo; SIGTERM mata el grupo de procesos. Registra un `card_event` de tipo `gate`. No ejecuta nada si `test_cmd` está vacío (devuelve `no_test_cmd`).

### 5.5 `dragon-prompt` — tramo 5c
Plantillas y bloques; **determinista, sin modelo**.
- `templates [--project <slug>] --json` → integradas (carpeta `config/dragon-prompt/templates/*.json`) + las del usuario en la base.
- `build --template <id|nombre> --project <slug> [--card AX-142] [--block tipo:arg …] [--off <id,…>] --json` → `{"text","tokens","blocks":[{"id","type","label","tokens","enabled","truncated","redactions"}],"warnings":[]}`.
- Tipos de bloque: `card` (título y cuerpo) · `criteria` · `paths` (lista de rutas; **rutas, no contenido**: el agente ya tiene el repo) · `diff` (de `dragon-git diff`, máx. 120 líneas, recorte marcado «… recortadas N líneas») · `log` (de `dragon-docker logs`, máx. 40 líneas alrededor del primer error, repetidas colapsadas) · `note`/`decisions` (últimas N) · `commands` (`test_cmd`/`build_cmd`) · `comments` (comentarios de revisión de la tarjeta) · `selection` (texto por entrada estándar o portapapeles) · `text` (libre).
- **Contador:** `tokens = ceil(caracteres_utf8 / 3.8)` por bloque y total, documentado como estimación (±20 %) y sin dependencias. Umbrales en Ajustes (por defecto: verde < 1 500, ámbar < 3 000, rojo ≥ 3 000).
- **Tachado de secretos** antes de contar y de mostrar (filtro compartido); `redactions` cuenta los tachados.
- `send --target herdr:<id>|clipboard|file:<ruta> --stdin [--no-enter]` → entrega (herdr vía `dragon-herdr prompt`; portapapeles vía `wl-copy`) y apunta un `prompt_run` con tokens y hash. **El texto solo se guarda si el ajuste «Guardar historial de prompts» está activado** (por defecto no).
- Plantillas integradas (en español, editables): `implementar-tarjeta`, `error-de-contenedor`, `revisar-cambios`, `arreglar-test`, `escribir-pruebas`, `refactor-pequeno`, `explicar-codigo`, `libre` (vacía). Formato del texto final: bloques separados por un encabezado `## Etiqueta`; nada más.
Pruebas: determinismo (misma entrada, mismo texto), recortes, tachado, contador, `--off`, envío a herdr falso y a portapapeles simulado, plantillas de usuario.

### 5.6 `dragon-tokens` (opcional) — tramo 5c
`dragon-tokens today --json` → `{"claude":{"in","out","cache"},"codex":{"in","out"}}` leyendo **solo lectura** los registros locales de Claude Code y Codex (inspecciona primero los archivos reales de esta máquina, en `~/.claude/` y `~/.codex/`; los formatos pueden cambiar). Parser tolerante: si algo no se entiende, devuelve `null` para ese agente y la UI muestra «—». Pruebas con muestras escritas por ti tras ver los reales (sin datos privados). Presupuesto diario configurable en Ajustes.

### 5.7 `dragon-files` — tramo 5d
Python con `os.scandir` más estas herramientas del sistema, **todas opcionales con degradación clara** (la UI avisa de lo que falta y cómo instalarlo): `gio` (glib), `udisksctl`/`lsblk`, `7z` (`7zip` o `p7zip`) y `bsdtar` (libarchive), `unrar` (solo si 7z no lee un RAR), `avahi-browse`, `smbclient`, `net` (samba), `secret-tool` (libsecret), `inotifywait`, `vipsthumbnail` o ImageMagick, `ffmpegthumbnailer`, `wl-copy`, `xdg-open`.

- `ls <ruta> [--hidden] [--sort name|size|mtime|type] [--dirs-first] [--git] [--limit N] --json` → `{"path","entries":[{"name","kind":"dir|file|link|other","size","mtime","mime","mode","owner","hidden","link_target","git":null|"M"|"A"|"D"|"?"}],"free","total","fs"}`. 1000 entradas en menos de 150 ms (sin `--git`). `--git` consulta `dragon-git status` **una vez por repo**.
- `watch <ruta>` → eventos de cambio (inotify; si no, sondeo de 1 s solo mientras la carpeta está abierta).
- `places --json` → carpetas XDG (`~/.config/user-dirs.dirs`), marcadores (lee `~/.config/gtk-3.0/bookmarks` y guarda los propios en `~/.config/dragon-island/files/bookmarks.json`), proyectos de `dragon-mem`.
- `thumb <ruta> [--size normal|large]` → ruta de la miniatura en la caché estándar `~/.cache/thumbnails/` (md5 del URI, como Nautilus), generada solo si falta; imágenes con vips/ImageMagick, vídeo con `ffmpegthumbnailer`, PDF con la primera página; si no hay herramienta, `null` (la UI usa icono).
- `props <ruta> --json` (permisos, propietario, mime, tamaño; para carpetas, tamaño recursivo con tope de tiempo y de entradas).
- `op copy|move|trash|delete|rename|mkdir|link …` con `--json-progress` (`{"t":"progress","pct","file","bps"}` … `{"t":"done"}`); conflictos `ask|skip|overwrite|rename`; copia con `cp -a --reflink=auto`, `rsync` para volúmenes grandes o entre dispositivos y `gio copy` para URI de GVFS; SIGTERM cancela y limpia. `delete` permanente exige `--confirm`. La papelera es la estándar del sistema (`gio trash`); listar y vaciar con `gio`.
- `open <ruta>` / `open-with <ruta> --list` / `terminal-here <ruta>`.
- **Dispositivos:** `devices --json` → `[{"id","label","kind":"disk|usb|mtp|optical|luks","size","used","free","fstype","mounted","mountpoint","removable","locked"}]` (de `lsblk -J -b` más `gio mount -l` para MTP); `devices --watch` (udev/udisks por eventos); `mount|unmount|eject <id>` (udisksctl; MTP con `gio mount`); `unlock <id> --passphrase-stdin` (**nunca la contraseña por argumento**).
- **Red:** `net discover --json` (`avahi-browse -art`: `_smb._tcp`, `_sftp-ssh._tcp`, `_ssh._tcp`, `_nfs._tcp`, `_ipp._tcp`), `net connect <uri> [--user] [--password-stdin] [--save]` (SMB, SFTP, NFS, FTP, WebDAV con `gio mount`; las contraseñas van al **llavero del sistema** con `secret-tool`, jamás a un archivo), `net mounts`, `net unmount <uri>`, `net shares <host>` (`smbclient -L`).
- **Archivos comprimidos:**
  - `archive list <archivo> --json` → `{"format","encrypted","count","total_size","entries":[{"path","size","packed","mtime","is_dir"}],"warnings":[]}` (con `7z l -slt`; respaldo `bsdtar -tvf`).
  - `archive test <archivo>` (integridad).
  - `archive extract <archivo> --dest <dir> [--password-stdin] [--conflict ask|skip|overwrite|rename] [--own-folder] --json-progress`.
  - `archive create --format zip|7z|tar.zst|tar.gz|tar.xz --out <archivo> --paths …`.
  - Formatos de lectura: zip, 7z, rar, tar (gz, xz, zst, bz2), iso, deb, rpm, cab, appimage y los que 7z lea.
  - **Extracción segura (obligatoria):** extrae siempre a un directorio temporal de preparación dentro del destino (`.dragon-extract-XXXX`); antes de mover nada, valida **cada ruta**: sin rutas absolutas, sin `..`, sin enlaces simbólicos que apunten fuera, sin dispositivos; quita los bits setuid/setgid; comprueba el espacio libre; **detecta bombas** (descomprimido/comprimido > 200 y > 2 GB exige `--confirm-bomb`); aplica la política de conflictos al mover; limpia el temporal al cancelar o fallar. Pruebas con archivos malévolos de muestra (zip-slip, enlace de escape, bomba pequeña).
- **Compartir (Samba):** `share status|enable|disable --path <ruta> --name <n> [--rw] [--guest]` con `net usershare`. Solo carpetas del usuario; **se niega** a compartir `$HOME` entero, `/`, `~/.ssh`, `~/.gnupg`, `~/.config` y rutas de sistema; los invitados vienen **apagados**; devuelve las direcciones `smb://<equipo>/<nombre>` y `\\<equipo>\<nombre>`. No toca el cortafuegos: si hace falta abrir puertos, **lo explica** con el comando exacto, sin ejecutarlo. La preparación de Samba (grupo `sambashare`, `usershare` en `smb.conf`) va en una migración que pide confirmación y usa `sudo` solo con `ASSUME_YES` o confirmación explícita.
- **Gestor predeterminado:** `dragon-files.desktop` con `MimeType=inode/directory;` y `xdg-mime default`; opcionalmente un servicio `org.freedesktop.FileManager1` (`ShowItems`, `ShowFolders`, `ShowItemProperties`) con PyGObject `Gio.bus_own_name` para que «Mostrar en carpeta» del navegador abra el explorador (si PyGObject no está, se omite y se documenta).
Pruebas (`tests/files/`): `ls` con 5000 entradas, nombres raros, enlaces rotos, permisos denegados; miniaturas; operaciones y conflictos; cancelación; extracción maliciosa; `share` con rutas prohibidas; discovery con `avahi-browse` simulado; dispositivos con `lsblk` grabado.

---

## 6. Interfaz: qué debe verse (criterios de aceptación visuales)

Compara siempre con las maquetas. Todo texto de la UI en español.

**Cabecera del Taller** (`32-*`): `TALLER` + selector de proyecto (nombre y rama) + estado de herdr (`HERDR <versión> · SOCKET`, verde si conectado) + `DB · N PROYECTOS` + botón `Prompt ✎ [P]` + `SUPER + T`. Cinco pestañas con insignia de pendientes (Agentes = bloqueados, Contenedores = con errores, Git = cambios, Revisión = sin ver). Esquinas cian y línea lavanda→cian. Se cierra con `Esc`.

**Agentes:** lista agrupada por proyecto (*space*) con estado resumido arriba (BLOQUEADO / LISTO / REPOSO), filas con punto de estado, insignia C/X, rama, tarjeta, nota, estado, tiempo y botón `Ir ↵` en los bloqueados; ayudantes anidados bajo el agente que los lanzó. Panel derecho: «Última salida del panel» (de `dragon-herdr read`), acciones (`Ir al panel`, `Preparar prompt`, `Ver cambios`, `Marcar como visto`) y «Consumo de hoy» (solo si existe `dragon-tokens`; si no, se oculta). **Sin botón de aprobar.**

**Isla:** pastilla de 440×30 px con punto ámbar, «claude pide aprobación · AX-142 · 2 min» y botón `Ir ↵` que llama a `dragon-herdr focus`; `SUPER + A` hace lo mismo. Prioridad: bloqueado > listo sin ver > resto. «Ignorar 10 min» (solo en memoria). Se integra en la pila de prioridad de la isla de mando (`services/Priority.qml`), sin romper lo que ya muestra.

**Kanban:** cinco columnas (Backlog, Listo, En curso con `n / WIP`, Revisión, Hecho), tarjetas con clave, tipo (feat/fix/chore), insignia del agente, barra de criterios y edad. Tira de métricas (lead time, ciclo, retrabajo, terminadas 7 d, espera de aprobación) de `dragon-mem stats flow`. Panel de la tarjeta: criterios con casillas, **puertas para «Hecho»** (pruebas del proyecto, archivos del diff vistos, sin conflictos con `main`) y botones `Iniciar con prompt…` / `A revisión`. Arrastrar entre columnas y flechas de teclado. Mover a «En curso» con el WIP lleno muestra un aviso y exige confirmar (`--force`).

**Iniciar con prompt…:** abre el compositor con la plantilla `implementar-tarjeta` cargada; al enviar, `dragon-git worktree add` → `dragon-herdr start` → la tarjeta guarda `branch`, `worktree`, `agent_ref` y pasa a «En curso». Todo tras pulsar «Enviar»; nada antes.

**Contenedores:** lista agrupada por proyecto de compose, con punto de estado, nombre, imagen y puertos, miniatura de CPU, `%CPU` y memoria; los que fallan, marcados en rojo y arriba. Detalle: acciones (`Reiniciar`, `Parar`, `Shell`, `Inspeccionar`), **banner de problema** («Reiniciado 5 veces · OOMKilled · salida 137», con `Preparar prompt`), tres tarjetas (CPU, memoria, red) y **logs en vivo** con filtros `Todo/Errores/Avisos`, repetidas colapsadas (`×5`) y errores resaltados.

**Git:** rama con `↑↓`, `Pull`/`Push`; «Preparados» y «Cambios» con casilla y marca M/A/D y +/−; diff unificado con números de línea y fondos de añadido/borrado; caja de commit con chips de tipo, mensaje editable por el usuario, aviso `✓ SIN SECRETOS EN LO PREPARADO`, `Commit` y `Commit y push`; historial y ramas a la derecha; botón `Abrir en lazygit` (abre la terminal con lazygit en el repo).

**Revisión:** worktree/agente actual, interruptor «Seguir en vivo», barra «N/M vistos», lista de archivos con casilla y aviso ámbar «CAMBIÓ DESPUÉS DE VERLO»; diff con **margen para comentar** (marca ● y burbuja lavanda); a la derecha, comentarios y «Prompt de revisión» con contador de tokens y `Componer y enviar`. La casilla alimenta la puerta «archivos vistos» del Kanban.

**Compositor de prompts** (cajón de 456 px sobre el Taller, `P`): selector de plantilla; bloques como chips con sus tokens (clic = quitar/poner, tachado si está quitado); vista previa por segmentos con etiqueta y tokens; **contador grande** («≈ 296 tokens · ligero») con barra de 30 segmentos y escala 0 / 1 000 / 2 000 / 3 000+ en verde/ámbar/rojo; «✓ secretos tachados: N»; selector de destino (`claude · AX-142`, otros agentes, portapapeles); `Enviar`, `Copiar`, `Guardar plantilla`. Puntos de entrada: botón de cabecera, `Iniciar con prompt…`, `Preparar prompt` (contenedores y agentes) y `Componer y enviar` (revisión), cada uno con su plantilla.

**Explorador** (`33-*`): ventana sin barra de título. Barra lateral con *Lugares* (con marca de repos), *Dispositivos* (barra de espacio y ⏏; cifrados con «abrir»), *Red* (Red local, montajes, servidores) y *Papelera*. Barra de herramientas: atrás/adelante/subir, migas de pan editables, búsqueda (`/`), `Compartir`, interruptor lista/cuadrícula. Pestañas. Lista con nombre, tamaño, modificado, tipo, marca git (M/A) y filas alternas; cuadrícula con miniaturas. Panel derecho: para archivos comprimidos, **contenido sin extraer** (árbol parcial, método, cifrado, integridad CRC, tamaño al extraer) con `Extraer aquí`, `Extraer en…`, `Probar`; para imágenes, vista previa y datos; para el resto, propiedades y `Abrir`, `Abrir con…`, `Terminal aquí`, `Enviar al agente` (abre el compositor con la ruta como bloque `paths`). Barra de estado con selección, cola de operaciones (progreso y cancelar) y espacio libre. Diálogo de extracción (destino, carpeta propia, papelera al terminar, conflictos, aviso de rutas seguras, progreso, formatos admitidos), vista de Red (equipos encontrados, conectar a servidor, marcadores, detalle con recursos compartidos) y diálogo de compartir (nombre, permisos, invitados, direcciones copiables, advertencia ámbar).

---

## 7. Tramos

Cada punto = un commit. Al terminar cada tramo: pruebas en verde, `shellcheck -x` limpio en lo nuevo, `hyprctl configerrors` vacío, resumen corto y `docs/handoff-fase-5<x>.md`.

### 5a · Base — rama `feat/fase5a-base`
1. **Entorno:** anota versiones (`hyprctl version`, `qs --version`, `herdr --version`, `docker --version`, `git --version`) y las herramientas de §5.7 presentes/ausentes en `docs/handoff-fase-5a.md`.
2. **Filtro de secretos compartido:** extrae el de `dragon-search`/`dragon-activity` a un módulo común con pruebas; sin romper las existentes.
3. **`dragon-mem`** (§4) completo, con `tests/mem/` y migración de instalación (crea la base con copia de seguridad si existe).
4. **`dragon-herdr`** (§5.1): primero `docs/HERDR-API.md`, luego la herramienta, el herdr falso y `tests/herdr/`; migración de instalación.
5. **Servicios** `Mem` y `Herdr` (el observador va siempre activo; `--record` activado).
6. **Taller:** `TallerPanel` con cabecera, pestañas y estados vacíos; IPC `taller`; atajo `SUPER + T`; contorno y escuadras del panel con `FrameDecor`.
7. **Pestaña Agentes** (§6) con datos reales de herdr y de `dragon-mem`, y modo simulado para pruebas visuales.
8. **Isla:** `AttentionCard` + prioridad en `Priority.qml` + `SUPER + A`.
9. **Proyectos:** alta de proyectos desde el selector de la cabecera (`dragon-mem project add`) y selector funcionando.
10. Registro de cambios de configuración: Ajustes escribe en `dragon-mem system log add` cada cambio de apariencia relevante (estilo de cristal, barra, paleta).
Aceptación: con un herdr real, un agente bloqueado aparece en la lista y en la isla en menos de 2 s; `Ir ↵`/`SUPER + A` lo enfocan; sin herdr, la pestaña dice «herdr no está en marcha» y nada falla; CPU de Quickshell en reposo sin subir más de 0,3 puntos respecto a antes del tramo.

### 5b · Contenedores y Git — rama `feat/fase5b-docker-git` (desde `main` con 5a fusionado)
1. **`dragon-docker`** (§5.2) con socket falso y `tests/docker/`.
2. **`dragon-git`** (§5.3) con `tests/git/`.
3. Servicios `Docker` y `Git` (procesos largos solo con la pestaña visible).
4. **Pestaña Contenedores** con `LogView`.
5. **Pestaña Git** con `DiffView` y caja de commit; botón `Abrir en lazygit` (comprueba que existe; si no, lo dice).
6. Migraciones de instalación y entradas en `pre-instalation.md`.
Aceptación: con compose real, los contenedores y sus CPU/memoria se ven y se actualizan cada 2 s solo con la pestaña abierta; un contenedor que se reinicia en bucle aparece con banner; un commit con un `.env` preparado es rechazado con el aviso de secretos; al cerrar el Taller no queda ningún proceso `dragon-docker` ni `dragon-git watch`.

### 5c · Kanban, prompts y revisión — rama `feat/fase5c-kanban-prompts` (desde `main` con 5a y 5b)
1. **`dragon-prompt`** (§5.5) con plantillas integradas y `tests/prompt/`.
2. **`dragon-gate`** (§5.4) con `tests/gate/`.
3. Servicios `Prompts` y `Gate`.
4. **Compositor** (`PromptComposer`) con todos los puntos de entrada y envío a herdr/portapapeles.
5. **Pestaña Kanban** con WIP, puertas, métricas y arrastrar.
6. **Flujo «Iniciar»:** worktree + agente + tarjeta en «En curso» (§6).
7. **Pestaña Revisión:** `seen` por contenido, comentarios por línea, «Seguir en vivo», prompt de revisión.
8. **Exportación `.dragon/CONTEXT.md`** al cambiar de tarjeta o decisión (`dragon-mem export`), con el tamaño máximo.
9. **Opcional:** `dragon-tokens` (§5.6) y la tarjeta «Consumo de hoy».
10. Ajustes: sección «Taller» (umbrales de tokens, historial de prompts desactivado por defecto, WIP por proyecto, comando de pruebas).
Aceptación: crear una tarjeta, componer su prompt viendo los tokens, enviarlo y ver al agente trabajar en su worktree; marcar archivos vistos y que «Hecho» se habilite solo con pruebas en verde y todo visto; mover más tarjetas a «En curso» que el WIP pide confirmación; ningún prompt sale sin pulsar `Enviar`; `prompt_run` no guarda el texto con el ajuste por defecto.

### 5d · Explorador de archivos — rama `feat/fase5d-archivos` (independiente; puede ir en paralelo)
1. **d1 Listado y navegación:** `dragon-files ls/places/watch/props/open`, `FilesWindow` con barra lateral, migas de pan, pestañas, lista y cuadrícula, atajos de teclado (flechas, Intro, Retroceso, `Ctrl+L`, `/`, `Ctrl+H` ocultos), orden y selección múltiple. IPC `files` y `SUPER + E`. Ventana sin barra de título.
2. **d2 Operaciones:** copiar/mover/renombrar/crear carpeta/papelera/eliminar con cola, progreso, cancelar y conflictos; arrastrar y soltar entre pestañas; deshacer mover/renombrar; miniaturas en caché estándar; panel de vista previa y propiedades; marca git.
3. **d3 Dispositivos:** `devices` con barra de espacio, montar/desmontar/expulsar, cifrados con desbloqueo (contraseña por entrada estándar), MTP; actualización por eventos.
4. **d4 Archivos comprimidos:** listar, probar, extraer y crear con extracción segura (§5.7); `ExtractDialog`; extraer desde el menú contextual y desde el panel; arrastrar un comprimido a una carpeta.
5. **d5 Red:** descubrimiento, conectar a servidores (SMB/SFTP/NFS/FTP/WebDAV), llavero, marcadores, `NetView`.
6. **d6 Compartir:** `share` con Samba, `ShareDialog`, migración de preparación con confirmación.
7. **d7 Gestor predeterminado:** `dragon-files.desktop`, `xdg-mime default inode/directory`, y si PyGObject está disponible, `org.freedesktop.FileManager1`. Documenta cómo volver al anterior (`dragon-files --restore-default` o comando equivalente). **No desinstales ni toques Dolphin ni Nautilus.**
8. **d8 Pulido:** estados vacíos, errores legibles, teclado completo, `Enviar al agente` (abre el compositor con la ruta), migración que añade las reglas de ventana y los atajos.
Aceptación: abrir una carpeta de 5 000 archivos sin tirones; copiar entre discos con progreso y cancelar; extraer un `.zip`, un `.7z` y un `.tar.zst` y rechazar el zip malicioso de muestra; expulsar un USB; ver y montar un recurso SMB; compartir una carpeta y ver sus direcciones; «Mostrar en carpeta» desde el navegador abre este explorador (si se instaló el servicio D-Bus).

---

## 8. Seguridad y privacidad (global)

- **Secretos:** tachado antes de mostrar, contar, enviar o guardar; la salida de paneles de agentes **nunca se persiste**; `inspect` de Docker sin valores de entorno; commits bloqueados si hay secretos; contraseñas de red y cifrados solo en llavero o por entrada estándar.
- **Nada se envía solo:** ningún texto llega a un agente sin una acción explícita (`Enviar`), y se muestra el destino. Sin aprobar permisos desde el escritorio.
- **Archivos:** extracción siempre a un directorio de preparación con validación de rutas, enlaces, bits especiales, espacio y bombas; borrado permanente solo con confirmación; papelera por defecto.
- **Red:** Samba solo en red local, invitados apagados, sin tocar el cortafuegos, carpetas sensibles prohibidas.
- **Git:** nunca `--force`; no se escribe configuración de git; los push los pide el usuario.
- **Base de datos:** permisos 600, copias rotativas, sin telemetría ni red.
- **Procesos:** nada en segundo plano con el Taller o el explorador cerrados (salvo el observador de herdr).

---

## 9. Pruebas globales y entrega

- Cada herramienta tiene su carpeta en `tests/` y su paso en `tests/run-all.sh` (bloques propios y marcados). Los tiempos usan la mediana de 7 ejecuciones con límite de 300 ms; las mediciones del objetivo real van en `tests/**/bench.py`, fuera de `run-all.sh`.
- Prueba de **no regresión de ligereza**: con el Taller y el explorador cerrados, no quedan procesos nuevos salvo `dragon-herdr watch`.
- Pruebas de interfaz con servicios simulados (`tests/qml/taller_mock.qml`, `tests/qml/files_mock.qml`), y capturas guardadas en `docs/screenshots/` (optimizadas con `scripts/optimize-images.sh`).
- La suite completa debe pasar 3 veces seguidas.
- **Documentación al terminar cada tramo:** `docs/handoff-fase-5<x>.md` (qué hiciste, decisiones, lo que no pudiste ver, límites conocidos). Al terminar la fase, una sola persona añade a `docs/HANDOFF.md` una sección nueva (la siguiente libre) con la arquitectura de esta fase, los contratos de las herramientas y los atajos; actualiza `docs/KEYBINDS.md` y `README.md`.

**Resumen final de cada tramo (corto):** qué hiciste; qué debe ver el usuario en pantalla (punto por punto); qué no pudiste comprobar; decisiones que necesita.

---

## 10. Fuera de alcance de esta fase

Hosts remotos de herdr por SSH · reanudar agentes tras reiniciar (solo se guarda `session_ref`) · planificación Shape Up (apuesta, mapa, colina) y DORA de despliegues · generación de historias con IA · Podman · montajes de nube (Drive, etc.) · selector de archivos del portal de escritorio (`xdg-desktop-portal`) · multi-monitor específico.

## 11. Decisiones tomadas por defecto (si el usuario no dice otra cosa)

SQLite como fuente de verdad del Kanban, con exportación corta a `.dragon/CONTEXT.md` ignorada con `.git/info/exclude` · aprobar permisos **no** se hace desde el escritorio · Docker con Compose, sin Podman · el Taller es un panel superpuesto y el explorador una ventana normal · la plantilla por defecto de cada punto de entrada está en §6 · el historial de prompts guarda solo hash y tokens · el WIP por defecto es 3.
