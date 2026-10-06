---
name: dragon-island
description: Project rules, versions, architecture and visual spec for the "dragon-island" dotfiles — a Hyprland + Quickshell desktop (SketchyBar-style bar, Dynamic Island with dashboard, Sweet/Garuda Dragonized palette) installed next to KDE Plasma on EndeavourOS with a gum TUI installer. Use for ANY work in this repository (Hyprland config, Quickshell QML, plugins, installer, docs or design questions).
---

# dragon-island — project skill

Read this first on every task in this repo. Then load the specialised skills:
- `hyprland` (full official wiki, Lua config) → any Hyprland config question
- `hyprland-plugins` → hyprpm, hyprbars, hyprfocus
- `quickshell` → any QML / Quickshell work (API reference for 0.3.1 included)
- `arch-tui-installer` → install.sh and installer/

## Target versions (verified 2026-10-05)

| Component | Version | Notes |
|---|---|---|
| Base OS | EndeavourOS (Arch) + KDE Plasma minimal | Hyprland is a **second session** in SDDM |
| Hyprland | **0.56.x stable** (0.56.2) | **Lua config** `~/.config/hypr/hyprland.lua`. hyprlang `.conf` is deprecated since 0.55 — do not write `.conf` |
| Quickshell | **0.3.1** (Arch `extra`) | |
| hyprland-plugins | pinned commit for 0.56.x via hyprpm | only hyprbars, hyprfocus (and borders-plus-plus) |
| gum | 2.x (Arch `extra`) | |

Baseline syntax: `resources/hyprland-0.56.2-example.lua` is the upstream example config **of the exact stable release**. When the `hyprland` skill (which tracks the wiki's *git* version) and this file disagree, the stable file wins.

### Things that do NOT exist on 0.56.2 stable
- `decoration.blur.variant` (frost, acrylic, aurora, …) and `blur.glass.*` / `blur.acrylic.*` — **git-only**. Use plain blur (`enabled`, `size`, `passes`, `vibrancy`, `noise`, `contrast`, `brightness`, `popups`) and leave a commented TODO for later.
- Plugins hyprexpo, hyprscrolling, hyprtrails, hyprwinwrap, xtra-dispatchers (removed). Scrolling layout is native.

## Coexistence with KDE Plasma (must not break it)
- Put session-specific environment variables in the Hyprland config (`hl.env(...)`), never in `~/.profile`, `~/.bashrc`, `~/.config/environment.d/` or `/etc/environment`.
- Don't uninstall or mask Plasma packages/services. Don't change SDDM settings.
- Only one notification daemon per session: our Quickshell `NotificationServer` (Plasma's runs only in Plasma).
- Polkit in Hyprland: `hyprpolkitagent` (Plasma's agent only autostarts in Plasma).
- Portals: install `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`; leave the KDE portal installed for Plasma.
- Keyring: **one Secret Service, KWallet**, shared with Plasma. The display manager's PAM (`pam_kwallet5`, already in SDDM / Plasma Login) unlocks wallet `kdewallet` (Blowfish, same password as the user, no autologin); `autostart.lua` runs `/usr/lib/pam_kwallet_init` chained before quickshell. `~/.config/xdg-desktop-portal/hyprland-portals.conf` routes the Secret portal to `kwallet`; Brave gets `--password-store=kwallet6` via `~/.config/brave-flags.conf`. Never start gnome-keyring (it steals `org.freedesktop.secrets`); recommend `pacman -R gnome-keyring` instead.
- File manager stays Dolphin; terminal is kitty.
- Qt theming in Hyprland: decide explicitly (KDE platform theme vs `hyprqt6engine`) and set it only via `hl.env`.

## Architecture contract

```
config/hypr/              hyprland.lua + require()d modules: monitors, input, look, animations, rules, binds, autostart, plugins, env
config/quickshell/
  shell.qml
  Theme.qml               singleton: every color, radius, font, duration (see references/design.md)
  ShellState.qml          singleton: openPanel + IpcHandler (target "shell")
  services/               singletons, data only: Hypr, Media, Audio, Network, Bluetooth, Power, Brightness,
                          SysStats, Notifs, Osd, Toggles, Apps, Clock, Tray (SNI host)
  components/             Capsule, IconButton, Toggle, Slider, ProgressBar, Card, Popover …
  modules/bar|island|popovers|notifications|launcher|power|lock
  debug/DebugPanel.qml    plain-text dump of all services (dev only, not autostarted)
installer/ install.sh packages/ docs/ HANDOFF.md
```

Rules:
1. **UI never runs commands or talks to D-Bus.** UI binds to service properties and calls service functions.
2. Prefer native Quickshell services (Pipewire, Mpris, UPower/PowerProfiles, Notifications, Bluetooth, Networking, Hyprland) over shelling out. Use `Process` only where no native service exists (brightness via `brightnessctl`, hyprsunset, wf-recorder, grim/slurp, CPU/RAM/temp/disk).
3. All colors/sizes/durations come from `Theme`. No hex literals in components.
4. Panels open/close only through `ShellState.openPanel`; one panel open at a time.
5. Hyprland binds control the shell through `qs ipc call shell toggle <panel>`.
6. Every new service member is documented in a comment block at the top of its file.

### IPC surface (target `shell`)
`toggle(name: string): void`, `open(name: string): void`, `close(): void`, `current(): string`.
Panel names: `dashboard, perf, wifi, bt, audio, battery, notifications, calendar, launcher, power`.
OSD is triggered by services reacting to changes (Audio volume, Brightness), not by IPC.

## Keybinds (SUPER = mod)

| Keys | Action |
|---|---|
| Return | kitty |
| Space | launcher (`shell toggle launcher`) |
| E | Dolphin |
| Q | close window |
| F | fullscreen (maximized toggle) |
| V | toggle floating |
| 1–5 / SHIFT+1–5 | focus / move to workspace |
| arrows or H J K L | move focus |
| SHIFT+arrows | move window |
| mouse 272 / 273 | drag / resize |
| D | dashboard |
| N | notifications |
| Escape | power menu |
| L | lock |
| Print / SHIFT+S | screenshot full / region |
| SHIFT+V | clipboard history |
| XF86 audio/brightness/media | wpctl / brightnessctl / playerctl (`locked = true, repeating = true`) |

## Visual spec
See `references/design.md` (tokens, components, motion). It reproduces the approved mockup; follow it exactly.

## Definition of done (every phase)
- `hyprctl configerrors` empty (when testable) and Lua syntax checked (`luac -p` if available).
- Quickshell loads with no errors in `qs -p config/quickshell`.
- `shellcheck -x` clean on all scripts.
- HANDOFF.md updated: what was done, verified, not verified, decisions.
