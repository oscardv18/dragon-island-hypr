# Probar en VirtualBox

Dragon Island se puede probar en una máquina virtual (CachyOS «sin escritorio»). Dos avisos antes de empezar:

- **SDDM y la aceleración gráfica** en VirtualBox son más limitados que en hardware real (activa 3D y ≥ 128 MB de vídeo; el instalador avisa del entorno virtual).
- **Si tu host también usa Hyprland, los atajos con SUPER los intercepta el host** y nunca llegan a la VM (SUPER + Return abre una terminal *del host*).

## Soluciones

### 1. Submapa «passthrough» en el host (recomendado)

En el host, un submapa sin atajos deja pasar todas las teclas a la ventana enfocada (la VM). En tu configuración Lua del host
(p. ej. `~/.config/hypr/local.lua`; sintaxis de Hyprland 0.57, firma comprobada en `/usr/share/hypr/stubs/hl.meta.lua`):

```lua
-- SUPER + ALT + P: entra/sale del modo «las teclas son de la VM»
hl.bind("SUPER + ALT + P", hl.dsp.submap("vm"))
hl.define_submap("vm", function()
    hl.bind("SUPER + ALT + P", hl.dsp.submap("reset"))
end)
```

Con la ventana de VirtualBox enfocada pulsa `SUPER + ALT + P`; todo lo que escribas va a la VM hasta que repitas la combinación.
(Alternativa sin tocar el host: la tecla anfitrión de VirtualBox, `Ctrl` derecha por defecto, captura el teclado en las versiones que lo permiten; ese comportamiento depende de VirtualBox, no de Hyprland.)

### 2. Cambiar el modificador dentro de la VM, solo para pruebas

En la VM, `~/.config/dragon-island/local.conf`:

```
MAIN_MOD=ALT
```

Reinicia la sesión (o `hyprctl reload`). Todos los atajos `SUPER + …` pasan a `ALT + …` (se aceptan `SUPER`, `ALT` o `CTRL`). Quítalo al terminar: con ALT chocan algunas combinaciones
`SUPER + ALT + …` (p. ej. el cambio de teclado) y no es la configuración que se entrega.

## Abrir una terminal sin atajos (con `hyprctl`, sintaxis de Hyprland 0.57)

Desde una TTY de la VM (`Ctrl + Alt + F3`), con la sesión de Hyprland ya iniciada:

```sh
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr | head -n1) hyprctl dispatch 'hl.dsp.exec_cmd("ghostty")'
```

Desde el host, sin tocar el teclado de la VM, no hay `hyprctl` de la VM: usa la TTY o SSH a la VM con la misma orden.

La sintaxis antigua **ya no funciona** en 0.57 (config Lua): `hyprctl dispatch exec kitty` da `')' expected near 'kitty'`.
Un dispatcher es ahora una expresión Lua entre comillas simples: `'hl.dsp.exec_cmd("kitty")'`, `'hl.dsp.window.close()'`,
`'hl.dsp.focus({ workspace = 2 })'`. `tests/installer_ux/test_rc2.py` falla si reaparece la forma antigua en el repositorio.
