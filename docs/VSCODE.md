# Visual Studio Code en Hyprland (blur y transparencia)

VS Code **no** lo instala el instalador; esto solo documenta cómo encaja.

- Regla: `config/hypr/rules.lua` (`opacity-vscode`). Variables al principio del bloque:
  `VSCODE_OPACITY_ACTIVE` (0.75), `VSCODE_OPACITY_INACTIVE` (0.68) y `VSCODE_CLASSES`.
  Aplicar: `hyprctl reload`; comprobar: `hyprctl configerrors` (vacío).
- Clases: `hyprctl clients | grep class` con VS Code abierto. Flatpak/Wayland nativo → `com.microsoft.VSCode`;
  paquete de distro o AUR → `Code`/`code`; forks → `code-oss`, `Antigravity`.
- Blur: el global (`decoration.blur` en `look.lua`). Con el estilo «liquido» el cristal lo da hyprglass
  (`glass-keep-vscode` en `glass.lua`).
- Si pierdes legibilidad: sube las dos opacidades (0.85 / 0.78).

## Hacerlo nativo en Wayland (si `hyprctl clients` dice `xwayland: true`)

Crea `~/.config/code-flags.conf` (Code-OSS/Arch: `~/.config/code-flags.conf`; Flatpak: `flatpak override --user --socket=wayland --env=ELECTRON_OZONE_PLATFORM_HINT=auto com.visualstudio.code`):

```
--enable-features=WaylandWindowDecorations
--ozone-platform-hint=auto
```

Reinicia VS Code. Nativo, el blur y los bordes redondeados de Hyprland se aplican mejor que bajo XWayland.
