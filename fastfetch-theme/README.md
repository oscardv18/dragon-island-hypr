# dragon-island · tema de fastfetch

Misma paleta que el resto (magenta `#c50ed2`, violeta `#7c3aed`, cian `#00c1e4`), con el núcleo neural como logo.

- **Ghostty:** el núcleo real (`config/dragon-core.png`, renderizado con NeuralCore.qml, fondo transparente) vía protocolo kitty.
- **Cualquier otra terminal / TTY / ssh / tmux:** logo ASCII del mismo núcleo (`config/dragon-logo.txt`).
- Secciones **Sistema · Escritorio · Hardware**. En *Escritorio* salen las piezas de dragon-island: Hyprland, Quickshell, plugins de hyprpm cargados,
  teclado activo (us/latam) y tema de login (SDDM). Si una pieza no existe en la máquina, esa línea muestra «—» en vez de romper.

## Instalar
```bash
sudo pacman -S --needed fastfetch jq
./install.sh --zsh        # copia a ~/.config/fastfetch (con respaldo) y añade UNA línea a ~/.zshrc
```
Abre una terminal nueva y escribe `fastfetch`. `./install.sh --preview` lo muestra sin instalar. `./install.sh --uninstall` lo revierte.

## Opciones
- `DRAGON_FF_ASCII=1 fastfetch` fuerza el logo ASCII.
- `export DRAGON_FF_ON_START=1` (antes de cargar el wrapper) lo muestra al abrir cada terminal.
- Si usas herdr/tmux, la imagen no pasa por el multiplexor: usa el ASCII (el wrapper ya lo hace con tmux).

## Archivos
| Archivo | Para qué |
|---|---|
| `config/config.jsonc` | módulos, colores, iconos (Nerd Font) — generado por `tools/build.py` |
| `config/dragon-logo.txt` | logo ASCII (códigos `$1..$4` = magenta, violeta, cian, tenue) |
| `config/dragon-core.png` | núcleo neural 480×480 con transparencia |
| `zsh/fastfetch.zsh` | wrapper: imagen en Ghostty, ASCII en el resto |
| `tools/build.py` | regenera config y logo ASCII; `tools/preview.py` renderiza una vista previa |

Requiere una Nerd Font en la terminal (ya la usamos: JetBrains Mono Nerd) para los iconos.
