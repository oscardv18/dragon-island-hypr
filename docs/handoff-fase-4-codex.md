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

Pruebas integradas en `tests/run-all.sh`. Falta cerrar el punto 3 y verificar
el conjunto completo; este documento se completa en el siguiente commit.
