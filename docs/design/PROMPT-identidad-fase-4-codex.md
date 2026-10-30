# dragon-island — Fase 4 (Codex): motores de búsqueda, de uso de apps y de portapapeles

Trabajas en la rama `feat/fase-4-motores`, creada desde `feat/nueva-identidad` (con la Fase 3 ya fusionada), en su propio worktree. Otro agente (Claude Code) hace en paralelo toda la interfaz de Quickshell y Hyprland. **No toques** `config/quickshell/`, `config/hypr/`, `sddm/` ni `shared/`. Si necesitas algo ahí, para y avísalo.

Antes de empezar lee:
- `AGENTS.md` y `.agents/skills/dragon-island/SKILL.md`;
- `docs/handoff-fase-3-codex.md` (tu trabajo anterior: sigue su estilo de instalación, pruebas y migraciones);
- `migrations/README.md` y `lib/common.sh`;
- `config/quickshell/services/Clipboard.qml` y `Apps.qml` (solo para entender qué datos usan; no los modifiques).

**Reglas:**
- Un commit por punto numerado.
- Migraciones solo desde la `032` (la `025` a la `029` son de Claude Code).
- Notas en `docs/handoff-fase-4-codex.md`.
- Sin red, sin demonios residentes, sin dependencias fuera de Python estándar salvo que lo justifiques.
- Nunca ejecutes acciones por el usuario (abrir URL, lanzar comandos, copiar): tus comandos **devuelven datos** y la interfaz ejecuta.
- Pruebas con HOME y XDG temporales. No toques el HOME real.

---

## Qué construyes

Tres comandos que el launcher de Claude Code llama con `--json`. **El contrato de abajo es fijo**: si necesitas cambiarlo, avisa antes. Se despliegan en `~/.local/bin/` con sus librerías, como hiciste con `dragon-palette`.

### 1. `dragon-search <modo> "<consulta>" [--limit N] [--lang es|en] --json`

Modos `calc`, `cmd`, `web`, `emoji`. Salida:
```json
{
  "mode": "calc",
  "query": "20% de 350",
  "results": [
    {
      "id": "calc:1",
      "title": "70",
      "sub": "20% de 350",
      "icon": "calc",
      "kind": "calc",
      "action": { "type": "copy", "value": "70" },
      "score": 0.98
    }
  ]
}
```
- `action.type`: `copy` (`value`), `open-url` (`value`), `exec` (`argv` lista y `terminal` booleano) o `none`.
- `score` va de 0 a 1 y ordena. Sin resultados, `results: []` y código 0.
- Siempre sale con código 0 salvo error de uso (modo desconocido). Un fallo interno devuelve `{"error": "..."}` con código 1.
- Límite de tiempo: menos de 150 ms por llamada.

**`calc`:**
- Evaluador **seguro propio**, sin `eval` ni `exec`. Operadores `+ - * / ^ %`, paréntesis, coma o punto decimal, funciones `sqrt sin cos tan log ln abs round`, constantes `pi e`.
- «20% de 350», «350 + 20%», «15% de propina sobre 48».
- Conversión de unidades locales: longitud, masa, volumen, temperatura, tiempo, datos (KB, MB, GiB…).
- Bases: `0xFF`, `0b1010`, y «255 a hex» / «ff a decimal».
- Sin monedas ni nada que necesite red.
- Entrada inválida, vacía o peligrosa devuelve `results: []`. Una operación enorme (como `9^9^9`) se corta con tope de tiempo y tamaño.
- El resultado se muestra sin ceros sobrantes; `action.value` es el número limpio.

**`cmd`:**
- Candidatos desde los ejecutables del `PATH` y desde el historial de zsh (`$HISTFILE` o `~/.zsh_history`, leído con `errors="replace"` y parseando el formato extendido).
- Orden por coincidencia y por frecuencia reciente. Sin duplicados.
- Descarta del historial líneas que parezcan secretos (variables `*_KEY`, `*_TOKEN`, `*PASSWORD*`, `Bearer`, URLs con credenciales).
- `action`: `{ "type": "exec", "argv": ["sh","-c","<línea>"], "terminal": true }` para líneas de historial; `terminal: false` para ejecutables sueltos.

**`web`:**
- Motores en `~/.config/dragon-island/search-engines.json`. Si no existe, valores por defecto: DuckDuckGo (por defecto), Google, GitHub, YouTube, ArchWiki, MDN, Wikipedia (ES y EN), Stack Overflow.
- Prefijos cortos al inicio de la consulta (`gh`, `yt`, `aw`, `mdn`, `wiki`, `so`): «gh quickshell» busca en GitHub.
- Devuelve una entrada por motor posible, con el motor del prefijo (o el predeterminado) primero.
- Codifica bien la URL (acentos, espacios, `&`, `#`). `action`: `open-url`.

**`emoji`:**
- Datos propios incluidos en el repo (`dragon-core/search-data/emoji.json`): emoji y símbolos útiles (flechas, matemáticos, monedas, letras griegas) con nombre y palabras clave en **español e inglés**. Genera el archivo con un script reproducible (`scripts/build-emoji-data.py`) a partir de `unicodedata` y una lista de traducciones tuya. **Indica la licencia** de cualquier fuente que uses; si no puedes usar una con licencia clara, limítate a un conjunto más pequeño escrito por ti.
- Búsqueda tolerante a acentos y mayúsculas. Los usados recientemente suben (archivo de recientes en `~/.local/state/dragon-island/emoji-recent.json`; no se escribe desde `dragon-search`, sino con `dragon-search emoji-use <id>`).
- `action`: `copy` con el carácter.

### 2. `dragon-usage`

- `dragon-usage record <desktop-id>`: suma un lanzamiento (con marca de tiempo) en `~/.local/state/dragon-island/usage.json`. Escritura atómica, con bloqueo local. Máximo 2000 eventos por app; compacta los más viejos en contadores.
- `dragon-usage stats --json`:
```json
{ "apps": [ { "id": "brave-browser", "total": 214, "week": 41, "lastUsed": 1761830000, "frecency": 0.93 } ] }
```
  `week` son los lanzamientos de los últimos 7 días. `frecency` va de 0 a 1 y se calcula con decaimiento exponencial (vida media de 7 días), normalizada por el máximo. Determinista.
- `dragon-usage forget <desktop-id>` y `dragon-usage reset`.
- Nada de rutas ni argumentos de los lanzamientos: solo el id.

### 3. `dragon-clip`

- `dragon-clip classify --json`: recibe por stdin `[{ "id", "text", "isImage" }]` y devuelve, por entrada, `{ "id", "kind", "label", "preview" }`.
  - `kind`: `command`, `link`, `path` (existe en disco), `color` (`#RGB`, `#RRGGBB`, `rgb()`, `hsl()`), `image`, `text`.
  - `label` en español («Comando», «Enlace», «Ruta», «Color», «Imagen», «Texto»).
  - `preview` es el texto recortado a 120 caracteres y **enmascarado** si parece un secreto (`sk-…`, `ghp_…`, `AKIA…`, cadenas largas sin espacios con mezcla de clases de caracteres). Devuelve también `secret: true` en ese caso.
- `dragon-clip pins list|add <id>|remove <id> --json`: fijados en `~/.local/state/dragon-island/clip-pins.json`.
- `dragon-clip meta <id> --json`: `{ "app": "ghostty", "time": 1761830000 }` o `{}` si no se anotó.
- `dragon-clip-store`: sustituto de `cliphist store` para el vigilante `wl-paste --watch`.
  - Lee el contenido por stdin y los tipos MIME con `wl-paste --list-types`.
  - **No guarda nada** si aparece `x-kde-passwordManagerHint` con valor `secret`.
  - Si no, llama a `cliphist store` y anota en un archivo aparte el hash del contenido, la clase de la ventana activa (`hyprctl activewindow -j`) y la hora. **No guarda el contenido en tu archivo**, solo el hash.
  - Si `hyprctl` falla, anota solo la hora. Nunca debe bloquear ni perder una copia.
  - Tope de 5000 anotaciones; las más viejas se descartan.

## Pruebas (`tests/engines/`)

- `calc`: más de 40 casos (porcentajes, unidades, bases, entradas hostiles, precedencia, decimales con coma, `9^9^9`, cadenas vacías). Sin `eval`: añade una prueba que falle si el código lo usa.
- `cmd`: historial extendido y simple, líneas con secretos descartadas, `PATH` simulado.
- `web`: prefijos, codificación de URL, archivo de motores propio y roto.
- `emoji`: búsqueda con y sin acentos, recientes.
- `usage`: decaimiento, normalización, concurrencia (dos escrituras a la vez), compactación.
- `clip`: cada `kind`, enmascarado de secretos, pins, `dragon-clip-store` con un `wl-paste` y un `cliphist` simulados (incluido el aviso de gestor de contraseñas).
- Tiempo: `dragon-search` por debajo de 150 ms en cada modo (mídelo y anótalo).
- Las pruebas entran en `tests/run-all.sh`.

## Migraciones

- `032-engines-install.sh`: despliega los tres comandos, `dragon-clip-store`, librerías y datos. Idempotente, con copia de seguridad, `DRY_RUN` respetado.
- `033-engines-dependencies.sh`: solo si necesitas algo más que Python estándar; si no, no la crees. Sale con `10` si el usuario rechaza.
- **No cambies** `config/hypr/autostart.lua`. Claude Code enlaza `dragon-clip-store` cuando exista. Deja documentado en tu handoff cómo debe quedar la línea.

## Comprobaciones antes de terminar

1. `dragon-search` responde en cada modo con el esquema exacto y en menos de 150 ms.
2. Ninguna ruta del código usa `eval`, `exec` de cadenas del usuario ni red.
3. `dragon-usage stats` es estable y determinista con los mismos datos.
4. `dragon-clip-store` no guarda copias de gestores de contraseñas y nunca pierde una copia normal.
5. Las migraciones son idempotentes y los scripts pasan `shellcheck`.
6. `docs/handoff-fase-4-codex.md` documenta el contrato final, la licencia de los datos de emoji y todo lo que no se pudo hacer.

Termina con un resumen corto: qué hiciste, qué desviaste y qué decisiones necesita el usuario.
