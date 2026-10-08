# Tarea: lanzador orbital sobre el núcleo neural (reemplaza el aspecto del lanzador actual)

Contexto: ya integraste `dragon-core` (NeuralCore.qml, CoreIcon.qml en `config/quickshell/components/`).
Esta entrega añade `quickshell/modules/launcher/LauncherView.qml` (renderizado y probado offscreen: 0 warnings,
filtrado, navegación circular, launch → verde, sin resultados → rojo, cierre → `settled`) y `Launcher.qml`
(wrapper de referencia, NO probado dentro de Quickshell).

Qué hace el diseño: el núcleo es el planeta, la barra de búsqueda está en su centro y las apps orbitan en un
anillo inclinado tipo Saturno (la mitad de atrás pasa por detrás de la esfera). Al escribir, las coincidencias
se quedan en el anillo y la mejor viene al frente; el núcleo pulsa con cada tecla, se pone rojo sin resultados
y se expande en verde al lanzar.

## Reglas
- No sudo. No toques /etc ni Plasma.
- NO reescribas LauncherView.qml; si algo falla, dime qué y propón el cambio mínimo.
- Conserva la LÓGICA del lanzador actual (ranking/frecuencia, apps ancladas, atajos, el panel de instalar apps
  con pacman/AUR, IPC `shell toggle launcher`). Solo cambia la capa visual.

## Pasos
1. Lee el módulo actual del lanzador orbital (`config/quickshell/modules/launcher/`) y el servicio `Apps`.
   Dime en 5 líneas qué hace y qué piezas de lógica vas a conservar.
2. Copia `LauncherView.qml` al módulo. Adapta `Launcher.qml` al proyecto:
   - `open` ← `ShellState.openPanel === "launcher"` (usa el nombre real si difiere).
   - `entries` ← el servicio `Apps` con su orden por frecuencia (formato `{ id, name, subtitle, icon }`; `icon` es una URL de imagen
     o "" y la vista pone la inicial). Mantén `Quickshell.iconPath(icon, "application-x-executable")` para el tema de iconos.
   - `launch(id)` ← el helper de lanzamiento actual (terminales, flags). Si no hay, `DesktopEntry.execute()`.
   - Si el lanzador actual tenía modo "instalar apps" cuando no hay coincidencias, engánchalo a `noMatch` (la vista ya lo expone:
     `Sin resultados`); por ejemplo con un atajo `Ctrl+I` que abra el panel de instalación con `query` como búsqueda inicial.
3. Elimina el código visual viejo que quede sin uso. Un solo `PanelWindow` de namespace `dragon-launcher`.
4. hyprglass/blur: NO añadas el namespace a la whitelist; el fondo ya es un velo oscuro.
   Si la ventana va lenta, baja `pointCount` (220 → 160) o `capacity` (12 → 10).
5. Pruebas (reporta cada una): `qs -p config/quickshell` sin errores; SUPER+Space abre con la animación de entrada
   (el anillo se abre desde el centro); escribir filtra; ←/→/Tab/rueda giran el anillo; Enter lanza y cierra;
   Esc borra y luego cierra; clic fuera cierra; con 1–2 resultados el anillo se reparte bien; sin resultados el núcleo se pone rojo;
   iconos nítidos (sin pixelado) en frente y al fondo; con `prefers-reduced-motion`/`reducedMotion: true` no hay giro del núcleo.
6. HANDOFF.md: hecho / verificado / no verificado / cómo revertir (`git revert` del commit).
