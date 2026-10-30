# dragon-island — Fase 3 (Codex): generador de paleta desde el fondo y tema de las apps externas

Trabajas en la rama `feat/fase-3-paleta`, creada desde `feat/nueva-identidad`. Otro agente (Claude Code) trabaja en paralelo en la interfaz de Quickshell y en SDDM. **No toques** `config/quickshell/`, `sddm/`, `shared/` ni `config/hypr/`. Si crees que hace falta tocar algo de eso, para y avísalo.

Antes de empezar lee:
- `AGENTS.md` y `.agents/skills/dragon-island/SKILL.md` (reglas del proyecto);
- `docs/HANDOFF.md`, solo las secciones sobre Starship, Ghostty y la terminal;
- `migrations/README.md` y `lib/common.sh`.

**Reglas:**
- Un commit por punto numerado.
- Migraciones solo en el rango `030` en adelante (`023` a `029` son de Claude Code).
- Todo cambio sobre sistemas ya instalados lleva migración, idempotente y con copia de seguridad.
- Tus notas van en `docs/handoff-fase-3-codex.md`, no en `HANDOFF.md`.
- Nunca ejecutes `pkill ghostty` ni nada que cierre ventanas del usuario.
- No edites los archivos de configuración del usuario a mano ni con `sed` frágil: genera archivos propios e inclúyelos.

---

## Qué construyes

Un comando, `bin/dragon-palette`, que:
1. Extrae una paleta de una imagen.
2. La guarda para que Quickshell la lea.
3. Tiñe herdr, Ghostty, kitty, Starship y fastfetch con ella, y los recarga sin cerrarlos.

Claude Code solo llama a tu comando y lee tu JSON. **El contrato de abajo es fijo**: si necesitas cambiarlo, avisa antes.

## El contrato

**Subcomandos:**
- `dragon-palette generate <imagen>`: escribe `~/.local/state/dragon-island/palette.json` de forma atómica (archivo temporal y `rename`). Debe tardar menos de 1 s con una imagen 4K. Sale con `0` aunque la imagen sea apagada (devuelve la paleta Dragon con `fallback: true`). Sale con error solo si la imagen no existe o no se puede leer.
- `dragon-palette apply`: lee `palette.json`, regenera los archivos de las apps externas y las recarga.
- `dragon-palette reset`: borra `palette.json` y devuelve las apps a la paleta Dragon fija.
- `dragon-palette status`: imprime `enabled` o `disabled` y la fuente.
- Todos aceptan `--dry-run` y `--quiet`.

**Esquema de `palette.json`:**
```json
{
  "version": 1,
  "source": "/ruta/al/fondo.jpg",
  "sourceHash": "sha1 de la imagen reducida",
  "fallback": false,
  "accent": "#C8B6E6",
  "accentSoft": "#DCCFF0",
  "accentDeep": "#7E6BA8",
  "glow": "#B26BFF",
  "onAccent": "#16121F",
  "tint": "#0D0B16",
  "swatches": ["#...", "#...", "#...", "#...", "#..."]
}
```
Todos son `#RRGGBB` en mayúsculas.

**Paleta Dragon por defecto (la del `fallback` y de `reset`):** accent `#C8B6E6`, accentSoft `#DCCFF0`, accentDeep `#7E6BA8`, glow `#B26BFF`, onAccent `#16121F`, tint `#0D0B16`. Los colores `ok #86EFAC`, `warn #F5B04A` y `alive/cyan #67E8F9` **no entran en el JSON ni se tiñen nunca**: son semánticos y fijos.

---

## 1. Extracción de la paleta

1. Lenguaje: Python 3 con la biblioteca estándar y, si hace falta, Pillow (`python-pillow` en Arch). Añade la dependencia a `packages/` siguiendo el formato existente, y a `doctor.sh` si el proyecto comprueba dependencias. Si ya hay `matugen` instalado y prefieres usarlo, explica por qué antes.
2. Reduce la imagen a unos 128 px por lado antes de analizarla. Calcula `sourceHash` sobre la imagen reducida, no sobre el archivo.
3. Algoritmo, determinista (la misma imagen da siempre la misma paleta):
   - cuantiza a unos 12 grupos de color;
   - descarta grupos casi negros, casi blancos y casi grises (saturación baja);
   - puntúa por población × saturación, con un tope de saturación para que no salgan colores chillones;
   - `accent` es el mejor grupo, ajustado a una luminosidad que se lea bien sobre cristal oscuro (L entre 0,68 y 0,82 en OKLCH o equivalente);
   - `accentSoft` es más claro y menos saturado, `accentDeep` más oscuro, `glow` más saturado;
   - `onAccent` es el texto oscuro o claro que da **contraste ≥ 4,5:1** sobre `accent`;
   - `tint` es un tono muy oscuro del mismo matiz para fondos de cristal (luminosidad ≤ 0,12);
   - `swatches` son 5 colores variados del fondo, de más a menos presentes.
4. Si no queda ningún grupo con color suficiente (fondo gris, casi monocromo), devuelve la paleta Dragon con `fallback: true`.
5. Pruebas en `tests/palette/`: imágenes pequeñas generadas por código (no subas fotos), con casos de fondo azul, rojo, verde, gris, negro y casi blanco. Comprueba determinismo, contraste de `onAccent` y que `fallback` salte en los casos grises.

## 2. Plantillas de las apps

Cada app tiene su plantilla en `dragon-core/palette-templates/` y el comando genera el resultado en `~/.config/dragon-island/palette/`. Los archivos del usuario solo ganan **una línea de inclusión** (en una migración), nunca se reescriben enteros.

1. **Ghostty:** tema generado `dragon-dynamic` (cursor, selección, y los colores 4 y 12 derivados del acento; el resto de la paleta ANSI se queda como está). La configuración incluye ese tema con `theme = dragon-dynamic`. Recarga con la señal o el atajo de recarga de la versión instalada; revisa cuál soporta, sin cerrar ventanas.
2. **kitty:** archivo `dragon-dynamic.conf` incluido desde `kitty.conf` con `include`. Recarga con `kitty @ set-colors` si el control remoto está activo, o con `SIGUSR1`.
3. **Starship:** hoy tiene colores fijos escritos en cada módulo. Cambia la configuración para usar `palette = "dragon"` y una tabla `[palettes.dragon]` con nombres (`accent`, `accent_soft`, etc.). `dragon-palette apply` solo reescribe el bloque `[palettes.dragon]` entre marcadores `# >>> dragon-palette` y `# <<< dragon-palette`. Los colores semánticos de error y éxito quedan fijos.
4. **herdr:** revisa en `config/herdr/config.toml` y en la documentación qué claves de tema acepta. Si admite un tema o colores por archivo, genera ese archivo. Si no, di exactamente qué falta y deja herdr sin tocar.
5. **fastfetch:** mira `fastfetch-theme/` (tiene un `PROMPT-fastfetch.md` con sus reglas). Genera solo el archivo de colores, sin cambiar la estructura de la salida.
6. Cada plantilla tiene un archivo de salida de ejemplo en `tests/palette/golden/` y una prueba que compara el resultado con él.

## 3. Cómo se aplica y se revierte

- `apply` es idempotente: si `sourceHash` no cambió desde la última aplicación, no hace nada.
- Guarda `sourceHash` aplicado en `~/.local/state/dragon-island/palette.applied`.
- Si una app no está instalada o no se puede recargar, sigue con las demás y lo registra en `--quiet`-compatible (código de salida `0`, aviso en stderr).
- `reset` devuelve cada app a la paleta Dragon fija regenerando los mismos archivos con los colores por defecto. No los borra, para que las líneas de inclusión no queden rotas.
- Sin dependencias de red. Sin demonios residentes.

## 4. Migraciones

- `030-palette-templates.sh`: instala las plantillas, crea `~/.config/dragon-island/palette/` con la paleta Dragon por defecto y añade **una línea de inclusión** en Ghostty y kitty. En Starship convierte los hex fijos a nombres de paleta; haz una copia de seguridad antes y respeta `DRY_RUN`.
- `031-palette-dependencies.sh`: instala la dependencia de Python si hace falta (con `confirm`), y sale con `10` si el usuario dice que no.

## 5. Comprobaciones antes de terminar

1. `dragon-palette generate` con tres fondos reales distintos (uno lo pone el usuario) da paletas distintas y estables.
2. `generate` tarda menos de 1 s en una imagen 4K.
3. `apply` recarga Ghostty y kitty abiertos sin cerrarlos.
4. `reset` deja las apps como estaban antes de la Fase 3.
5. Las migraciones son idempotentes: ejecutarlas dos veces no cambia nada.
6. `shellcheck` limpio en los scripts de shell y las pruebas pasan.
7. `docs/handoff-fase-3-codex.md` documenta el contrato final, las claves que herdr acepta y todo lo que no se pudo hacer.

Termina con un resumen corto: qué hiciste, qué desviaste y qué decisiones necesita el usuario.
