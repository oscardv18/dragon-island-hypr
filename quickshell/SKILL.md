---
name: quickshell
description: Builds and debugs desktop shells written in QML with Quickshell (bars, panels, popups, dashboards, notification daemons, OSDs, launchers, lock screens) on Hyprland and other Wayland compositors. Use whenever writing or reviewing any .qml file for Quickshell, shell.qml, PanelWindow, PopupWindow, IpcHandler, `qs ipc`, Quickshell.Hyprland, Quickshell.Services.* (Mpris, Pipewire, Notifications, UPower, SystemTray), Quickshell.Bluetooth or Quickshell.Networking.
---

# Quickshell

Target version: **Quickshell 0.3.1** (the version in the Arch `extra` repo as of Oct 2026).
Qt 6 / QtQuick. Config language is QML + JavaScript.

## Rule zero: never invent API

`references/api/` is generated from the Quickshell v0.3.1 source with the project's own doc generator.
It lists every type, property, function, signal and enum value that exists.

1. Before using any Quickshell type or member, open `references/api/_INDEX.md`, then the module file.
2. If a member is not listed there, it does not exist in 0.3.1. Do not guess; use a different approach (often `Process` + a CLI tool).
3. Properties marked `[readonly]` cannot be assigned. Types marked *uncreatable* are obtained from other objects (e.g. `Hyprland.workspaces`), never instantiated.
4. Plain QtQuick types (Rectangle, Text, Item, MouseArea, Behavior, NumberAnimation, layouts…) are standard Qt 6 and are not in this reference.

Read `references/patterns.md` for tested building blocks and `references/gotchas.md` before shipping.

## Running and debugging

- Default config: `~/.config/quickshell/shell.qml`. Run a specific folder or file with `qs -p <path>` (`--path`).
- Named configs: `qs -c <name>` loads `~/.config/quickshell/<name>/shell.qml`.
- Quickshell **live-reloads** on save. Keep it running in a terminal and read the errors it prints (file:line).
- Logs: `qs log` (`-f` to follow). Running instances: `qs list`. Stop: `qs kill`.
- IPC: `qs ipc show` lists targets and functions; `qs ipc call <target> <function> [args]` calls one.
- Editor tooling: create an empty `.qmlls.ini` next to `shell.qml`. Quickshell fills it in when it runs, enabling qmlls (completion and lint). Add it to `.gitignore`.

## Project layout (recommended)

```
quickshell/
  shell.qml              # ShellRoot / Scope: instantiates everything
  Theme.qml              # pragma Singleton: colors, radii, fonts, durations
  ShellState.qml         # pragma Singleton: which panel is open, etc.
  services/              # pragma Singleton data objects (no visuals)
  components/            # reusable visual pieces (Capsule, Slider, Toggle…)
  modules/bar/           # Bar.qml, islands
  modules/island/        # Dynamic Island, dashboard
  modules/popovers/      # one file per popover
  modules/notifications/ # popups + center
  modules/launcher/
```

- A file named `Foo.qml` is usable as type `Foo` from sibling files. Files in subfolders need `import "subfolder"` (relative) or `import qs.services` style imports if a `qmldir`/module is set up. Keep imports explicit and consistent.
- Singletons: first line `pragma Singleton`, root type `Singleton { ... }`.
- Separate **data** (services) from **visuals**. UI only binds to service properties and calls service functions.

## Core building blocks (all verified in references/api)

- `ShellRoot` / `Scope`: non-visual containers.
- `Variants { model: Quickshell.screens; delegate: Component { PanelWindow { property var modelData; screen: modelData } } }`: one window per monitor (the screen is injected into `modelData`).
- `PanelWindow` (layer-shell window): `anchors {top,left,right,bottom}`, `margins`, `exclusiveZone` / `exclusionMode`, `aboveWindows`, `focusable`, `color`, `mask: Region {...}`, `implicitWidth/Height`.
- `WlrLayershell` attached props (import `Quickshell.Wayland`): `WlrLayershell.namespace` (default `"quickshell"`), `WlrLayershell.layer`, `WlrLayershell.keyboardFocus`.
- `PopupWindow`: `anchor.window`, `anchor.item`, `anchor.rect`, `anchor.edges`, `anchor.gravity`, `visible`. Only shows when the anchor is valid.
- `BackgroundEffect.blurRegion: Region { item: ... }` (import `Quickshell.Wayland`): compositor blur behind a window via `ext-background-effect-v1`. Hyprland 0.56 supports this protocol.
- `Process` (import `Quickshell.Io`): `command: ["prog","arg"]` (no shell; use `["sh","-c","..."]` for pipes), `running`, `stdout: StdioCollector { onStreamFinished: ... }` or `SplitParser { onRead: ... }`, `exec()`, `startDetached()`. `Quickshell.execDetached([...])` for fire-and-forget.
- `IpcHandler { target: "dashboard"; function toggle(): void { ... } }`: **argument and return types must be annotated** or the function is not registered.
- `Timer` (QtQuick) for polling. `SystemClock` (Quickshell) for clocks.
- `FileView` + `JsonAdapter` for reading and persisting settings files.
- `LazyLoader` to defer heavy windows (launcher, dashboard) until first use.
- `DesktopEntries.applications` for a launcher (each entry has `name`, `icon`, `execute()`, `command`).

## Services available in 0.3.1

| Need | Module | Entry point |
|---|---|---|
| Workspaces, monitors, active window, dispatch | `Quickshell.Hyprland` | `Hyprland` singleton (`workspaces`, `focusedWorkspace`, `activeToplevel`, `dispatch()`, `usingLua`) |
| Media players | `Quickshell.Services.Mpris` | `Mpris.players` |
| Volume / devices | `Quickshell.Services.Pipewire` | `Pipewire.defaultAudioSink`, `nodes`; **bind nodes with `PwObjectTracker`** |
| Notifications daemon | `Quickshell.Services.Notifications` | `NotificationServer` + `onNotification` |
| Battery / power | `Quickshell.Services.UPower` | `UPower.displayDevice`, `PowerProfiles` |
| Tray | `Quickshell.Services.SystemTray` | `SystemTray.items` |
| Bluetooth | `Quickshell.Bluetooth` | `Bluetooth.defaultAdapter`, `devices` |
| Wi-Fi / network | `Quickshell.Networking` | `Networking` singleton, `WifiDevice`, `WifiNetwork` |
| Lock screen | `Quickshell.Wayland` + `Quickshell.Services.Pam` | `WlSessionLock`, `PamContext` |
| Polkit agent | `Quickshell.Services.Polkit` | `PolkitAgent` |

Always open the module file to confirm exact member names before writing code.

## Hyprland specifics

- Hyprland 0.55+ uses a **Lua config**. `Hyprland.usingLua` is true then, and **dispatcher syntax changes**: `Hyprland.dispatch()` and `hyprctl dispatch` take Lua dispatcher expressions such as `hl.dsp.focus({ workspace = "3" })`, not the old `workspace 3` strings. Check the `hyprland` skill / wiki dispatcher page for the exact `hl.dsp.*` call.
- Keybinds that control the shell should call `qs ipc call <target> <fn>` from Hyprland binds (`hl.dsp.exec_cmd("qs ipc call dashboard toggle")`), or use `GlobalShortcut` from `Quickshell.Hyprland`.
- Layer rules (blur, animations) match `WlrLayershell.namespace`. Give each window type its own namespace (e.g. `dragon-bar`, `dragon-island`) so rules can target them.
