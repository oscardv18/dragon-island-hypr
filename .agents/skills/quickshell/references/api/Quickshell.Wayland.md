# Quickshell.Wayland

`import Quickshell.Wayland`

Wayland specific Quickshell types

## BackgroundEffect
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Applies background blur behind a `QsWindow` or subclass,
as an attached object, using the [ext-background-effect-v1] Wayland protocol.

> [!NOTE]
> Using a background effect requires the compositor support the
> [ext-background-effect-v1] protocol.

[ext-background-effect-v1]: https://wayland.app/protocols/ext-background-effect-v1

#### Example
```qml
PanelWindow {
  id: root
  color: "#80000000"

  BackgroundEffect.blurRegion: Region { item: root.contentItem }
}
```

**Properties**
- `blurRegion`: Region — Region to blur behind the surface. Set to null to remove blur.

## IdleInhibitor
*class* · extends `QtObject`

If an idle daemon is running, it may perform actions such as locking the screen
or putting the computer to sleep.

An idle inhibitor prevents a wayland session from being marked as idle, if compositor
defined heuristics determine the window the inhibitor is attached to is important.

A compositor will usually consider a `PanelWindow` or
a focused `FloatingWindow` to be important.

> [!NOTE]
> Using an idle inhibitor requires the compositor support the [idle-inhibit-unstable-v1] protocol.

[idle-inhibit-unstable-v1]: https://wayland.app/protocols/idle-inhibit-unstable-v1

**Properties**
- `window`: QtObject — The window to associate the idle inhibitor with. This may be used by the compositor
  to determine if the inhibitor should be respected.

  Must be set to a non null value to enable the inhibitor.
- `enabled`: bool — If the idle inhibitor should be enabled. Defaults to false.

## IdleMonitor
*class* · extends `QtObject`

An idle monitor detects when the user stops providing input for a period of time.

> [!NOTE]
> Using an idle monitor requires the compositor support the [ext-idle-notify-v1] protocol.

[ext-idle-notify-v1]: https://wayland.app/protocols/ext-idle-notify-v1

**Properties**
- `isIdle`: bool [readonly] — This property is true if the user has been idle for at least `timeout`.
  What is considered to be idle is influenced by `respectInhibitors`.
- `enabled`: bool — If the idle monitor should be enabled. Defaults to true.
- `respectInhibitors`: bool — When set to true, `isIdle` will depend on both user interaction and active idle inhibitors.
  When false, the value will depend solely on user interaction. Defaults to true.
- `timeout`: real — The amount of time in seconds the idle monitor should wait before reporting an idle state.

  Defaults to zero, which reports idle status immediately.

## ScreencopyView
*class* · extends `Item`

ScreencopyView displays live video streams or single captured frames from valid
capture sources. See `captureSource` for details on which objects are accepted.

**Properties**
- `constraintSize`:  — If nonzero, the width and height constraints set for this property will constrain those
  dimensions of the ScreencopyView's implicit size, maintaining the image's aspect ratio.
- `captureSource`: QtObject — The object to capture from. Accepts any of the following:
  - `null` - Clears the displayed image.
  - `ShellScreen` - A monitor.
    Requires a compositor that supports `wlr-screencopy-unstable`
    or both `ext-image-copy-capture-v1` and `ext-capture-source-v1`.
  - `Toplevel` - A toplevel window.
    Requires a compositor that supports `hyprland-toplevel-export-v1`.
- `hasContent`: bool [readonly] — If true, the view has content ready to display. Content is not always immediately available,
  and this property can be used to avoid displaying it until ready.
- `live`: bool — If true, a live video feed from the capture source will be displayed instead of a still image.
  Defaults to false.
- `paintCursor`: bool — If true, the system cursor will be painted on the image. Defaults to false.
- `sourceSize`: size [readonly] — The size of the source image. Valid when `hasContent` is true.

**Functions**
- `captureFrame()`: void — Capture a single frame. Has no effect if `live` is true.

**Signals**
- `stopped()` — handler `onStopped` — The compositor has ended the video stream. Attempting to restart it may or may not work.

## ShortcutInhibitor
*class* · extends `QtObject`

A shortcuts inhibitor prevents the compositor from processing its own keyboard shortcuts
for the focused surface. This allows applications to receive key events for shortcuts
that would normally be handled by the compositor.

The inhibitor only takes effect when the associated window is focused and the inhibitor
is enabled. The compositor may choose to ignore inhibitor requests based on its policy.

> [!NOTE]
> Using a shortcuts inhibitor requires the compositor support the [keyboard-shortcuts-inhibit-unstable-v1] protocol.

[keyboard-shortcuts-inhibit-unstable-v1]: https://wayland.app/protocols/keyboard-shortcuts-inhibit-unstable-v1

**Properties**
- `enabled`: bool — If the shortcuts inhibitor should be enabled. Defaults to false.
- `window`: QtObject — The window to associate the shortcuts inhibitor with.
  The inhibitor will only inhibit shortcuts pressed while this window has keyboard focus.

  Must be set to a non null value to enable the inhibitor.
- `active`: bool [readonly] — Whether the inhibitor is currently active. The inhibitor is only active if `enabled` is true,
  `window` has keyboard focus, and the compositor grants the inhibit request.

  The compositor may deactivate the inhibitor at any time (for example, if the user requests
  normal shortcuts to be restored). When deactivated by the compositor, the inhibitor cannot be
  programmatically reactivated.

**Signals**
- `cancelled()` — handler `onCancelled` — Sent if the compositor cancels the inhibitor while it is active.

## Toplevel
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A window/toplevel from another application, retrievable from
the `ToplevelManager`.

**Properties**
- `title`: string [readonly]
- `maximized`: bool — If the window is currently maximized.

  Maximization can be requested by setting this property, though it may
  be ignored by the compositor.
- `parent`: Toplevel [readonly] — Parent toplevel if this toplevel is a modal/dialog, otherwise null.
- `appId`: string [readonly]
- `screens`: list<ShellScreen> [readonly] — Screens the toplevel is currently visible on.
  Screens are listed in the order they have been added by the compositor.

  > [!NOTE]
  > Some compositors only list a single screen, even if a window is visible on multiple.
- `activated`: bool [readonly] — If the window is currently activated or focused.

  Activation can be requested with the `activate` function.
- `fullscreen`: bool — If the window is currently fullscreen.

  Fullscreen can be requested by setting this property, though it may
  be ignored by the compositor.
  Fullscreen can be requested on a specific screen with the `fullscreenOn` function.
- `minimized`: bool — If the window is currently minimized.

  Minimization can be requested by setting this property, though it may
  be ignored by the compositor.

**Functions**
- `activate()`: void — Request that this toplevel is activated.
  The request may be ignored by the compositor.
- `close()`: void — Request that this toplevel is closed.
  The request may be ignored by the compositor or the application.
- `fullscreenOn(screen: ShellScreen)`: void — Request that this toplevel is fullscreened on a specific screen.
  The request may be ignored by the compositor.
- `setRectangle(window: QtObject, rect: rect)`: void — Provide a hint to the compositor where the visual representation
  of this toplevel is relative to a quickshell window.
  This hint can be used visually in operations like minimization.
- `unsetRectangle()`: void

**Signals**
- `closed()` — handler `onClosed`

## ToplevelManager
*singleton* · extends `QtObject`

Exposes a list of windows from other applications as `Toplevel`s via the
[zwlr-foreign-toplevel-management-v1](https://wayland.app/protocols/wlr-foreign-toplevel-management-unstable-v1)
wayland protocol.

**Properties**
- `activeToplevel`: Toplevel [readonly] — Active toplevel or null.

  > [!NOTE]
  > If multiple are active, this will be the most recently activated one.
  > Usually compositors will not report more than one toplevel as active at a time.
- `toplevels`: ObjectModel<Toplevel> [readonly] — All toplevel windows exposed by the compositor.

## WlSessionLock
*class* · extends `Reloadable`

Wayland session lock implemented using the [ext_session_lock_v1] protocol.

WlSessionLock will create an instance of its `surface` component for every screen when
`locked` is set to true. The `surface` component must create a `WlSessionLockSurface`
which will be displayed on each screen.

The below example will create a session lock that disappears when the button is clicked.
```qml
WlSessionLock {
  id: lock

  WlSessionLockSurface {
    Button {
      text: "unlock me"
      onClicked: lock.locked = false
    }
  }
}

// ...
lock.locked = true
```

> [!WARNING]
> If the WlSessionLock is destroyed or quickshell exits without setting `locked`
> to false, conformant compositors will leave the screen locked and painted with a solid
> color.
>
> This is what makes the session lock secure. The lock dying will not expose your session,
> but it will render it inoperable.

[ext_session_lock_v1]: https://wayland.app/protocols/ext-session-lock-v1

**Properties**
- `locked`: bool — Controls the lock state.

  > [!WARNING]
  > Only one WlSessionLock may be locked at a time. Attempting to enable a lock while
  > another lock is enabled will do nothing.
- `secure`: bool [readonly] — The compositor lock state.

  This is set to true once the compositor has confirmed all screens are covered with locks.
- `surface`: Component [default] — The surface that will be created for each screen. Must create a `WlSessionLockSurface`.

## WlSessionLockSurface
*class* · extends `Reloadable`

Surface displayed by a `WlSessionLock` when it is locked.

**Properties**
- `color`: color — The background color of the window. Defaults to white.

  > [!WARNING]
  > This seems to behave weirdly when using transparent colors on some systems.
  > Using a colored content item over a transparent window is the recommended way to work around this:
  > ```qml
  > ProxyWindow {
  >   Rectangle {
  >     anchors.fill: parent
  >     color: "#20ffffff"
  >
  >     // your content here
  >   }
  > }
  > ```
  > ... but you probably shouldn't make a transparent lock,
  > and most compositors will ignore an attempt to do so.
- `screen`: ShellScreen [readonly] — The screen that the surface is displayed on.
- `visible`: bool [readonly] — If the surface has been made visible.

  Note: SessionLockSurfaces will never become invisible, they will only be destroyed.
- `data`: list<QtObject> [readonly, default]
- `contentItem`: Item [readonly]
- `height`: int [readonly]
- `width`: int [readonly]

## WlrKeyboardFocus
*enum*

See `WlrLayershell.keyboardFocus`.

**Values:** `WlrKeyboardFocus.Exclusive`, `WlrKeyboardFocus.None`, `WlrKeyboardFocus.OnDemand`

## WlrLayer
*enum*

See `WlrLayershell.layer`.

**Values:** `WlrLayer.Bottom`, `WlrLayer.Top`, `WlrLayer.Background`, `WlrLayer.Overlay`

## WlrLayershell
*class* · extends `PanelWindow`

Decorationless window that can be attached to the screen edges using the [zwlr_layer_shell_v1] protocol.

#### Attached object
`WlrLayershell` works as an attached object of `PanelWindow` which you should use instead if you can,
as it is platform independent.

```qml
PanelWindow {
  // When PanelWindow is backed with WlrLayershell this will work
  WlrLayershell.layer: WlrLayer.Bottom
}
```

To maintain platform compatibility you can dynamically set layershell specific properties.
```qml
PanelWindow {
  Component.onCompleted: {
    if (this.WlrLayershell != null) {
      this.WlrLayershell.layer = WlrLayer.Bottom;
    }
  }
}
```

[zwlr_layer_shell_v1]: https://wayland.app/protocols/wlr-layer-shell-unstable-v1

**Properties**
- `keyboardFocus`: WlrKeyboardFocus — The degree of keyboard focus taken. Defaults to `KeyboardFocus.None`.
- `layer`: WlrLayer — The shell layer the window sits in. Defaults to `WlrLayer.Top`.
- `namespace`: string — Similar to the class property of windows. Can be used to identify the window to external tools.

  Cannot be set after windowConnected.
