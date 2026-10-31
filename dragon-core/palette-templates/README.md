# Plantillas de dragon-palette

`palette_apps.py` renderiza estos archivos en
`${XDG_CONFIG_HOME:-~/.config}/dragon-island/palette/`. Cada resultado tiene
un ejemplo verificado en `tests/palette/golden/` y otro en `golden/legacy/`.

- `ghostty.theme` → `dragon-dynamic`: cursor, selección y ANSI 4/12.
  `ghostty.conf` selecciona `theme = dragon-dynamic` y repite los mismos
  valores explícitos: Ghostty da prioridad a los colores explícitos del
  usuario sobre los de un tema, independientemente del orden del tema.
  La migración añade un único `config-file = …/ghostty.conf` al archivo principal
  y un enlace `ghostty/themes/dragon-dynamic` al tema generado.
- `kitty.conf` → `dragon-dynamic.conf`: cursor, selección, ANSI 4/12 y pestaña
  activa; los demás colores ANSI y la transparencia se conservan.
- `starship.toml`: bloque `[palettes.dragon]` entre los marcadores acordados.
  La migración convierte tokens de color dentro de cadenas TOML y añade
  `palette = "dragon"`; las siguientes aplicaciones solo cambian el bloque.
  Error y éxito mantienen los colores anteriores. `directory_accent` y
  `git_state` permiten restaurar sus colores originales con `reset`.
- `fastfetch-colors.json`: solo colores SGR. `dragon-fastfetch` los combina en
  memoria con la configuración existente y la entrega por stdin a fastfetch.
  No cambia los módulos, las etiquetas, los comandos ni los logos. `-c` /
  `--config` explícitos conservan su comportamiento y omiten esta combinación.
- `legacy.json`: valores anteriores a la fase 3. **Decisión del usuario:**
  `reset` restaura estos valores por aplicación, conservando las inclusiones.
  No modifica la paleta Dragon del JSON de fallback.

herdr 0.9.5 solo permite temas incorporados y colores en `[theme.custom]` dentro
de `config.toml`; no admite inclusión de un archivo de colores. No hay plantilla
ficticia para herdr ni se modifica su configuración. Sus claves verificadas y
las fuentes están en `docs/HANDOFF.md`, sección 8f.

No hay procesos residentes ni dependencias de red. El comando copia las librerías
y las plantillas a `~/.local/share/dragon-island/palette/` en modo copia y resuelve
los enlaces al repo en modo symlink. Pillow solo se importa en `generate`.
