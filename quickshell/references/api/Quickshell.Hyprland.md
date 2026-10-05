# Quickshell.Hyprland

`import Quickshell.Hyprland`

Hyprland specific Quickshell types

## GlobalShortcut
*class* · extends `QtObject`

Global shortcut implemented with [hyprland_global_shortcuts_v1].

You can use this within hyprland as a global shortcut:
```
bind = <modifiers>, <key>, global, <appid>:<name>
```
See [the wiki] for details.

> [!WARNING]
> The shortcuts protocol does not allow duplicate appid + name pairs.
> Within a single instance of quickshell this is handled internally, and both
> users will be notified, but multiple instances of quickshell or XDPH may collide.
>
> If that happens, whichever client that tries to register the shortcuts last will crash.

> [!NOTE]
> This type does *not* use the xdg-desktop-portal global shortcuts protocol,
> as it is not fully functional without flatpak and would cause a considerably worse
> user experience from other limitations. It will only work with Hyprland.
> Note that, as this type bypasses xdg-desktop-portal, XDPH is not required.

[hyprland_global_shortcuts_v1]: https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-global-shortcuts-v1.xml
[the wiki]: https://wiki.hyprland.org/Configuring/Binds/#dbus-global-shortcuts

**Properties**
- `appid`: string — The appid of the shortcut. Defaults to `quickshell`.
  You cannot change this at runtime.

  If you have more than one shortcut we recommend subclassing
  GlobalShortcut to set this.
- `pressed`: bool [readonly] — If the keybind is currently pressed.
- `name`: string — The name of the shortcut.
  You cannot change this at runtime.
- `triggerDescription`: string — Have not seen this used ever, but included for completeness. Safe to ignore.
- `description`: string — The description of the shortcut that appears in `hyprctl globalshortcuts`.
  You cannot change this at runtime.

**Signals**
- `pressed()` — handler `onPressed` — Fired when the keybind is pressed.
- `released()` — handler `onReleased` — Fired when the keybind is released.

## Hyprland
*singleton* · extends `QtObject`

**Properties**
- `focusedMonitor`: HyprlandMonitor [readonly] — The currently focused hyprland monitor. May be null.
- `monitors`: ObjectModel<HyprlandMonitor> [readonly] — All hyprland monitors.
- `requestSocketPath`: string [readonly] — Path to the request socket (.socket.sock)
- `usingLua`: bool [readonly] — True if Hyprland is running in lua mode. Dispatcher syntax changes when using lua.

  This property will be false until the Hyprland module is initialized.
- `workspaces`: ObjectModel<HyprlandWorkspace> [readonly] — All hyprland workspaces, sorted by id.

  > [!NOTE]
  > Named workspaces have a negative id, and will appear before unnamed workspaces.
- `focusedWorkspace`: HyprlandWorkspace [readonly] — The currently focused hyprland workspace. May be null.
- `activeToplevel`: Toplevel [readonly] — Currently active toplevel (might be null)
- `toplevels`: ObjectModel<Toplevel> [readonly] — All hyprland toplevels
- `eventSocketPath`: string [readonly] — Path to the event socket (.socket2.sock)

**Functions**
- `dispatch(request: string)`: void — Execute a hyprland [dispatcher](https://wiki.hyprland.org/Configuring/Dispatchers).
- `monitorFor(screen: ShellScreen)`: HyprlandMonitor — Get the HyprlandMonitor object that corresponds to a quickshell screen.
- `refreshMonitors()`: void — Refresh monitor information.

  Many actions that will invalidate monitor state don't send events,
  so this function is available if required.
- `refreshToplevels()`: void — Refresh toplevel information.

  Many actions that will invalidate workspace state don't send events,
  so this function is available if required.
- `refreshWorkspaces()`: void — Refresh workspace information.

  Many actions that will invalidate workspace state don't send events,
  so this function is available if required.

**Signals**
- `rawEvent(event: HyprlandEvent)` — handler `onRawEvent` — Emitted for every event that comes in through the hyprland event socket (socket2).

  See [Hyprland Wiki: IPC](https://wiki.hyprland.org/IPC/) for a list of events.

## HyprlandEvent
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Live Hyprland IPC event. Holding this object after the
signal handler exits is undefined as the event instance
is reused.

Emitted by `Hyprland.rawEvent`.

**Properties**
- `data`: string [readonly] — The unparsed data of the event.
- `name`: string [readonly] — The name of the event.

  See [Hyprland Wiki: IPC](https://wiki.hyprland.org/IPC/) for a list of events.

**Functions**
- `parse(argumentCount: int)`: list<string> — Parse this event with a known number of arguments.

  Argument count is required as some events can contain commas
  in the last argument, which can be ignored as long as the count is known.

## HyprlandFocusGrab
*class* · extends `QtObject`

Object for managing input focus grabs via the [hyprland_focus_grab_v1]
wayland protocol.

When enabled, all of the windows listed in the `windows` property will
receive input normally, and will retain keyboard focus even if the mouse
is moved off of them. When areas of the screen that are not part of a listed
window are clicked or touched, the grab will become inactive and emit the
cleared signal.

This is useful for implementing dismissal of popup type windows.
```qml
import Quickshell
import Quickshell.Hyprland
import QtQuick.Controls

ShellRoot {
  FloatingWindow {
    id: window

    Button {
      anchors.centerIn: parent
      text: grab.active ? "Remove exclusive focus" : "Take exclusive focus"
      onClicked: grab.active = !grab.active
    }

    HyprlandFocusGrab {
      id: grab
      windows: [ window ]
    }
  }
}
```

[hyprland_focus_grab_v1]: https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-global-shortcuts-v1.xml

**Properties**
- `windows`: list<QtObject> — The list of windows to whitelist for input.
- `active`: bool — If the focus grab is active. Defaults to false.

  When set to true, an input grab will be created for the listed windows.

  This property will change to false once the grab is dismissed.
  It will not change to true until the grab begins, which requires
  at least one visible window.

**Signals**
- `cleared()` — handler `onCleared` — Sent whenever the compositor clears the focus grab.

  This may be in response to all windows being removed
  from the list or simultaneously hidden, in addition to
  a normal clear.

## HyprlandMonitor
*class* · extends `QtObject` · uncreatable (obtained from other objects)

**Properties**
- `height`: int [readonly]
- `scale`: real [readonly]
- `id`: int [readonly]
- `activeWorkspace`: HyprlandWorkspace [readonly] — The currently active workspace on this monitor. May be null.
- `description`: string [readonly]
- `focused`: bool [readonly] — If the monitor is currently focused.
- `name`: string [readonly]
- `x`: int [readonly]
- `y`: int [readonly]
- `lastIpcObject`:  [readonly] — Last json returned for this monitor, as a javascript object.

  > [!WARNING]
  > This is *not* updated unless the monitor object is fetched again from
  > Hyprland. If you need a value that is subject to change and does not have a dedicated
  > property, run `Hyprland.refreshMonitors` and wait for this property to update.
- `width`: int [readonly]

## HyprlandToplevel
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Represents a window as Hyprland exposes it.
Can also be used as an attached object of a `Toplevel`,
to resolve a handle to an Hyprland toplevel.

**Properties**
- `activated`: bool [readonly] — Whether the toplevel is active or not
- `monitor`: HyprlandMonitor [readonly] — The current monitor of the toplevel (might be null)
- `handle`: Toplevel [readonly] — The toplevel handle, exposing the Hyprland toplevel.
  Will be null until the address is reported
- `urgent`: bool [readonly] — Whether the client is urgent or not
- `workspace`: HyprlandWorkspace [readonly] — The current workspace of the toplevel (might be null)
- `title`: string [readonly] — The title of the toplevel
- `wayland`: Toplevel [readonly] — The wayland toplevel handle. Will be null intil the address is reported
- `address`: string [readonly] — Hexadecimal Hyprland window address. Will be an empty string until
  the address is reported.
- `lastIpcObject`:  [readonly] — Last json returned for this toplevel, as a javascript object.

  > [!WARNING]
  > This is *not* updated unless the toplevel object is fetched again from
  > Hyprland. If you need a value that is subject to change and does not have a dedicated
  > property, run `Hyprland.refreshToplevels` and wait for this property to update.

## HyprlandWindow
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Allows setting hyprland specific window properties on a `QsWindow` or subclass,
as an attached object.

#### Example
```qml
PopupWindow {
  // ...
  HyprlandWindow.opacity: 0.6 // any number or binding
}
```

> [!NOTE]
> Requires at least hyprland 0.47.0, or [hyprland-surface-v1] support.

[hyprland-surface-v1]: https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-surface-v1.xml

**Properties**
- `visibleMask`: Region — A hint to the compositor that only certain regions of the surface should be rendered.
  This can be used to avoid rendering large empty regions of a window which can increase
  performance, especially if the window is blurred. The mask should include all pixels
  of the window that do not have an alpha value of 0.
- `opacity`: real — A multiplier for the window's overall opacity, ranging from 1.0 to 0.0. Overall opacity includes the opacity of
  both the window content *and* visual effects such as blur that apply to it.

  Default: 1.0

## HyprlandWorkspace
*class* · extends `QtObject` · uncreatable (obtained from other objects)

**Properties**
- `urgent`: bool [readonly] — If this workspace has a window that is urgent.
  Becomes always falsed after the workspace is `focused`.
- `id`: int [readonly]
- `name`: string [readonly]
- `toplevels`: ObjectModel<> [readonly] — List of toplevels on this workspace.
- `monitor`: HyprlandMonitor [readonly]
- `focused`: bool [readonly] — If this workspace is currently active on a monitor and that monitor is currently
  focused. See also `active`.
- `hasFullscreen`: bool [readonly] — If this workspace currently has a fullscreen client.
- `lastIpcObject`:  [readonly] — Last json returned for this workspace, as a javascript object.

  > [!WARNING]
  > This is *not* updated unless the workspace object is fetched again from
  > Hyprland. If you need a value that is subject to change and does not have a dedicated
  > property, run `Hyprland.refreshWorkspaces` and wait for this property to update.
- `active`: bool [readonly] — If this workspace is currently active on its monitor. See also `focused`.

**Functions**
- `activate()`: void — Activate the workspace.

  > [!NOTE]
  > This is equivalent to running
  > ```qml
  > HyprlandIpc.dispatch(`workspace ${workspace.name}`);
  > ```
