# Quickshell.I3

`import Quickshell.I3`

I3 specific Quickshell types

## I3
*singleton* · extends `QtObject`

I3/Sway IPC integration

**Properties**
- `socketPath`: string [readonly] — Path to the I3 socket
- `workspaces`: ObjectModel<I3Workspace> [readonly] — All I3 workspaces.
- `focusedMonitor`: I3Monitor [readonly]
- `focusedWorkspace`: I3Workspace [readonly]
- `monitors`: ObjectModel<I3Monitor> [readonly] — All I3 monitors.

**Functions**
- `dispatch(request: string)`: void — Execute an [I3/Sway command](https://i3wm.org/docs/userguide.html#list_of_commands)
- `findMonitorByName(name: string)`: I3Monitor — Find an I3Monitor using its name, returns null if the monitor doesn't exist.
- `findWorkspaceByName(name: string)`: I3Workspace — Find an I3Workspace using its name, returns null if the workspace doesn't exist.
- `monitorFor(screen: ShellScreen)`: I3Monitor — Return the i3/Sway monitor associated with `screen`
- `refreshMonitors()`: void — Refresh monitor information.
- `refreshWorkspaces()`: void — Refresh workspace information.

**Signals**
- `rawEvent(event: I3Event)` — handler `onRawEvent`
- `connected()` — handler `onConnected`

## I3Event
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Emitted by `I3.rawEvent`

**Properties**
- `type`: string [readonly]
- `data`: string [readonly]

## I3IpcListener
*class* · extends `QtObject`

#### Example
```qml
I3IpcListener {
  subscriptions: ["input"]
  onIpcEvent: function (event) {
    handleInputEvent(event.data)
  }
}
```

**Properties**
- `subscriptions`: list<string> — List of [I3/Sway events](https://man.archlinux.org/man/sway-ipc.7.en#EVENTS) to subscribe to.

**Signals**
- `ipcEvent(event: I3Event)` — handler `onIpcEvent`

## I3Monitor
*class* · extends `QtObject` · uncreatable (obtained from other objects)

I3/Sway monitors

**Properties**
- `lastIpcObject`:  [readonly] — Last JSON returned for this monitor, as a JavaScript object.

  This updates every time Quickshell receives an `output` event from i3/Sway
- `name`: string [readonly] — The name of this monitor
- `scale`: real [readonly] — The scaling factor of this monitor, 1 means it runs at native resolution
- `focused`: bool [readonly] — Whether this monitor is currently in focus
- `focusedWorkspace`: I3Workspace [readonly] — Deprecated: See `activeWorkspace`.
- `height`: int [readonly] — The height in pixels of this monitor
- `power`: bool [readonly] — Whether this monitor is turned on or not
- `width`: int [readonly] — The width in pixels of this monitor
- `x`: int [readonly] — The X coordinate of this monitor inside the monitor layout
- `activeWorkspace`: I3Workspace [readonly] — The currently active workspace on this monitor, May be null.
- `id`: int [readonly] — The ID of this monitor
- `y`: int [readonly] — The Y coordinate of this monitor inside the monitor layout

## I3Workspace
*class* · extends `QtObject` · uncreatable (obtained from other objects)

I3/Sway workspaces

**Properties**
- `number`: int [readonly] — The number of this workspace
- `active`: bool [readonly] — If this workspace is currently active on its monitor. See also `focused`.
- `num`: int [readonly] — Deprecated: use `number`
- `focused`: bool [readonly] — If this workspace is currently active on a monitor and that monitor is currently
  focused. See also `active`.
- `urgent`: bool [readonly] — If a window in this workspace has an urgent notification
- `name`: string [readonly] — The name of this workspace
- `id`: int [readonly] — The ID of this workspace, it is unique for i3/Sway launch
- `lastIpcObject`:  [readonly] — Last JSON returned for this workspace, as a JavaScript object.

  This updates every time we receive a `workspace` event from i3/Sway
- `monitor`: I3Monitor [readonly] — The monitor this workspace is being displayed on

**Functions**
- `activate()`: void — Activate the workspace.

  > [!NOTE]
  > This is equivalent to running
  > ```qml
  > I3.dispatch(`workspace number ${workspace.number}`);
  > ```
