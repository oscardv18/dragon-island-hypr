# Tarea: integrar el tema de fastfetch en dragon-island

Lee primero los skills `dragon-island` y `arch-tui-installer`. En `fastfetch-theme/` hay un tema ya escrito y probado
(config.jsonc, logo ASCII, logo PNG, wrapper zsh, install.sh). Integra, no reescribas.

## Reglas
- No sudo. No ejecutes nada en mi `$HOME` real salvo `--dry-run`; para probar usa `HOME=$(mktemp -d)`.
- No sobrescribas mi `~/.config/fastfetch` ni mi `.zshrc` sin respaldo (el install.sh del tema ya lo hace: reutiliza su lógica, no la dupliques).

## Pasos
1. Mueve `config/` → `config/fastfetch/` del repo y `zsh/fastfetch.zsh` → `config/zsh/` (junto a `dragon.zsh`; que `dragon.zsh` lo cargue con `source`).
   `tools/build.py` y `tools/preview.py` → `scripts/fastfetch/`. Quita rutas absolutas.
2. Módulo `theme`/`shell` del instalador: instala `fastfetch` y `jq` (añádelos a `packages/`), enlaza/copia la config con respaldo en
   `~/.local/state/dragon-island/backups/`, sin duplicar líneas (marcadores `# >>> dragon-island fastfetch >>>`). Incluye `--dry-run`.
3. `update.sh`: migración run-once `fastfetch-theme`. `uninstall.sh`: revierte.
4. `doctor.sh`: comprueba que `fastfetch` existe, que `~/.config/fastfetch/{config.jsonc,dragon-logo.txt,dragon-core.png}` están,
   y que `fastfetch -c ... --logo-type none` no da errores; imprime ✔/✘.
5. `dragon-core.png` se genera desde `shared/neural-core/NeuralCore.qml` (render offscreen transparente, 700×700, energy 0.62, recorte al contenido, 480×480).
   Añade `scripts/render-fastfetch-logo.sh` para regenerarlo cuando cambie el núcleo.
6. Verifica con mi máquina real (solo lectura): que los comandos de las líneas Quickshell / Plugins / Teclado / Login den valores correctos
   (`qs --version`, `hyprctl plugin list`, `hyprctl devices -j`, tema SDDM) y ajusta el parseo si la salida real difiere. Repórtame cada uno.
7. Pruebas: `shellcheck -x`, `bash -n`, `fastfetch -c config/fastfetch/config.jsonc` sin errores, idempotencia en `HOME` temporal.
   Lo que no puedas probar sin Ghostty (imagen por protocolo kitty) va a HANDOFF.md como «no verificado».
8. README/docs: capturas de `fastfetch-theme/previews/`.
