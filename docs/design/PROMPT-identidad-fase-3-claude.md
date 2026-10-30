# Nueva identidad de dragon-island — Fase 3 (Claude Code): selector de fondos orbital, el shell toma el color del fondo y login SDDM

Continúa en `feat/nueva-identidad`, sobre la Fase 2. Esta fase se reparte entre dos agentes:
- **Tú (Claude Code):** todo lo de Quickshell / Hyprland / SDDM descrito abajo.
- **Codex:** el generador de paleta `bin/dragon-palette` y las plantillas de herdr, Ghostty, kitty, Starship y fastfetch. Trabaja en la rama `feat/fase-3-paleta` y **no toca nada de lo tuyo**. Tú no tocas nada de lo suyo.

Las mismas reglas de siempre:
- primero la skill `dragon-island` y `docs/HANDOFF.md`;
- un commit por punto numerado;
- nada de colores ni duraciones fuera de `Theme`;
- la UI nunca ejecuta comandos: todo pasa por servicios;
- si algo no es viable tal cual en Quickshell 0.3.1 / Hyprland 0.56.2, **para y pregunta**.

**Migraciones:** tú usas el rango `023` a `029`. Codex usa `030` en adelante.
**Notas:** escribe las tuyas en `docs/handoff-fase-3-claude.md`, no en `HANDOFF.md`. Las unimos después.

Referencias visuales en `docs/design/`:
- `07-login.png`
- `14-fondos.png`
- `16-orbital.png`
- `18-nucleo.png`

Si el código y una referencia chocan, manda la referencia.

**Fuera de alcance:** Alt+Tab, vista general, launcher «Gravedad», módulo ágil y los detalles pendientes del dock.

---

## El contrato con Codex (léelo antes de empezar)

`bin/dragon-palette` es el único que genera colores. Tú solo lo llamas y lees su resultado.

**Comandos (los implementa Codex):**
- `dragon-palette generate <imagen>` escribe `~/.local/state/dragon-island/palette.json` de forma atómica, en menos de 1 s.
- `dragon-palette apply` regenera los archivos de las apps externas a partir de `palette.json` y las recarga.
- `dragon-palette reset` borra `palette.json` y devuelve las apps externas a la paleta Dragon fija.
- `dragon-palette status` imprime `enabled` o `disabled` y la fuente.

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
- Todos los valores son `#RRGGBB`.
- `fallback: true` significa que el fondo era demasiado apagado y se devolvió la paleta Dragon por defecto.
- Los colores semánticos (`ok`, `warn`, `danger`) **no** vienen en el JSON y **no cambian nunca**. Siguen fijos en `Theme`.

**Hasta que Codex termine,** crea tú un `palette.json` de prueba a mano con ese esquema para desarrollar. No lo subas al repo.

---

## 1. Servicio `Palette` y `Theme` que lo sigue

1. Crea `services/Palette.qml` (singleton) que lee `~/.local/state/dragon-island/palette.json` con `FileView` y `watchChanges`. Expón `accent`, `accentSoft`, `accentDeep`, `glow`, `onAccent`, `tint`, `swatches`, `fallback` y `ready`.
2. En `Theme.qml`, los tokens de acento pasan a seguir a `Palette` **solo si** `Settings.wallpaperPalette` es `true` y `Palette.ready`. Si no, usan los valores Dragon fijos actuales. Así `Theme` sigue siendo la única fuente de tokens.
3. `Settings.accentIntensity` sigue funcionando sobre el acento resultante.
4. Cada cambio de color se anima con `ColorAnimation` usando la curva `estandar` y una duración de `Theme` (nueva: `Theme.motion.paleta`, 600 ms). Nada de saltos.
5. El núcleo neural (`NeuralCore`), los anillos, los bordes en degradado, los interruptores y el dock toman el acento del `Theme`, no de `Palette` directamente.
6. Los estados semánticos del núcleo (`alert`, `ok`, `verifying`) conservan sus colores fijos.

## 2. Ajustes: la paleta del fondo

En el panel de Ajustes, en la sección de apariencia:
- Interruptor **«Paleta desde el fondo»**, activado por defecto (`Settings.wallpaperPalette`, que ya existe).
- Interruptor **«Aplicar a las apps»** (`Settings.paletteApplyExternal`, nuevo, activado por defecto). Controla herdr, Ghostty, kitty, Starship y fastfetch.
- Muestra los `swatches` actuales como círculos pequeños junto al interruptor, como en `14-fondos.png`.
- Al apagar «Paleta desde el fondo», el shell vuelve al acento Dragon fijo con animación y se llama a `dragon-palette reset`.
- Al encenderlo, se llama a `dragon-palette generate` sobre el fondo actual.

## 3. Conectar el cambio de fondo con la paleta

En `services/Wallpaper.qml` y `scripts/wallpapers.sh`, después de aplicar un fondo:
1. Ejecuta `dragon-palette generate "$HOME/.cache/dragon-island/current-wallpaper"` (ese enlace ya apunta a un fotograma para GIF y vídeo).
2. Si `paletteApplyExternal` está activo, ejecuta después `dragon-palette apply`.
3. Todo en segundo plano y con `nice`. El cambio de fondo no debe esperar a la paleta.
4. Solo si `wallpaperPalette` está activo. La lectura del ajuste va en el servicio, no en el script de la UI.

## 4. Selector de fondos orbital

Sigue `16-orbital.png`. Cámbialo por el panel actual de `modules/wallpapers/WallpaperPanel.qml`, pero **conserva** el panel clásico como vista alternativa (`SUPER + W` abre el orbital, y un botón del orbital abre la cuadrícula).

1. **Captador del escritorio:** una ventana de capa de Quickshell (`layer` fondo, nombre propio, sin tapar ventanas normales) que detecta **clic derecho** en el escritorio vacío y guarda el punto `(x, y)`. Si un diseño de capa así no es viable, para y pregunta: no pongas una ventana a pantalla completa que robe los clics de las apps.
2. **Anillo de miniaturas** alrededor del punto del clic: aparecen con la curva `orbita` y un pequeño retardo escalonado. Si el punto está cerca de un borde, el anillo se desplaza hacia dentro sin salirse de la pantalla.
3. **Centro del anillo:** disco de 112 px con borde discontinuo que muestra el nombre del fondo bajo el cursor y `ACTUAL` o `CLIC PARA APLICAR`. Si no hay ninguno, `ELIGE UNO`.
4. **Al elegir uno:** la miniatura vuela hacia el centro de la pantalla y se expande hasta cubrirla. Mientras se expande se llama a `Wallpaper.apply(path)`, y el revelado de `awww` usa `--transition-type grow --transition-pos <x>,<y>` con el centro de la pantalla. Al terminar, el anillo y la miniatura desaparecen.
5. **Pastilla de ayuda** abajo («Clic para aplicar · Esc para cerrar»), visible solo en reposo.
6. **Cierre:** `Esc`, clic fuera del anillo, o aplicar un fondo.
7. **Rendimiento:** usa solo miniaturas ya generadas (`Wallpaper.thumbUrl`). Máximo 12 en el anillo; si hay más, rueda del ratón para girar. Para vídeos y GIF, la miniatura es un fotograma estático.
8. Un solo `Region` con un elemento fijo para la máscara. Una sola región de blur por ventana.
9. Añade `qs ipc call wallpaper orbital` para abrirlo desde un atajo y que `SUPER + W` lo llame.

## 5. Vista previa de la paleta en el selector

En la cuadrícula clásica y en el orbital, cada fondo muestra al pasar el cursor una tira con sus colores. Como la paleta real solo se genera al aplicar, calcula la vista previa con `ColorQuantizer` de Quickshell sobre la miniatura (solo para mostrar; el color real sigue siendo el de `dragon-palette`). Si no es viable, omite la tira y dilo.

## 6. Inicio de sesión SDDM

Rediseña `sddm/dragon-core/Main.qml` y `theme.conf` según `07-login.png`:
1. Fondo: el fondo actual desenfocado con un velo oscuro. SDDM corre antes de tu sesión, así que necesita una copia en `/usr/share/sddm/themes/dragon-core/`. No uses `sudo` a escondidas desde el shell: deja el fondo y el acento como parte de un script `bin/dragon-sddm-sync` que el usuario ejecuta a mano (o la migración, una vez), y deja un fondo fijo por defecto. Si ves una opción más limpia, **para y pregunta**.
2. El núcleo neural en el centro con el mismo componente compartido (`shared/neural-core/`, sincronizado con `scripts/sync-shared.sh`). Estados: reposo, verificando al pulsar Enter y alerta si la contraseña es incorrecta.
3. Saludo según la hora, nombre del usuario, selector de usuario y de sesión, y botones de apagar y reiniciar con el estilo de cristal de las islas.
4. El acento en SDDM se lee de `accent.conf` dentro del tema. Si no existe, usa el Dragon fijo.
5. Prueba con `sddm-greeter-qt6 --test-mode --theme sddm/dragon-core`. Si falla por Qt, avisa.

## 7. Migraciones

- `023-wallpaper-palette-settings.sh`: añade `wallpaperPalette=true` (si falta) y `paletteApplyExternal=true` a `settings.json` sin pisar los valores del usuario.
- `024-sddm-dragon-core-identity.sh`: instala el tema SDDM nuevo, con copia de seguridad del actual.

## 8. Comprobaciones antes de terminar

1. `SUPER + W` abre el selector orbital; el clic derecho en el escritorio vacío también.
2. Elegir un fondo con el anillo lo revela con `grow` y cambia el acento del shell con animación.
3. Con «Paleta desde el fondo» apagado, el acento no cambia al cambiar de fondo.
4. Cambiar de fondo con un vídeo 4K no bloquea el escritorio.
5. El clic derecho sobre una ventana normal sigue llegando a la ventana.
6. Con `palette.json` ausente o corrupto, el shell usa el acento Dragon y no da errores en el registro.
7. `docs/handoff-fase-3-claude.md` actualizado, con la lista de lo que no se pudo hacer tal cual.

Termina con un resumen corto: qué hiciste, qué desviaste del diseño y qué necesita ver el usuario en pantalla.
