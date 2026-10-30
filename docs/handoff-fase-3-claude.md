# Fase 3 · Claude Code — selector orbital, el shell toma el color del fondo y login SDDM (2026-10-30)

Rama `feat/nueva-identidad`, prompt `docs/design/PROMPT-identidad-fase-3-claude.md`, un commit por punto (1–7) más este documento. Capturas en `docs/screenshots/identidad/` (`orbital-*.png`, `paleta-transicion.png`, `ajustes-paleta-fondo.png`, `login-*.png`). Codex (generador `bin/dragon-palette` y plantillas de las apps) no había empezado cuando se hizo esto: todo se probó con un `palette.json` hecho a mano y un `dragon-palette` provisional que solo registraba las llamadas. **Ambos se borraron al terminar.**

## Hecho

- **1 Servicio y `Theme`** (`7d4427b`): `services/WallPalette.qml` lee `~/.local/state/dragon-island/palette.json` (`FileView` + `watchChanges`; sigue el archivo tras un `rename` atómico, tras borrarlo y al recrearlo) y valida cada color. `Theme` recibe `paletteOn` / `wallPalette` con `Binding` desde `shell.qml` y sigue siendo la única fuente: `accent`, `lavender`, `lavenderInk`, `lavenderDeep`, `violetBase`, `coreNode`, `threadPink`, `textOnAccent`, `accentShade` y `switchOn` siguen la paleta solo si `Settings.wallpaperPalette`, el archivo es válido y **no** es `fallback`. Si no, valen los Dragon fijos (`Theme.dragon.*`). Cada uno se anima con `ColorAnimation` (curva `estandar`, `Theme.motion.paleta` = 600 ms). `accentTint` / `accentEdge` salen de `violetBase`, así que `accentIntensity` sigue funcionando. `NeuralCore` gana `identity` (por defecto los colores Dragon; `alert` / `ok` fijos). La barra, el notch, el dock, el lanzador y el bloqueo le pasan `Theme.coreIdentity`.
- **2 Ajustes › Apariencia** (`d406972`): «Paleta desde el fondo» con los cinco `swatches` junto al interruptor, como en `14-fondos.png`, y «Aplicar a las apps» (`Settings.paletteApplyExternal`, nuevo; IPC `settings paletteApplyExternal`). Apagar → `dragon-palette reset` y el shell vuelve a Dragon con animación. Encender → `generate` sobre el fondo actual (+ `apply`).
- **3 Fondo → paleta** (`70f0ad8`): `Wallpaper.apply` lee los dos ajustes y pasa `DRAGON_PALETTE=generate|apply` a `scripts/wallpapers.sh`. El script, una vez que `current-wallpaper` apunta a la imagen (o al fotograma de un GIF o vídeo), lanza `dragon-palette` desacoplado (`setsid`) y con `nice 10`. No regeneran: restaurar el fondo al iniciar sesión, ni cambiar a la copia reducida de un vídeo grande.
- **4 Selector orbital** (`e73f6f0`): `modules/wallpapers/DesktopCatcher.qml` (capa `Bottom`, `dragon-desktop`) y `OrbitalPicker.qml`, dentro de `WallpaperWindow` (misma capa `dragon-wallpapers`, sin velo; la cuadrícula clásica sigue ahí como panel `wallpapers`).
  - Anillo elíptico de hasta 12 miniaturas, que salen con `orbita` y 28 ms de escalonado. Se desplaza hacia dentro cerca de un borde, sin tapar la barra ni la pastilla de ayuda.
  - En el centro, un disco de 112 px con borde discontinuo: nombre y `ACTUAL` / `CLIC PARA APLICAR` / `ELIGE UNO`.
  - Con más de 12 fondos, la rueda gira el anillo. La pastilla de ayuda solo se ve en reposo; el botón «Cuadrícula» abre la cuadrícula clásica.
  - Al elegir uno: la miniatura vuela al centro, crece hasta cubrir la pantalla y se desvanece sobre el revelado `grow` de `awww`, con `--transition-pos` en el centro de la pantalla.
  - Una sola `Region` con un elemento fijo.
  - IPC: `wallpaper orbital` / `orbitalAt x y`. `SUPER + W` llama a `wallpaper orbital`.
- **5 Tira de colores** (`f3a81f9`): `components/PaletteStrip.qml`, con `ColorQuantizer` sobre la miniatura ya hecha, solo mientras está bajo el cursor o elegida con el teclado. La caché de la sesión está en `WallPalette.previews`. Aparece en el orbital (bajo la miniatura) y en la cuadrícula (abajo de la celda).
- **6 Login SDDM** (`c3659eb`): `Main.qml` rehecho según `07-login.png`.
  - Fecha y hora; DRAGONOS + saludo según la hora; núcleo compartido con HUD (reposo, escuchando al escribir, verificando tras Enter, alerta si la contraseña es incorrecta) con el avatar en el centro.
  - Los otros usuarios como satélites de la órbita, más «Otro usuario» (escribir el login); campo de cristal, pastilla de sesión con lista desplegable, distribución de teclado / Bloq Mayús y suspender / reiniciar / apagar con cristal.
  - Fondo: `background.jpg` (copia desenfocada por defecto de `assets/wallpapers/dragon-island.jpg`, 19 KB), desenfocado otra vez con `MultiEffect`, bajo un `veil`.
  - Acento: `accent.conf` del tema; si no existe, el Dragon fijo.
  - `bin/dragon-sddm-sync` copia con `sudo` el fondo actual (desenfocado) y su acento al tema, tras mostrar qué va a hacer (`--dry-run`, `--yes`, `--reset`, copias `.bak-dragon`).
  - `tests/qml/sddm_mock.qml` dibuja el tema fuera de pantalla con una API de greeter simulada.
- **7 Migraciones** (`5332aab`): `023-wallpaper-palette-settings.sh` (solo las claves que faltan, más `hyprctl reload`) y `024-sddm-dragon-core-identity.sh` (despliega `dragon-sddm-sync`; si `dragon-core` ya está instalado, copia de seguridad completa del tema, archivos nuevos y una pasada de `dragon-sddm-sync`, siempre con un «sí» interactivo).

## Comprobaciones del prompt (§8)

| # | Resultado |
|---|---|
| 1 | `qs ipc call wallpaper orbital` (lo que ejecuta `SUPER + W`) lo abre. El clic derecho no se pudo hacer (no hay ratón virtual): el captador está en `hyprctl layers`, nivel 1 (`Bottom`), sobre `awww-daemon` (nivel 0). Con `orbitalAt 40 700` se ve el anillo desplazado hacia dentro. |
| 2 | Elegido con ← → + Enter (mismo `choose()` que el clic): vuelo, cobertura, revelado y cierre (`orbital-vuelo.png`). La paleta se regeneró y el acento cambió con animación (`paleta-transicion.png`: dorado → mezcla → Dragon). |
| 3 | Con `wallpaperPalette` apagado, cambiar de fondo no llama a `dragon-palette` (registro del provisional vacío). |
| 4 | Vídeo 4K (`gojo…3840×2160.mp4`): latencia máxima del IPC del shell durante el cambio 49 ms; `generate` / `apply` con `nice 10` tras extraer el fotograma. |
| 5 | **No verificado con un clic real.** Por diseño, la capa está en `Bottom`, por debajo de toda ventana normal, así que Hyprland entrega el clic a la ventana. |
| 6 | `palette.json` ausente, JSON roto y color `#ZZZZZZ` → `ready=false`, acento Dragon y nada en el registro. |
| 7 | Este documento. |

Además: arranque limpio de Quickshell sin avisos propios (solo `printer.svg`, ya conocido); `hyprctl configerrors` vacío; `luac -p` de `glass.lua` y `binds.lua`; `shellcheck -x` de `wallpapers.sh`, `dragon-sddm-sync`, `install-theme.sh` y las migraciones; `sync-shared.sh --check`; `tests/run-all.sh` en verde. `sddm-greeter-qt6 --test-mode --theme sddm/dragon-core` carga sin avisos, con y sin `accent.conf`. 023 se probó dos veces sobre una copia de `settings.json` (respeta un `wallpaperPalette: false` del usuario; la segunda vez sale con 10). 024 se probó en `DRY_RUN`.

## No verificado

- Clic derecho físico en el escritorio y sobre una ventana, clic en una miniatura, rueda del ratón para girar el anillo y clic fuera para cerrar: no hay ratón virtual. El teclado recorre el mismo código salvo el `MouseArea`.
- La tira de colores en la **cuadrícula**: `hl.dsp.cursor.move` no genera eventos de «hover» en la capa. La del orbital sí se vio.
- El estado de alerta del login en el greeter real: en `--test-mode` SDDM no responde al inicio de sesión. Se vio en el render con la API simulada (`login-reposo-alerta.png`).
- `dragon-sddm-sync` sin `--dry-run` y 024 de verdad: ambos piden `sudo` y no se instaló nada en `/usr/share`.
- Los comandos reales de `dragon-palette` (de Codex): solo el contrato, con un provisional.

## Desviaciones del prompt (para decidir)

1. **`services/WallPalette.qml` en vez de `services/Palette.qml`.** QtQuick 6 ya tiene un tipo `Palette`: `Palette.active` en `shell.qml` apuntaba al de Qt y el singleton nunca se creaba (ni su IPC). Las propiedades son las pedidas.
2. **`Theme.textOnAccent` en vez de `onAccent`.** En QML, `onAccent` es la sintaxis de un manejador de señal y rompe la carga. El JSON sigue usando `onAccent`.
3. **Capa `Bottom`, no `Background`, para el captador.** `awww` y `mpvpaper` viven en `Background`, y `awww` se reinicia al salir de un fondo de vídeo, con lo que taparía un captador en la misma capa. `Bottom` sigue por debajo de todas las ventanas normales.
4. **Anillo elíptico (300 × 206) en vez de circular.** Con 12 miniaturas 16:9 en un círculo de ~200 px se solapaban arriba y abajo.
5. **Teclado en el orbital** (← → para elegir, Enter para aplicar): no lo pedía el prompt; sirve de accesibilidad y fue la forma de probar el vuelo. Documentado en `KEYBINDS.md` y `panelGroups`.
6. **Interruptores:** cian en el aspecto Dragon (decisión de la fase 0, `08-ajustes.png`) y el acento cuando hay paleta del fondo (`14-fondos.png`). Es `Theme.switchOn`.
7. **`fallback: true` se trata como «sin paleta»**: el shell usa sus Dragon fijos (idénticos a los del contrato) y Ajustes dice «El fondo es muy apagado».
8. **«Aplicar a las apps» apagado no devuelve las apps a Dragon.** El contrato no tiene un «reset solo de las apps» (`reset` borra también `palette.json`, del que vive el shell). Las apps se quedan con la última paleta aplicada hasta el próximo cambio. Si se quiere, Codex podría añadir `dragon-palette apply --dragon` o similar.
9. **Login:** no se puso el botón de accesibilidad de la maqueta (la API del greeter de SDDM no ofrece nada que activar). En su lugar, Bloq Mayús aparece como botón de cristal cuando está activo. El aro del avatar es cian (como la maqueta) y pasa al acento al verificar y a rojo en la alerta.
10. **`accent.conf` se lee con `QtCore.Settings` y `value()`.** SDDM solo expone `theme.conf`. Con propiedades declaradas, `Settings` **reescribe el archivo** al cerrar el greeter. Además, QSettings trata `[General]` como la raíz del INI, así que las claves se leen sin prefijo.

## Para Codex (contrato visto desde aquí)

- El shell llama a `~/.local/bin/dragon-palette` (ruta fija: el `PATH` de Quickshell no incluye `~/.local/bin`). Siempre con `--quiet`: `generate "$HOME/.cache/dragon-island/current-wallpaper"`, `apply`, `reset`.
- `palette.json` se lee con `version: 1` y los seis colores `#RRGGBB`. `swatches` se filtra (máximo 5). Cualquier otra cosa = sin paleta.
- `bin/dragon-sddm-sync` lee `accent`, `accentSoft` y `glow` del mismo `palette.json` (y nada si `fallback`).

## Trampas

- `Palette` es un tipo de QtQuick: no llamar así a un singleton. `on<Mayúscula>…` no puede ser el nombre de una propiedad.
- Un singleton nuevo en `services/qmldir` no aparece con la recarga en caliente: hay que reiniciar Quickshell (`pkill -x quickshell; hyprctl dispatch 'hl.dsp.exec_cmd("quickshell")'`).
- `QtCore.Settings` con propiedades declaradas escribe el archivo al destruirse: en un tema SDDM, leer con `value()`.
- `hl.dsp.cursor.move` mueve el puntero pero no dispara `containsMouse` en una capa: para probar estados de «hover» hace falta un camino por teclado.

## Revertir

`git revert` de los commits `7d4427b..5332aab`. Además:
- `rm ~/.local/bin/dragon-sddm-sync`.
- En el login: `sudo rm -rf /usr/share/sddm/themes/dragon-core && sudo mv /usr/share/sddm/themes/dragon-core.bak-dragon-<fecha> /usr/share/sddm/themes/dragon-core`.
- `settings.json` admite las claves nuevas sin problema en versiones anteriores.
