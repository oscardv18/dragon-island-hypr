# Fase 4 — Codex: motores offline

2026-10-30. Rama `feat/fase-4-motores`, worktree `/home/oddv/Devs/dragon-motores`,
base `4a7a0ff` de `feat/nueva-identidad` con fase 3 integrada.
No se modifican `config/quickshell/`, `config/hypr/`, `sddm/`, `shared/` ni
`docs/HANDOFF.md`. Un commit por punto numerado; solo Python estándar, sin red
ni demonios. Todas las pruebas usan HOME y XDG temporales.

## 1. Búsqueda

`dragon-search calc|cmd|web|emoji '<consulta>' [--limit N] [--lang es|en] --json`.
JSON con `mode`, `query`, `results`; cada resultado contiene exactamente `id`,
`title`, `sub`, `icon`, `kind`, `action`, `score` (0–1, descendente).
Sin resultados: lista vacía y código 0; uso incorrecto: código 2;
fallo interno: `{"error":"..."}` y código 1. La salida es JSON también sin `--json`.
Límite predeterminado 20, máximo 100; 0 o negativo devuelve lista vacía.
Los identificadores son estables. Las acciones se devuelven sin ejecutarlas.

- **calc**: parser recursivo propio con 160 tokens / 1024 caracteres, plazo interno
  de 35 ms y valor absoluto máximo 1e100. Potencias asociativas a la derecha;
  `-2^2 = -4`. `%` es módulo si sigue un operando (`10%3`), porcentaje al final
  de un operando (`20%`, `350+20%`), y se entiende `% de`, `% of` y propina.
  Funciones trigonométricas en radianes, `log` base 10, `ln` natural, `round`
  con redondeo de Python (empates al par). Precisión opcional: `round(1.234;2)`;
  el separador es `;` para conservar la coma decimal. Resultados con 12 cifras
  significativas y sin ceros sobrantes. Conversiones locales, no monetarias;
  `KB=1000 B`, `KiB=1024 B`, `B` byte, `bit` bit, galón/taza estadounidenses.
  Temperatura C/F/K. `255 a hex` copia `0xff`, `ff a decimal` copia `255`.
- **cmd**: nombres ejecutables de PATH y últimos 512 KiB / 4000 registros de zsh,
  incluidos extendidos y multilínea con continuación. Deduplica y ordena por
  coincidencia y frecuencia con decaimiento de siete días. Filtra secretos antes
  de publicar. Si una línea coincide con un nombre de PATH, conserva el candidato
  ejecutable (`terminal:false`); las demás líneas usan `['sh','-c',línea]` y
  `terminal:true`. El motor jamás ejecuta esos argv.
- **web**: nueve motores locales; no se consultan. Un prefijo reconocido se quita
  para todos los resultados; `wiki` prefiere el idioma de `--lang`.
  Configuración opcional en `$XDG_CONFIG_HOME/dragon-island/search-engines.json`:
  `{"default":"own","engines":[{"id":"own","name":"Own","prefix":"o","url":"https://example.org/?q={query}"}]}`.
  `lang` opcional (`es`/`en`) distingue prefijos repetidos. Archivo ausente,
  roto o inválido: valores predeterminados; solo plantillas HTTP(S) sin credenciales.
- **emoji**: datos propios de `dragon-core/search-data/emoji.json`, regenerables
  con `python3 scripts/build-emoji-data.py`. Anotaciones bilingües originales
  CC0-1.0; nombres normativos de `unicodedata`, Unicode-3.0 / distribución Python
  PSF. Sin corpus externo. Véase `dragon-core/search-data/README.md`.
  Buscar no escribe nada. `dragon-search emoji-use <id>` registra el uso con
  escritura atómica y bloqueo en `emoji-recent.json` (máximo 100 recientes).

## 2. Uso de aplicaciones

`dragon-usage record <desktop-id>`, `stats --json`, `forget <desktop-id>`, `reset`.
Mutaciones responden `{"ok":true}`; stats devuelve `{"apps":[...]}` según el contrato.
Solo se aceptan IDs (letras, cifras, punto, guion, guion bajo, más; máximo 255).
Nunca rutas, argumentos ni contenido de los lanzamientos. No importa automáticamente
los contadores de `launcher.json`: la interfaz decide cuándo empezar a registrar.

`$XDG_STATE_HOME/dragon-island/usage.json` tiene versión 1. Cada app conserva hasta
2000 eventos; el exceso se agrupa por segundo durante siete días y después se
reduce a contador y suma exponencial con fecha de referencia. Así `week` sigue
siendo exacto incluso con más de 2000 lanzamientos semanales y la compactación
conserva la curva de decaimiento, con vida media de siete días. `week` usa
`ahora-7d < tiempo <= ahora`; `frecency` se normaliza por el máximo y se redondea
a doce decimales. El cálculo usa una referencia común para evitar que el paso de
unos segundos altere las proporciones con los mismos eventos. Orden: frecency
descendente e ID en empates. Sin eventos: lista vacía, sin crear archivos.

Todas las escrituras comparten `flock` sobre un archivo separado, archivo temporal
0600, fsync y reemplazo atómico. Un estado corrupto produce error sin sobrescribir
el original. Las consultas no escriben. Verificadas dos instancias simultáneas,
compactación, ventanas temporales, normalización, olvido y reset.

## 3. Portapapeles

- `dragon-clip classify --json` lee un array y devuelve un array, en el mismo
  orden, con `id`, `kind`, `label`, `preview`; `secret:true` solo si se detectó
  un secreto. Vista previa de hasta 120 caracteres, enmascarada **antes** de
  recortar; cubre claves conocidas, asignaciones, Bearer, URL con credenciales
  y tokens opacos largos. La detección es heurística, no una certificación de
  ausencia de secretos. Clasifica imagen, color, enlace, ruta existente, comando
  conocido y texto, en ese orden. Reconocer un comando no lo ejecuta.
- `dragon-clip pins list|add <id>|remove <id> --json` responde siempre
  `{"pins":["12","34"]}`. El archivo `clip-pins.json` contiene solo ese array
  de IDs, sin texto; bloqueo, escritura atómica y operaciones idempotentes.
- `dragon-clip meta <id> --json` responde `{app,time}`, solo `{time}` si falló
  Hyprland, o `{}` sin dato. Los IDs de cliphist no son hashes: se decodifica el
  ID **en memoria**, sin copiarlo al portapapeles ni a otro archivo, y se busca su
  SHA256. Una copia repetida del mismo contenido muestra su anotación más reciente.
- `dragon-clip-store` conserva el flag de pausa de la fase 2. Consulta MIME con
  `wl-paste --list-types`; si se anuncia `x-kde-passwordManagerHint`, lee ese tipo
  con `wl-paste --type x-kde-passwordManagerHint --no-newline`. Omite `secret` y
  también un hint anunciado pero ilegible; respeta `CLIPBOARD_STATE=sensitive`.
  Para copias normales envía los bytes exactos a `cliphist store` **antes** de
  intentar guardar los metadatos. Estos van a `clip-meta.json` (v1, mapa `items`
  por SHA256), con clase y hora, sin contenido, título, PID ni argumentos.
  Máximo 5000 hashes; se descartan los más viejos. Consultas auxiliares limitadas
  a 250 ms, lectura de meta a 750 ms y store a 2 s; bloqueo de anotaciones no
  bloqueante. Un fallo de Hyprland, archivo corrupto, permisos o bloqueo de
  metadatos no pierde la copia que ya está en cliphist. Un fallo/timeout del
  propio cliphist se devuelve como error: no se simula un guardado exitoso.

## Instalación e integración con Claude Code

`migrations/032-engines-install.sh` y `lib/engines.sh` despliegan bibliotecas y datos
en `$XDG_DATA_HOME/dragon-island/engines/` y los cuatro comandos en `~/.local/bin/`.
Usan `deploy_item`, respaldo y manifest. Se prueban por copia y por enlaces;
segunda ejecución sin cambios ni nuevos respaldos; dry-run standalone sin crear
ni el directorio de estado. El módulo core llama al mismo helper en instalaciones
nuevas. No hay `033`: Python estándar ya está en las dependencias de core.
`ASSUME_YES` sigue el entorno común; no se requieren decisiones adicionales ni
sudo. Si falta Python, 032 sale 10 para reintentar después de instalarlo.

**Integración reservada a Claude**, sin editar aquí autostart ni QML:

```text
wl-paste --type text --watch dragon-clip-store
wl-paste --type image --watch dragon-clip-store
```

Ambos vigilantes deben encontrar `~/.local/bin` en PATH (o usar su ruta absoluta).
Para emoji, la interfaz llama `emoji-use <id>` cuando acepta una selección; buscar
no actualiza recientes. Para apps, llama `dragon-usage record <desktop-id>` al
lanzar. Pins responde con objeto `pins`, classify con array. El servicio ejecuta
los `action` del buscador; los módulos visuales continúan llamando al servicio.

No se ejecutaron migraciones ni motores contra el HOME real ni se reiniciaron
los vigilantes de la sesión. La integración se hace fusionando la rama y usando
el flujo de actualización del proyecto; no basta con copiar los wrappers.

## Verificación final

- **40 pruebas** en `tests/engines/`, incluidas en `tests/run-all.sh`: más de 40
  expresiones válidas (60+), entradas hostiles y excesivas, AST sin ejecución
  dinámica ni red, CLI y esquemas, historial extendido/simple/multilínea con UTF-8
  roto, secretos excluidos, PATH simulado, motores propios/rotos y codificación,
  emojis bilingües/acentos/recientes y generación reproducible, uso concurrente y
  compactado, seis clases de clip, enmascarado, pins, metadatos y sus límites,
  copias binarias exactas, pausa, hints secretos/ilegibles, fallos/timeouts y
  bloqueo ocupado, despliegue e idempotencia.
- `tests/run-all.sh --no-qml` en HOME/XDG temporales terminó **TODO EN VERDE**:
  shellcheck y bash -n en 73 scripts; Lua válido; 34 pruebas de paleta, pruebas de
  motores, documentación coherente, shared sincronizado, instalación idempotente
  y dry-run general sin rastro. Tras la revisión final de privacidad y rendimiento,
  se repitió toda la suite de motores: 40 pruebas correctas.
- `shellcheck -x` limpio en todos los scripts nuevos/modificados; `git diff --check`
  limpio. Ningún cambio en los directorios reservados ni en `docs/HANDOFF.md`.

Tiempos finales del **CLI completo**, cinco procesos por consulta, en esta máquina;
PATH instalado y 4000 registros **distintos** en historial temporal para cmd:

| Modo / consulta | Cinco medidas (ms) |
|---|---|
| calc / `20% de 350` | 69,9 / 66,4 / 66,2 / 66,3 / 65,3 |
| cmd / `git` | 112,9 / 113,8 / 111,0 / 110,5 / 110,8 |
| cmd / vacía | 121,9 / 120,9 / 121,3 / 121,9 / 120,2 |
| web / `gh quickshell` | 68,9 / 70,7 / 71,1 / 67,4 / 70,1 |
| emoji / `corazón` | 66,9 / 71,6 / 68,4 / 65,3 / 68,5 |

Todas <150 ms. El test mide arranque del wrapper y Python, no solo la función.
La búsqueda de comandos evita normalizar ASCII carácter a carácter y selecciona
los mejores N candidatos antes de crear los resultados. Estos tiempos no garantizan
latencia en PATH sobre discos/red lentos, HOME remoto ni máquinas distintas.

**No verificado**: launcher y tarjetas en pantalla, integración de los servicios
QML de Claude, MIME de un gestor de contraseñas real ni los vigilantes reales.
wl-paste, cliphist y hyprctl se simularon dentro de HOME temporal; no se leyó ni
alteró el portapapeles de la sesión. Cuando se integren, deben verse resultados
al escribir `=`, `>`, `?`, `:`, tipos/previas en las tarjetas del historial y uso
semanal al pasar por las apps. No se afirma haber observado esa interfaz.

**Desviaciones y decisiones**: ninguna modificación del contrato acordado ni
nuevas dependencias. Se concretan arriba los formatos auxiliares no fijados
(pins y motores propios), semántica de `%` / `round` y compactación exacta.
No quedan decisiones de usuario pendientes; queda la integración y prueba visual
en la rama de interfaz. El fallo de una dependencia externa no puede garantizar
un guardado; el wrapper lo informa y no conserva contenido en un almacén paralelo.
