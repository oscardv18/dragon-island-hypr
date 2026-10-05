---
name: arch-tui-installer
description: Writes safe, idempotent, interactive dotfiles installers for Arch Linux and EndeavourOS as Bash scripts with a gum (charmbracelet) TUI — preflight checks, component selection, pacman/AUR installs, backups, symlinks, services, dry-run and uninstall. Use when creating or reviewing install.sh / installer scripts, gum commands, pacman or yay/paru automation, or dotfiles deployment on Arch-based systems.
---

# Arch / EndeavourOS TUI installer (Bash + gum)

Target: Arch-based systems (EndeavourOS ships `yay`). TUI: **gum 2.x** (in Arch `extra` as `gum`).
Flags below were checked against gum's source (v2.0.2).

## Non-negotiables

1. `#!/usr/bin/env bash` + `set -Eeuo pipefail` + an `ERR` trap that prints the failing line and the log path.
2. Never run as root. Use `sudo` only for the commands that need it. Validate it once with `sudo -v` and keep it alive in the background while installing.
3. **Idempotent:** running twice changes nothing the second time (`pacman --needed`, check before linking, skip existing backups).
4. **Never** partial-upgrade: do one `sudo pacman -Syu` at the start (with confirmation), then `pacman -S --needed` without `-y`.
5. Back up anything you overwrite, and record what you did in a manifest so `--uninstall` can restore it.
6. Everything is logged to `~/.local/state/<project>/install.log`.
7. `--dry-run` prints every action without executing it. `--yes` (or no TTY) runs with defaults and no prompts.
8. Must pass `shellcheck -x` with no warnings.

## Skeleton

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

PROJECT="dragon-island"
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$PROJECT"
LOG="$STATE_DIR/install.log"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_DIR/backups/$TS"
MANIFEST="$STATE_DIR/manifest"   # lines: <action>\t<target>\t<backup-or-source>

DRY_RUN=false; ASSUME_YES=false; MODE=install
for a in "$@"; do case "$a" in
  --dry-run) DRY_RUN=true ;; --yes|-y) ASSUME_YES=true ;; --uninstall) MODE=uninstall ;;
  -h|--help) usage; exit 0 ;; *) echo "Unknown option: $a" >&2; exit 2 ;;
esac; done
[[ -t 0 && -t 1 ]] || ASSUME_YES=true

mkdir -p "$STATE_DIR"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "✗ Error en la línea $LINENO. Revisa $LOG" >&2' ERR

run() { if $DRY_RUN; then printf '[dry-run] %q ' "$@"; echo; else "$@"; fi; }
```

## Preflight

```bash
[[ $EUID -ne 0 ]] || { echo "No ejecutes este instalador como root."; exit 1; }
. /etc/os-release
[[ "$ID" == "arch" || "$ID" == "endeavouros" || " ${ID_LIKE:-} " == *" arch "* ]] || { echo "Solo Arch/EndeavourOS"; exit 1; }
curl -fsS --max-time 5 -o /dev/null https://archlinux.org || { echo "Sin conexión"; exit 1; }
command -v gum >/dev/null || run sudo pacman -S --needed --noconfirm gum
AUR=""; for h in paru yay; do command -v "$h" >/dev/null && { AUR=$h; break; }; done
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &   # keep sudo alive
```

If no AUR helper: offer to build `yay` (`git clone https://aur.archlinux.org/yay-bin.git && makepkg -si`) in a temp dir.

## gum cheat-sheet (verified flags)

| Purpose | Command |
|---|---|
| Styled box | `gum style --border rounded --border-foreground "#c50ed2" --padding "1 2" --foreground "#e6e8ef" "Título" "texto"` |
| Multi-select | `gum choose --no-limit --header "Componentes" --selected "core,shell" core shell plugins fonts` |
| Single choice | `gum choose --header "¿Cómo instalar?" "Symlink (desarrollo)" "Copia"` |
| Yes/No | `gum confirm --affirmative "Sí" --negative "No" "¿Continuar?"` (exit 0 = yes, 1 = no, 130 = Ctrl-C) |
| Text / password | `gum input --placeholder "…"` · `gum input --password` |
| Spinner | `gum spin --spinner dot --title "Instalando paquetes…" --show-error -- sudo pacman -S --needed --noconfirm "${PKGS[@]}"` |
| Render Markdown | `gum format -- "# Listo" "- Cierra sesión y elige **Hyprland** en SDDM"` |
| Log line | `gum log --level info "Copiando configs"` |
| Pager | `gum pager < "$LOG"` |

Gotchas:
- `gum spin` runs a **program**, not a Bash function. Use `gum spin -- bash -c '…'` or export the function and call `bash -c 'fn'`.
- `gum spin` hides interactive prompts: call `sudo -v` before any spinner that uses sudo, and never spin `makepkg -si`/`yay` steps that may ask questions — run those in the foreground.
- `gum choose --no-limit` prints one selection per line → read with `mapfile -t SEL < <(gum choose …)`.
- Theme gum with environment variables (`GUM_CHOOSE_CURSOR_FOREGROUND`, `GUM_CHOOSE_SELECTED_FOREGROUND`, `GUM_CONFIRM_SELECTED_BACKGROUND`, `GUM_SPIN_SPINNER_FOREGROUND`, …) set once at the top.
- In `--yes` mode, skip every gum prompt and use defaults.

## Packages

- Keep lists in `packages/pacman.txt` and `packages/aur.txt` (one per line, `#` comments). Load with `mapfile -t PKGS < <(grep -vE '^\s*(#|$)' packages/pacman.txt)`.
- Verify a name before shipping it: `pacman -Si <pkg>` (repo) or `$AUR -Si <pkg>` (AUR).
- Install: `run sudo pacman -S --needed --noconfirm "${PKGS[@]}"`; AUR: `run "$AUR" -S --needed --noconfirm "${AUR_PKGS[@]}"` (no sudo; the helper asks itself).
- Don't install packages that conflict with the desktop already present (e.g. a second notification daemon, another display manager).

## Configs: backup + link/copy (idempotent)

```bash
deploy() {  # deploy <src-in-repo> <dest>
  local src="$REPO_DIR/$1" dest="$2"
  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then return 0; fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    run mkdir -p "$BACKUP_DIR/$(dirname "${dest#"$HOME"/}")"
    run mv "$dest" "$BACKUP_DIR/${dest#"$HOME"/}"
    $DRY_RUN || printf 'backup\t%s\t%s\n' "$dest" "$BACKUP_DIR/${dest#"$HOME"/}" >> "$MANIFEST"
  fi
  run mkdir -p "$(dirname "$dest")"
  if [[ "$LINK_MODE" == symlink ]]; then run ln -sfn "$src" "$dest"; else run cp -a "$src" "$dest"; fi
  $DRY_RUN || printf 'deploy\t%s\t%s\n' "$dest" "$src" >> "$MANIFEST"
}
```

Uninstall reads the manifest **in reverse**: remove deployed targets, move backups back.

## Services

- System: `run sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon` (skip ones already enabled: `systemctl is-enabled`).
- User: `run systemctl --user enable --now <unit>`.
- Do not change the display manager; on EndeavourOS with KDE, SDDM already lists every installed Wayland session.

## Things that must run inside the graphical session

Some steps can't run from a TTY or another desktop (e.g. `hyprpm update/enable/reload`, which needs a running Hyprland). Install a **first-run script** called from the compositor's autostart that:
1. checks a marker file (`$STATE_DIR/firstrun.done`), exits if present;
2. performs the steps, notifies the user (`notify-send`), writes the marker.

## Final screen

Summarize: what was installed, where backups are, how to start the session (log out → pick the session in SDDM), the 5 most important keybinds, and how to uninstall (`./install.sh --uninstall`).
