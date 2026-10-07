# Quickshell gotchas (0.3.1)

Checked against the 0.3.1 source. Read before declaring a component done.

## Windows
- `PanelWindow.color` defaults to **white**. Set `color: "transparent"` for floating bars and overlays. If a window starts opaque it may not become transparent later (see `QsWindow.color` / `surfaceFormat`).
- A `PanelWindow` with no anchors is centered and does not reserve space. Opposite anchors (left+right) force full width; use `margins` to float it.
- `exclusiveZone` only works with 1 or 3 anchors. Setting it switches `exclusionMode` to `Normal`. Overlays that must not push windows use `exclusionMode: ExclusionMode.Ignore`.
- Clicks: a transparent full-screen overlay blocks the whole desktop unless you set `mask`. Closed state → `mask: Region { item: pill }`; open state → `mask: null` (whole window clickable).
- Keyboard: layer windows get no keyboard input unless `WlrLayershell.keyboardFocus` is `OnDemand` or `Exclusive`. Use `Exclusive` only while a panel/launcher is open, otherwise you steal typing from apps.
- `WlrLayershell.namespace` cannot change after the window is shown. Pick it once.
- `PopupWindow` stays hidden until its `anchor` is valid **and** `visible` is true.

## Processes
- `Process.command` is **not** run in a shell. `["echo","hi"]`, never `["echo hi"]`. Pipes/globs need `["sh","-c","..."]`.
- A `Process` started by Quickshell dies when Quickshell exits or reloads. Use `startDetached()` / `Quickshell.execDetached()` for apps you launch.
- To re-run a polling command, set `running = true` again from a `Timer`; it is a no-op if still running.
- `StdioCollector` gives the whole output on `onStreamFinished` (`this.text`); `SplitParser` emits per line on `onRead`.

## Enum-typed properties
- Don't declare properties with a Quickshell enum type (`property NetworkConnectivity c: ...`, `property PowerProfile p: ...`). QML treats those as object pointers and logs `Unable to assign int to qs::...*`. Declare them as `property int` (enum values are ints) and compare against `NetworkConnectivity.Full`, `PowerProfile.Balanced`, etc.

## Tray icons
- Some apps (e.g. Proton VPN) send an empty `IconPixmap`, producing repeated `Error demarshalling property update ... IconPixmap` warnings. Harmless: use the item's `icon` (it falls back to the icon name). Don't try to "fix" it in QML.

## IPC
- `IpcHandler` functions need explicit parameter and return types (`function toggle(name: string): void`). Untyped functions are silently not registered. Check with `qs ipc show`.
- `target` must be unique per Quickshell instance.

## Services
- **PipeWire:** nodes are unbound by default; `audio.volume`/`muted` are not usable until the node is in a `PwObjectTracker { objects: [...] }`. `defaultAudioSink` can briefly be `null` when the device changes → always use `?.`.
- **UPower:** `percentage` is **0.0–1.0** in practice (the code divides the D-Bus value by 100). Multiply by 100 to display. Check `isLaptopBattery` before showing a battery widget on desktops.
- **Notifications:** set `n.tracked = true` inside `onNotification` or the notification is discarded immediately. Only one notification daemon per session (no mako/dunst/swaync alongside).
- **MPRIS:** `position` does not tick by itself; poll while `isPlaying` if you need a live progress bar.
- **Bluetooth:** `battery` is 0.0–1.0 and only valid when `batteryAvailable`.
- **Networking:** needs NetworkManager running. Wi-Fi networks live under a `WifiDevice`'s `networks`; secured networks use `connectWithPsk(psk)`.
- **ObjectModel:** index access (`model[3]`) is not reactive; use `.values` in bindings.

## Hyprland
- Hyprland 0.55+ runs in **Lua mode**: `Hyprland.dispatch()` expects Lua dispatcher expressions (`hl.dsp.*`). `Hyprland.usingLua` tells you which mode is active.
- `Hyprland.workspaces` includes named/special workspaces with **negative ids**; filter `id > 0` for numbered pills.
- Some Hyprland changes do not emit events; call `Hyprland.refreshWorkspaces()` / `refreshMonitors()` if state looks stale.

## QML in general
- `{{ }}` doesn't exist in QML; bindings are plain JS expressions.
- Use `implicitWidth/implicitHeight` for component sizing; `width/height` are the final sizes set by parents/layouts.
- Layouts (`RowLayout`, `ColumnLayout`) have non-zero default `spacing`.
- `Behavior on x` animates **every** change, including the first layout pass. Disable it while an explicit animation runs (`enabled: !anim.running`).
- Per-corner radii (`topLeftRadius`, …) on `Rectangle` need Qt ≥ 6.7 (Arch ships newer).
- Prefer `Text.textFormat: Text.PlainText` for notification bodies unless you sanitize markup.

## Workflow
- Keep `qs -p <dir>` running while editing; it hot-reloads and prints `file:line` errors.
- Create an empty `.qmlls.ini` next to `shell.qml` so qmlls understands Quickshell imports (Quickshell fills it in). Git-ignore it.
- After changes, test: multiple monitors (`Quickshell.screens`), no battery (desktop), no player, no Bluetooth adapter, Wi-Fi off, 0 notifications and 50 notifications.
