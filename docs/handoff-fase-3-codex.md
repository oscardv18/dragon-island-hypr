# Fase 3 — Codex: paleta del fondo y aplicaciones externas

2026-10-30. Rama `feat/fase-3-paleta`, worktree `/home/oddv/Devs/dragon-paleta`.
Cambios sobre `d406972` de `feat/nueva-identidad`. Un commit por punto del prompt.
No se modificaron `config/quickshell/`, `config/hypr/`, `sddm/`, `shared/` ni
`docs/HANDOFF.md`; el trabajo simultáneo de Claude queda en su worktree.

## Contrato final

`bin/dragon-palette` ejecuta Python 3.11+; Pillow solo se importa en `generate`.
Se despliegan el comando y `dragon-fastfetch` en `~/.local/bin/`, y librerías y
plantillas en `${XDG_DATA_HOME:-~/.local/share}/dragon-island/palette/`.
Se respeta XDG también para configuración y estado.

| Orden | Resultado |
|---|---|
| `generate <imagen>` | Reduce a un máximo de 128×128, cuantiza 12 grupos y publica atómicamente `palette.json`. JPEG usa decodificación reducida. |
| `apply` | Valida el JSON v1 y regenera los archivos externos; si `palette.applied` contiene el mismo `sourceHash`, no escribe ni recarga. |
| `reset` | Borra `palette.json` y regenera los mismos archivos con **los colores anteriores a la fase 3**, por decisión explícita del usuario. Conserva las inclusiones. |
| `status` | Imprime `enabled <source>` o `disabled Dragon`. |

Las cuatro órdenes aceptan `--dry-run` y `--quiet`, antes o después del
subcomando. El dry-run no crea estado ni toca archivos; `--quiet` silencia salida
normal y avisos de apps, pero conserva errores. `status` siempre informa el estado.
`apply` sin JSON da un error: hay que generar una paleta primero.

`palette.json` conserva exactamente las claves del contrato: `version`, `source`,
`sourceHash`, `fallback`, `accent`, `accentSoft`, `accentDeep`, `glow`, `onAccent`,
`tint`, `swatches`. Colores en `#RRGGBB` mayúsculas, cinco swatches, SHA1 sobre
las dimensiones y los píxeles RGB reducidos, nunca sobre el archivo original.
No se añaden claves semánticas al JSON.

Extracción determinista: selección por población × saturación limitada; se filtran
negros, blancos y neutros; conversión OKLCH con reducción de croma al gamut sRGB.
Acento L=0,76, tinte L=0,10, texto elegido por contraste WCAG ≥4,5:1.
Un fondo apagado devuelve los seis valores Dragon acordados y `fallback: true`,
con código 0. Las imágenes transparentes se componen sobre el tinte Dragon.

`apply` y `reset` comparten un bloqueo local. Los archivos se escriben mediante
rename atómico. El bloque de Starship se respalda por hash de contenido antes de
modificarlo; cualquier contenido fuera de sus marcadores se conserva. Los avisos
de apps ausentes o sin recarga no cambian el código 0. No hay red ni demonios.
`palette.applied` guarda el SHA1 aplicado, o `legacy-v1` tras `reset`.

## Plantillas y recarga

Salidas en `${XDG_CONFIG_HOME:-~/.config}/dragon-island/palette/`:

| Archivo | Uso |
|---|---|
| `dragon-dynamic` | Tema Ghostty, enlazado desde `ghostty/themes/dragon-dynamic`. |
| `ghostty.conf` | `theme = dragon-dynamic` y overrides explícitos, incluidos una sola vez desde el config principal. |
| `dragon-dynamic.conf` | Inclusión de kitty: cursor, selección, ANSI 4/12 y pestaña activa. |
| `starship.toml` | Bloque que sustituye únicamente `[palettes.dragon]` entre los marcadores acordados. |
| `fastfetch-colors.json` | Solo colores SGR; el wrapper los combina con el JSONC existente en memoria. |

Ghostty 1.3.1 da prioridad a los colores explícitos del config frente a un tema:
por eso la inclusión generada aplica los mismos seis valores que el tema.
No cambia la tipografía, el cristal ni los demás colores ANSI. Recarga con
SIGUSR2, documentada por Ghostty y por su unidad systemd instalada.
kitty 0.49.2 recarga con SIGUSR1; si hay socket remoto y una instancia coincidente,
también se usa `kitty @ set-colors --all --configured` con timeout de 2 s.
Solo se señalizan ejecutables del mismo UID y raíz de configuración, y cuando
`/proc/<pid>/status` confirma un manejador de la señal. Un HOME temporal no
recarga las terminales de la sesión real.

Starship y fastfetch leen los colores en la siguiente invocación. El wrapper zsh
nuevo se carga en shells nuevos; un shell ya abierto puede cargarlo con
`source ~/.config/dragon-island/zsh/fastfetch.zsh` (o la ruta del instalador
standalone: `~/.config/dragon-island/fastfetch.zsh`). No se inyecta código en los
shells abiertos ni se cierra ninguna terminal.

Error y éxito de Starship permanecen fijos. Durante la aplicación dinámica,
ok `#86EFAC`, warn `#F5B04A` y cyan `#67E8F9` son constantes, independientes de
la imagen. `reset` recupera los valores previos de cada aplicación, incluidos los
colores distintos de usuario/directorio y de duración/estado Git de Starship.
El archivo `legacy.json` describe esa referencia, con golden por cada salida.

## herdr: límite comprobado

Instalado: herdr 0.9.5. Se consultaron `herdr --default-config`, la documentación
y el lector de configuración oficial. `[theme]` admite `name`, `auto_switch`,
`dark_name`, `light_name`; `[theme.custom]` admite estos tokens de color:

`accent`, `panel_bg`, `sidebar_bg`, `active_row_bg`, `selection_bg`, `surface0`,
`surface1`, `surface_dim`, `overlay0`, `overlay1`, `text`, `subtext0`, `mauve`,
`green`, `yellow`, `red`, `blue`, `teal`, `peach`. También existen subtables
`light` y `dark` con los mismos tokens.

Valores: hex, nombres, `rgb(r,g,b)` y alias `reset/default/none/transparent`.
No hay inclusión de un archivo de tema/colores; `name` selecciona un tema
incorporado. Falta un mecanismo para cargar overrides desde un archivo externo.
Se deja herdr sin modificar, como permite el punto 2.4. Su tema actual `terminal`
puede reflejar parte de la paleta ANSI del host; no se presenta como integración
completa ni verificada. No se recarga ni reinicia el servidor o sus agentes.

Fuentes: [configuración herdr](https://herdr.dev/tui/docs/configuration/),
[lector de configuración](https://github.com/herdrdev/herdr/blob/master/src/config/io.rs),
[tokens de tema](https://github.com/herdrdev/herdr/blob/master/src/config/theme.rs),
[recarga Ghostty](https://ghostty.org/docs/linux/systemd),
[recarga kitty](https://sw.kovidgoyal.net/kitty/conf/).

## Decisiones confirmadas por el usuario

1. **Fastfetch:** aprobado generar solo `fastfetch-colors.json` y adaptar el
   wrapper. El binario 2.70.0 rechaza dos `--config` con «only one config file
   can be loaded». La combinación se entrega por stdin sin reescribir el JSONC.
   Se conservan módulos, orden, textos, comandos, logo y su selección gráfica/ASCII.
   Un `-c/--config` explícito omite la combinación para respetar presets.
2. **Reset:** el usuario eligió «Los colores anteriores a la fase 3», resolviendo
   la contradicción entre el contrato de reset lavanda y la comprobación 5.4.
   El fallback del JSON sigue siendo Dragon lavanda. Tras reset, Quickshell
   vuelve a su Dragon fijo al desaparecer el JSON y las apps a su referencia previa.
3. **Fondo de prueba:** el usuario eligió el fondo actual, Kawah Ijen.

No quedan decisiones de diseño pendientes.

## Migraciones e instalación

- `030-palette-templates.sh`: despliega comandos, librerías y plantillas; crea
  archivos con Dragon fijo si no hay estado, preserva una paleta dinámica existente
  o un reset previo, añade una sola inclusión a Ghostty/kitty y convierte Starship
  mediante cadenas TOML validadas. Actualiza los wrappers propios que ya existan.
  Respalda con `backup_copy` antes de editar. Los directorios enlazados de las
  terminales se copian conservando su contenido antes de añadir la inclusión;
  nunca se modifica su archivo original en el repo. Si ni Python está disponible,
  sale 10: después de 031 se reintenta en la siguiente actualización.
- `031-palette-dependencies.sh`: instala Python/Pillow solo si faltan, mediante
  `confirm`/`ensure_pacman`; sale 10 ante rechazo o sudo deshabilitado. No necesita
  red si las dependencias ya están disponibles.
- El módulo core despliega el comando también en instalaciones nuevas. Shell
  conserva un Starship existente y lo convierte sin sustituirlo entero.
- `update.sh` reconoce las configuraciones con paleta y las conserva, evitando
  perder inclusiones o sobrescribir el bloque dinámico al convertir copias a enlaces.
- Dependencias en `packages/pacman-core.txt`, comprobación de Pillow en `doctor.sh`
  y tabla de paquetes regenerada en `pre-instalation.md`.

No se ejecutaron migraciones reales, instalación de paquetes ni modificaciones de
fastfetch en el HOME del usuario. Sus reglas exigen HOME temporal para pruebas.
Para integrar: fusionar esta rama con `feat/nueva-identidad` y ejecutar el flujo de
actualización del proyecto; no basta con copiar el ejecutable sin sus librerías.

## Verificación

34 pruebas en `tests/palette/`, incorporadas a `tests/run-all.sh`:
no aplicar paletas solo generadas durante una migración, extracción azul/rojo/verde/gris/negro/casi blanco, determinismo, hash de píxeles,
contraste, L de acento y tinte, golden actuales y legacy, TOML, preservación de
contenido, ausencia de recarga sin manejador o con otra configuración, errores de
apps, JSON inválido, idempotencia de apply/reset y migraciones, dry-run sin archivos,
rechazo de dependencias con código 10, instalación por copia y enlaces sin tocar
el repo, y lectores nativos de Ghostty, kitty y fastfetch.

También se comprobó Starship 1.26.0 real (`username`, `directory`, `character`,
`git_branch`), sin errores y con los RGB esperados. `shellcheck -x` y `bash -n`
limpios en 65 scripts; `zsh -n` en los wrappers; Lua válido; núcleos compartidos
sincronizados; instalación completa idempotente en HOME temporal; dry-run general
sin modificar configuraciones. La tabla de paquetes detectada como desactualizada
se regeneró y `tests/check-docs.sh` pasó. La ejecución general
`tests/run-all.sh --no-qml` terminó «TODO EN VERDE»; las 34 pruebas de paleta
volvieron a pasar después de la última corrección de migración.

Tres JPEG reales 3840×2160; tres ejecuciones completas del CLI por imagen en
HOME temporal, todas estables y con acentos distintos:

| Fondo | Acento | Tiempos (s) |
|---|---|---|
| `kawah-ijen-crater-3840x2160-27374.jpg` (actual) | `#DB9EAB` | 0,148 / 0,144 / 0,133 |
| `iron-man-vs-doctor-3840x2160-25811.jpg` | `#88BEB1` | 0,138 / 0,140 / 0,137 |
| `black-asta-black-3840x2160-22972.jpg` | `#E199B1` | 0,132 / 0,131 / 0,126 |

Las fotos no se añadieron al repo. Son mediciones de esta máquina, no una garantía
de tiempo para cualquier formato/equipo.

**Recarga real verificada:** `python3 tests/palette/live-reload.py <fondo-actual>`
abre Ghostty y kitty con HOME/XDG temporales en `special:dragon-palette-check`
oculto. Consulta ANSI 4/12 por OSC antes, después de apply y después de reset;
comprueba que los PID permanecen iguales. Sus procesos de prueba terminan al
salir su propio comando; no usa cierres de ventanas del usuario. Ambas terminales
respondieron:

| Estado | ANSI 4 | ANSI 12 |
|---|---|---|
| Dragon inicial | `#7E6BA8` | `#C8B6E6` |
| Apply del fondo actual | `#905E69` | `#DB9EAB` |
| Reset anterior a fase 3 | `#7C3AED` | `#945DF0` |

Las dos ventanas sobrevivieron a apply/reset con sus mismos procesos y después
terminaron; comprobado que no quedó ninguna ventana de prueba. `hyprctl
configerrors` estaba vacío. Esta prueba opcional no se ejecuta en `run-all.sh`.

**No verificado:** comparación visual mediante captura, logo PNG dentro de
Ghostty, integración de las ramas y el flujo completo de Quickshell → comando
instalado en el perfil real. No se afirma que esas comprobaciones hayan pasado.
Tras instalar, el usuario debería ver cambiar cursor, selección y azules 4/12,
pestaña de kitty y acentos del prompt/fetch sin cerrar ventanas; reset debería
devolver sus colores magenta/violeta anteriores.
