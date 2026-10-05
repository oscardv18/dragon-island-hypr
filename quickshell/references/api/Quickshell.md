# Quickshell

`import Quickshell`

Core Quickshell types

## BoundComponent
*class* · extends `Item`

Component loader that allows setting initial properties, primarily useful for
escaping cyclic dependency errors.

Properties defined on the BoundComponent will be applied to its loaded component,
including required properties, and will remain reactive. Functions created with
the names of signal handlers will also be attached to signals of the loaded component.

```qml {filename="MyComponent.qml"}
MouseArea {
  required property color color;
  width: 100
  height: 100

  Rectangle {
    anchors.fill: parent
    color: parent.color
  }
}
```

```qml
BoundComponent {
  source: "MyComponent.qml"

  // this is the same as assigning to `color` on MyComponent if loaded normally.
  property color color: "red";

  // this will be triggered when the `clicked` signal from the MouseArea is sent.
  function onClicked() {
    color = "blue";
  }
}
```

**Properties**
- `implicitHeight`: real [readonly]
- `item`: QtObject [readonly] — The loaded component. Will be null until it has finished loading.
- `sourceComponent`: Component — The source to load, as a Component.
- `bindValues`: bool — If property values should be bound after they are initially set. Defaults to `true`.
- `implicitWidth`: real [readonly]
- `source`: string — The source to load, as a Url.

## ColorQuantizer
*class* · extends `QtObject`

A color quantization utility used for getting prevalent colors in an image, by
averaging out the image's color data recursively.

#### Example
```qml
ColorQuantizer {
  id: colorQuantizer
  source: Qt.resolvedUrl("./yourImage.png")
  depth: 3 // Will produce 8 colors (2³)
  rescaleSize: 64 // Rescale to 64x64 for faster processing
}
```

**Properties**
- `imageRect`: rect — Rectangle that the source image is cropped to.

  Can be set to `undefined` to reset.
- `rescaleSize`: real — The size to rescale the image to, when rescaleSize is 0 then no scaling will be done.
  > [!NOTE]
  > Results from color quantization doesn't suffer much when rescaling, it's
  > recommended to rescale, otherwise the quantization process will take much longer.
- `colors`: list<color> [readonly] — Access the colors resulting from the color quantization performed.
  > [!NOTE]
  > The amount of colors returned from the quantization is determined by
  > the property depth, specifically 2ⁿ where n is the depth.
- `source`:  — Path to the image you'd like to run the color quantization on.
- `depth`: real — Max depth for the color quantization. Each level of depth represents another
  binary split of the color space

## DesktopAction
*class* · extends `QtObject` · uncreatable (obtained from other objects)

An action of a `DesktopEntry`.

**Properties**
- `execString`: string — The raw `Exec` string from the action.

  > [!WARNING]
  > This cannot be reliably run as a command. See `command` for one you can run.
- `icon`: string
- `name`: string
- `id`: string [readonly]
- `command`: list<string> — The parsed `Exec` command in the action.

  The entry can be run with `execute`, or by using this command in
  `Quickshell.execDetached` or `Process`.
  If used in `execDetached` or a `Process`, `DesktopEntry.workingDirectory` should also be passed to
  the invoked process.

  > [!NOTE]
  > The provided command does not invoke a terminal even if `runInTerminal` is true.

**Functions**
- `execute()`: void — Run the application. Currently ignores `DesktopEntry.runInTerminal` and field codes.

  This is equivalent to calling `Quickshell.execDetached` with `command`
  and `DesktopEntry.workingDirectory`.

## DesktopEntries
*singleton* · extends `QtObject`

Index of desktop entries according to the [desktop entry specification].

Primarily useful for looking up icons and metadata from an id, as there is
currently no mechanism for usage based sorting of entries and other launcher niceties.

[desktop entry specification]: https://specifications.freedesktop.org/desktop-entry-spec/latest/

**Properties**
- `applications`: ObjectModel<DesktopEntry> [readonly] — All desktop entries of type Application that are not Hidden or NoDisplay.

**Functions**
- `byId(id: string)`: DesktopEntry — Look up a desktop entry by name. Includes NoDisplay entries. May return null.

  While this function requires an exact match, `heuristicLookup` will correctly
  find an entry more often and is generally more useful.
- `heuristicLookup(name: string)`: DesktopEntry — Look up a desktop entry by name using heuristics. Unlike `byId`,
  if no exact matches are found this function will try to guess - potentially incorrectly.
  May return null.

**Signals**
- `applicationsChanged()` — handler `onApplicationsChanged`

## DesktopEntry
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A desktop entry. See `DesktopEntries` for details.

**Properties**
- `workingDirectory`: string — The working directory to execute from.
- `runInTerminal`: bool — If the application should run in a terminal.
- `startupClass`: string — Initial class or app id the app intends to use. May be useful for matching running apps
  to desktop entries.
- `name`: string
- `icon`: string — Name of the icon associated with this application. May be empty.
- `comment`: string — Long description of the application, such as "View websites on the internet". May be empty.
- `id`: string [readonly]
- `actions`: list<DesktopAction> [readonly]
- `categories`: list<string>
- `execString`: string — The raw `Exec` string from the desktop entry.

  > [!WARNING]
  > This cannot be reliably run as a command. See `command` for one you can run.
- `command`: list<string> — The parsed `Exec` command in the desktop entry.

  The entry can be run with `execute`, or by using this command in
  `Quickshell.execDetached` or `Process`.
  If used in `execDetached` or a `Process`, `workingDirectory` should also be passed to
  the invoked process. See `execute` for details.

  > [!NOTE]
  > The provided command does not invoke a terminal even if `runInTerminal` is true.
- `keywords`: list<string>
- `noDisplay`: bool — If true, this application should not be displayed in menus and launchers.
- `genericName`: string — Short description of the application, such as "Web Browser". May be empty.

**Functions**
- `execute()`: void — Run the application. Currently ignores `runInTerminal` and field codes.

  This is equivalent to calling `Quickshell.execDetached` with `command`
  and `DesktopEntry.workingDirectory` as shown below:

  ```qml
  Quickshell.execDetached({
    command: desktopEntry.command,
    workingDirectory: desktopEntry.workingDirectory,
  });
  ```

## EasingCurve
*class* · extends `QtObject`

Directly accessible easing curve as used in property animations.

**Properties**
- `curve`: EasingCurve — Easing curve settings. Works exactly the same as
  [PropertyAnimation.easing](https://doc.qt.io/qt-6/qml-qtquick-propertyanimation.html#easing-prop).

**Functions**
- `interpolate(x: real, a: real, b: real)`: real — Interpolates between two values using the given X coordinate.
- `interpolate(x: real, a: point, b: point)`: point — Interpolates between two points using the given X coordinate.
- `interpolate(x: real, a: rect, b: rect)`: rect — Interpolates two rects using the given X coordinate.
- `valueAt(x: real)`: real — Returns the Y value for the given X value on the curve
  from 0.0 to 1.0.

## Edges
*enum*

Edge flags can be combined with the `|` operator.

**Values:** `Edges.Right`, `Edges.None`, `Edges.Top`, `Edges.Bottom`, `Edges.Left`

## ElapsedTimer
*class* · extends `QtObject`

The ElapsedTimer measures time since its last restart, and is useful
for determining the time between events that don't supply it.

**Functions**
- `elapsed()`: real — Return the number of seconds since the timer was last
  started or restarted, with nanosecond precision.
- `elapsedMs()`: int — Return the number of milliseconds since the timer was last
  started or restarted.
- `elapsedNs()`: int — Return the number of nanoseconds since the timer was last
  started or restarted.
- `restart()`: real — Restart the timer, returning the number of seconds since
  the timer was last started or restarted, with nanosecond precision.
- `restartMs()`: int — Restart the timer, returning the number of milliseconds since
  the timer was last started or restarted.
- `restartNs()`: int — Restart the timer, returning the number of nanoseconds since
  the timer was last started or restarted.

## ExclusionMode
*enum*

See `PanelWindow.exclusionMode`.

**Values:** `ExclusionMode.Auto`, `ExclusionMode.Normal`, `ExclusionMode.Ignore`

## FloatingWindow
*class* · extends `QsWindow`

Standard toplevel operating system window that looks like any other application.

**Properties**
- `parentWindow`: QtObject — The parent window of this window. Setting this makes the window a child of the parent,
  which affects window stacking behavior.

  > [!NOTE]
  > This property cannot be changed after the window is visible.
- `title`: string — Window title.
- `maximumSize`: size — Maximum window size given to the window system.
- `minimumSize`: size — Minimum window size given to the window system.
- `minimized`: bool — Whether the window is currently minimized.
- `fullscreen`: bool — Whether the window is currently fullscreen.
- `maximized`: bool — Whether the window is currently maximized.

**Functions**
- `startSystemMove()`: bool — Start a system move operation. Must be called during a pointer press/drag.
- `startSystemResize(edges: )`: bool — Start a system resize operation. Must be called during a pointer press/drag.

## Intersection
*enum*

See `Region.intersection`.

**Values:** `Intersection.Subtract`, `Intersection.Intersect`, `Intersection.Xor`, `Intersection.Combine`

## LazyLoader
*class* · extends `Reloadable`

The LazyLoader can be used to prepare components that don't need to be
created immediately, such as windows that aren't visible until triggered
by another action. It works on creating the component in the gaps between
frame rendering to prevent blocking the interface thread.
It can also be used to preserve memory by loading components only
when you need them and unloading them afterward.

Note that when reloading the UI due to changes, lazy loaders will always
load synchronously so windows can be reused.

#### Example
The following example creates a PopupWindow asynchronously as the bar loads.
This means the bar can be shown onscreen before the popup is ready, however
trying to show the popup before it has finished loading in the background
will cause the UI thread to block.

```qml
import QtQuick
import QtQuick.Controls
import Quickshell

ShellRoot {
  PanelWindow {
    id: window
    height: 50

    anchors {
      bottom: true
      left: true
      right: true
    }

    LazyLoader {
      id: popupLoader

      // start loading immediately
      loading: true

      // this window will be loaded in the background during spare
      // frame time unless active is set to true, where it will be
      // loaded in the foreground
      PopupWindow {
        // position the popup above the button
        parentWindow: window
        relativeX: window.width / 2 - width / 2
        relativeY: -height

        // some heavy component here

        width: 200
        height: 200
      }
    }

    Button {
      anchors.centerIn: parent
      text: "show popup"

      // accessing popupLoader.item will force the loader to
      // finish loading on the UI thread if it isn't finished yet.
      onClicked: popupLoader.item.visible = !popupLoader.item.visible
    }
  }
}
```

> [!WARNING]
> Components that internally load other components must explicitly
> support asynchronous loading to avoid blocking.
>
> Notably, `Variants` does not corrently support asynchronous
> loading, meaning using it inside a LazyLoader will block similarly to not
> having a loader to start with.

**Properties**
- `source`: string — The URI to load the component from. Mutually exclusive to `component`.
- `component`: Component [default] — The component to load. Mutually exclusive to `source`.
- `item`: QtObject [readonly] — The fully loaded item if the loader is `loading` or `active`, or `null`
  if neither `loading` nor `active`.

  Note that the item is owned by the LazyLoader, and destroying the LazyLoader
  will destroy the item.

  > [!WARNING]
  > If you access the `item` of a loader that is currently loading,
  > it will block as if you had set `active` to true immediately beforehand.
  >
  > You can instead set `loading` and listen to `activeChanged` signal to
  > ensure loading happens asynchronously.
- `active`: bool — If the component is fully loaded.

  Setting this property to `true` will force the component to load to completion,
  blocking the UI, and setting it to `false` will destroy the component, requiring
  it to be loaded again.

  See also: `activeAsync`.
- `activeAsync`: bool — If the component is fully loaded.

  Setting this property to true will asynchronously load the component similarly to
  `loading`. Reading it or setting it to false will behanve
  the same as `active`.
- `loading`: bool — If the loader is actively loading.

  If the component is not loaded, setting this property to true will start
  loading it asynchronously. If the component is already loaded, setting
  this property has no effect.

  See also: `activeAsync`.

## ObjectComparison
*enum*

`ScriptModel` value comparison mode.

**Values:** `ObjectComparison.Identity`, `ObjectComparison.Structure`

## ObjectModel
*class* · extends `` · uncreatable (obtained from other objects)

Typed view into a list of objects.

An ObjectModel works as a QML [Data Model], allowing efficient interaction with
components that act on models. It has a single role named `modelData`, to match the
behavior of lists.
The same information contained in the list model is available as a normal list
via the `values` property.

#### Differences from a list
Unlike with a list, the following property binding will never be updated when `model[3]` changes.
```qml
// will not update reactively
property var foo: model[3]
```

You can work around this limitation using the `values` property of the model to view it as a list.
```qml
// will update reactively
property var foo: model.values[3]
```

[Data Model]: https://doc.qt.io/qt-6/qtquick-modelviewsdata-modelview.html#qml-data-models

**Properties**
- `values`: list<QtObject> [readonly] — The content of the object model, as a QML list.
  The values of this property will always be of the type of the model.

**Functions**
- `indexOf()`: int

**Signals**
- `objectInsertedPre(object: QtObject, index: int)` — handler `onObjectInsertedPre` — Sent immediately before an object is inserted into the list.
- `objectRemovedPost(object: QtObject, index: int)` — handler `onObjectRemovedPost` — Sent immediately after an object is removed from the list.
- `objectRemovedPre(object: QtObject, index: int)` — handler `onObjectRemovedPre` — Sent immediately before an object is removed from the list.
- `objectInsertedPost(object: QtObject, index: int)` — handler `onObjectInsertedPost` — Sent immediately after an object is inserted into the list.

## PanelWindow
*class* · extends `QsWindow`

Decorationless window attached to screen edges by anchors.

#### Example
The following snippet creates a white bar attached to the bottom of the screen.

```qml
PanelWindow {
  anchors {
    left: true
    bottom: true
    right: true
  }

  Text {
    anchors.centerIn: parent
    text: "Hello!"
  }
}
```

**Properties**
- `anchors`: { left: bool, bottom: bool, right: bool, top: bool } — Anchors attach a shell window to the sides of the screen.
  By default all anchors are disabled to avoid blocking the entire screen due to a misconfiguration.

  > [!NOTE]
  > When two opposite anchors are attached at the same time, the corresponding dimension
  > (width or height) will be forced to equal the screen width/height.
  > Margins can be used to create anchored windows that are also disconnected from the monitor sides.
- `exclusionMode`: ExclusionMode — Defaults to `ExclusionMode.Auto`.
- `aboveWindows`: bool — If the panel should render above standard windows. Defaults to true.

  Note: On Wayland this property corresponds to `WlrLayershell.layer`.
- `focusable`: bool — If the panel should accept keyboard focus. Defaults to false.

  Note: On Wayland this property corresponds to `WlrLayershell.keyboardFocus`.
- `exclusiveZone`: int — The amount of space reserved for the shell layer relative to its anchors.
  Setting this property sets `exclusionMode` to `ExclusionMode.Normal`.

  > [!NOTE]
  > Either 1 or 3 anchors are required for the zone to take effect.
- `margins`: { top: int, bottom: int, right: int, left: int } — Offsets from the sides of the screen.

  > [!NOTE]
  > Only applies to edges with anchors

## PersistentProperties
*class* · extends `Reloadable`

PersistentProperties holds properties declated in it across a reload, which is
often useful for things like keeping expandable popups open and styling them.

Below is an example of using `PersistentProperties` to keep track of the state
of an expandable panel. When the configuration is reloaded, the `expanderOpen` property
will be saved and the expandable panel will stay in the open/closed state.

```qml
PersistentProperties {
  id: persist
  reloadableId: "persistedStates"

  property bool expanderOpen: false
}

Button {
  id: expanderButton
  anchors.centerIn: parent
  text: "toggle expander"
  onClicked: persist.expanderOpen = !persist.expanderOpen
}

Rectangle {
  anchors.top: expanderButton.bottom
  anchors.left: expanderButton.left
  anchors.right: expanderButton.right
  height: 100

  color: "lightblue"
  visible: persist.expanderOpen
}
```

**Signals**
- `reloaded()` — handler `onReloaded` — Called every time the properties are reloaded.
  Will not be called if no old instance was loaded.
- `loaded()` — handler `onLoaded` — Called every time the reload stage completes.
  Will be called every time, including when nothing was loaded from an old instance.

## PopupAdjustment
*enum*

Adjustment strategy for popups. See `PopupAnchor.adjustment`.

Adjustment flags can be combined with the `|` operator.

`Flip` will be applied first, then `Slide`, then `Resize`.

**Values:** `PopupAdjustment.Flip`, `PopupAdjustment.All`, `PopupAdjustment.FlipY`, `PopupAdjustment.ResizeY`, `PopupAdjustment.FlipX`, `PopupAdjustment.SlideY`, `PopupAdjustment.ResizeX`, `PopupAdjustment.Resize`, `PopupAdjustment.Slide`, `PopupAdjustment.None`, `PopupAdjustment.SlideX`

## PopupAnchor
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Anchorpoint or positioner for popup windows.

**Properties**
- `adjustment`: PopupAdjustment — The strategy used to adjust the popup's position if it would otherwise not fit on screen,
  based on the anchor `rect`, preferred `edges`, and `gravity`.

  See the documentation for `PopupAdjustment` for details.
- `gravity`: Edges — The direction the popup should expand towards, relative to the anchorpoint.
  Opposing edges suchs as `Edges.Left | Edges.Right` are not allowed.

  Defaults to `Edges.Bottom | Edges.Right`.
- `edges`: Edges — The point on the anchor rectangle the popup should anchor to.
  Opposing edges suchs as `Edges.Left | Edges.Right` are not allowed.

  Defaults to `Edges.Top | Edges.Left`.
- `item`: Item — The item to anchor / attach the popup to. Setting this property unsets `window`.

  The popup's position relative to its parent window is only calculated when it is
  initially shown (directly before `anchoring` is emitted), meaning its anchor
  rectangle will be set relative to the item's position in the window at that time.
  `updateAnchor` can be called to update the anchor rectangle if the item's position
  has changed.

  > [!NOTE]
  > If a more flexible way to position a popup relative to an item is needed,
  > set `window` to the item's parent window, and handle the `anchoring` signal to
  > position the popup relative to the window's contentItem.
- `margins`: { bottom: int, left: int, top: int, right: int } — A margin applied to the anchor rect.

  This is most useful when `item` is used and `rect` is left at its default
  value (matching the Item's dimensions).
- `rect`: { w: int, h: int, x: int, width: int, y: int, height: int } — The anchorpoints the popup will attach to, relative to `item` or `window`.
  Which anchors will be used is determined by the `edges`, `gravity`, and `adjustment`.

  If using `item`, the default anchor rectangle matches the dimensions of the item.

  If you leave `edges`, `gravity` and `adjustment` at their default values,
  setting more than `x` and `y` does not matter. The anchor rect cannot
  be smaller than 1x1 pixels.

  [coordinate mapping functions]: https://doc.qt.io/qt-6/qml-qtquick-item.html#mapFromItem-method
- `window`: QtObject — The window to anchor / attach the popup to. Setting this property unsets `item`.

**Functions**
- `updateAnchor()`: void — Update the popup's anchor rect relative to its parent window.

  If anchored to an item, popups anchors will not automatically follow
  the item if its position changes. This function can be called to
  recalculate the anchors.

**Signals**
- `anchoring()` — handler `onAnchoring` — Emitted when this anchor is about to be used. Mostly useful for modifying
  the anchor `rect` using [coordinate mapping functions], which are not reactive.

  [coordinate mapping functions]: https://doc.qt.io/qt-6/qml-qtquick-item.html#mapFromItem-method

## PopupWindow
*class* · extends `QsWindow`

Popup window that can display in a position relative to a floating
or panel window.

#### Example
The following snippet creates a panel with a popup centered over it.

```qml
PanelWindow {
  id: toplevel

  anchors {
    bottom: true
    left: true
    right: true
  }

  PopupWindow {
    anchor.window: toplevel
    anchor.rect.x: parentWindow.width / 2 - width / 2
    anchor.rect.y: parentWindow.height
    width: 500
    height: 500
    visible: true
  }
}
```

**Properties**
- `visible`: bool — If the window is shown or hidden. Defaults to false.

  The popup will not be shown until `anchor` is valid, regardless of this property.
- `grabFocus`: bool — If true, the popup window will be dismissed and `visible` will change to false
  if the user clicks outside of the popup or it is otherwise closed.

  > [!WARNING]
  > Changes to this property while the window is open will only take
  > effect after the window is hidden and shown again.

  > [!NOTE]
  > Under Hyprland, `HyprlandFocusGrab` provides more advanced
  > functionality such as detecting clicks outside without closing the popup.
- `anchor`: PopupAnchor [readonly] — The popup's anchor / positioner relative to another item or window. The popup will
  not be shown until it has a valid anchor relative to a window and `visible` is true.

  You can set properties of the anchor like so:
  ```qml
  PopupWindow {
    anchor.window: parentwindow
    // or
    anchor {
      window: parentwindow
    }
  }
  ```
- `relativeY`: int — > [!ERROR]
  > Deprecated in favor of `anchor.rect.y`.

  The Y position of the popup relative to the parent window.
- `relativeX`: int — > [!ERROR]
  > Deprecated in favor of `anchor.rect.x`.

  The X position of the popup relative to the parent window.
- `screen`: ShellScreen [readonly] — The screen that the window currently occupies.

  This may be modified to move the window to the given screen.
- `parentWindow`: QtObject — > [!ERROR]
  > Deprecated in favor of `anchor.window`.

  The parent window of this popup.

  Changing this property reparents the popup.

## QsMenuAnchor
*class* · extends `QtObject`

Display anchor for platform menus.

**Properties**
- `anchor`: PopupAnchor [readonly] — The menu's anchor / positioner relative to another window. The menu will not be
  shown until it has a valid anchor.

  > [!NOTE]
  > *The following is subject to change and NOT a guarantee of future behavior.*
  >
  > A snapshot of the anchor at the time `opened` is emitted will be
  > used to position the menu. Additional changes to the anchor after this point
  > will not affect the placement of the menu.

  You can set properties of the anchor like so:
  ```qml
  QsMenuAnchor {
    anchor.window: parentwindow
    // or
    anchor {
      window: parentwindow
    }
  }
  ```
- `menu`: QsMenuHandle — The menu that should be displayed on this anchor.

  See also: `SystemTrayItem.menu`.
- `visible`: bool [readonly] — If the menu is currently open and visible.

  See also: `open`, `close`.

**Functions**
- `close()`: void — Close the open menu.
- `open()`: void — Open the given menu on this menu Requires that `anchor` is valid.

**Signals**
- `opened()` — handler `onOpened` — Sent when the menu is displayed onscreen which may be after `visible`
  becomes true.
- `closed()` — handler `onClosed` — Sent when the menu is closed.

## QsMenuButtonType
*enum* · extends `QtObject`

See `QsMenuEntry.buttonType`.

**Functions**
- `toString(value: QsMenuButtonType)`: string

**Values:** `QsMenuButtonType.CheckBox`, `QsMenuButtonType.None`, `QsMenuButtonType.RadioButton`

## QsMenuEntry
*class* · extends `QsMenuHandle` · uncreatable (obtained from other objects)

**Properties**
- `checkState`:  [readonly] — The check state of the checkbox or radiobutton if applicable, as a
  [Qt.CheckState](https://doc.qt.io/qt-6/qt.html#CheckState-enum).
- `enabled`: bool [readonly]
- `buttonType`: QsMenuButtonType [readonly] — If this menu item has an associated checkbox or radiobutton.
- `icon`: string [readonly] — Url of the menu item's icon or `""` if it doesn't have one.

  This can be passed to [Image.source](https://doc.qt.io/qt-6/qml-qtquick-image.html#source-prop)
  as shown below.

  ```qml
  Image {
    source: menuItem.icon
    // To get the best image quality, set the image source size to the same size
    // as the rendered image.
    sourceSize.width: width
    sourceSize.height: height
  }
  ```
- `text`: string [readonly] — Text of the menu item.
- `isSeparator`: bool [readonly] — If this menu item should be rendered as a separator between other items.

  No other properties have a meaningful value when `isSeparator` is true.
- `hasChildren`: bool [readonly] — If this menu item has children that can be accessed through a `QsMenuOpener`.

**Functions**
- `display(parentWindow: QtObject, relativeX: int, relativeY: int)`: void — Display a platform menu at the given location relative to the parent window.

**Signals**
- `triggered()` — handler `onTriggered` — Send a trigger/click signal to the menu entry.

## QsMenuHandle
*class* · extends `QtObject` · uncreatable (obtained from other objects)

See `QsMenuOpener`.

**Signals**
- `menuChanged()` — handler `onMenuChanged`

## QsMenuOpener
*class* · extends `QtObject`

Provides access to children of a QsMenuEntry

**Properties**
- `menu`: QsMenuHandle — The menu to retrieve children from.
- `children`: ObjectModel<QsMenuEntry> [readonly] — The children of the given menu.

## QsWindow
*class* · extends `Reloadable` · uncreatable (obtained from other objects)

Base class of Quickshell windows
### Attached properties
`QSWindow` can be used as an attached object of anything that subclasses `Item`.
It provides the following properties
- `window` - the `QSWindow` object.
- `contentItem` - the `contentItem` property of the window.

`itemPosition`, `itemRect`, and `mapFromItem` can also be called directly
on the attached object.

**Properties**
- `implicitHeight`: int — The window's desired height.
- `surfaceFormat`: { opaque: bool } — Set the surface format to request from the system.

  - `opaque` - If the requested surface should be opaque. Opaque windows allow
  the operating system to avoid drawing things behind them, or blending the window
  with those behind it, saving power and GPU load. If unset, this property defaults to
  true if `color` is opaque, or false if not. *You should not need to modify this
  property unless you create a surface that starts opaque and later becomes transparent.*

  > [!NOTE]
  > The surface format cannot be changed after the window is created.
- `screen`: ShellScreen — The screen that the window currently occupies.

  This may be modified to move the window to the given screen.
- `updatesEnabled`: bool — If the window should receive render updates. Defaults to true.

  When set to false, the window will not re-render in response to animations
  or other visual updates from other windows. This is useful for static windows
  such as wallpapers that do not need to update frequently, saving GPU cycles.

  When set back to true, a new frame is rendered, including any changes made
  while updates were disabled.
- `width`: int — The window's actual width.

  Setting this property is deprecated. Set `implicitWidth` instead.
- `data`: list<QtObject> [readonly, default]
- `mask`: Region — The clickthrough mask. Defaults to null.

  If non null then the clickable areas of the window will be determined by the provided region.

  ```qml
  ShellWindow {
    // The mask region is set to `rect`, meaning only `rect` is clickable.
    // All other clicks pass through the window to ones behind it.
    mask: Region { item: rect }

    Rectangle {
      id: rect

      anchors.centerIn: parent
      width: 100
      height: 100
    }
  }
  ```

  If the provided region's intersection mode is `Combine` (the default),
  then the region will be used as is. Otherwise it will be applied on top of the window region.

  For example, setting the intersection mode to `Xor` will invert the mask and make everything in
  the mask region not clickable and pass through clicks inside it through the window.

  ```qml
  ShellWindow {
    // The mask region is set to `rect`, but the intersection mode is set to `Xor`.
    // This inverts the mask causing all clicks inside `rect` to be passed to the window
    // behind this one.
    mask: Region { item: rect; intersection: Intersection.Xor }

    Rectangle {
      id: rect

      anchors.centerIn: parent
      width: 100
      height: 100
    }
  }
  ```
- `implicitWidth`: int — The window's desired width.
- `height`: int — The window's actual height.

  Setting this property is deprecated. Set `implicitHeight` instead.
- `backingWindowVisible`: bool [readonly] — If the window is currently shown. You should generally prefer [visible](#prop.visible).

  This property is useful for ensuring windows spawn in a specific order, and you should
  not use it in place of [visible](#prop.visible).
- `devicePixelRatio`: real [readonly] — The ratio between logical pixels and monitor pixels.

  Qt's coordinate system works in logical pixels, which equal N monitor pixels
  depending on scale factor. This property returns the amount of monitor pixels
  in a logical pixel for the current window.
- `visible`: bool — If the window should be shown or hidden. Defaults to true.
- `windowTransform`: QtObject [readonly] — Opaque property that will receive an update when factors that affect the window's position
  and transform changed.

  This property is intended to be used to force a binding update,
  along with map[To|From]Item (which is not reactive).
- `color`: color — The background color of the window. Defaults to white.

  > [!WARNING]
  > If the window color is opaque before it is made visible,
  > it will not be able to become transparent later unless `surfaceFormat`.opaque
  > is false.
- `contentItem`: Item [readonly]

**Functions**
- `itemPosition(item: Item)`: point — Returns the given Item's position relative to the window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, 0, 0)`

  See also: `Item.mapFromItem`
- `itemRect(item: Item)`: rect — Returns the given Item's geometry relative to the window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, 0, 0, 0, 0)`

  See also: `Item.mapFromItem`
- `mapFromItem(item: Item, point: point)`: point — Maps the given point in the coordinate space of `item` to one in the coordinate space
  of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, point)`

  See also: `Item.mapFromItem`
- `mapFromItem(item: Item, x: real, y: real)`: point — Maps the given point in the coordinate space of `item` to one in the coordinate space
  of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, x, y)`

  See also: `Item.mapFromItem`
- `mapFromItem(item: Item, rect: rect)`: rect — Maps the given rect in the coordinate space of `item` to one in the coordinate space
  of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, rect)`

  See also: `Item.mapFromItem`
- `mapFromItem(item: Item, x: real, y: real, width: real, height: real)`: rect — Maps the given rect in the coordinate space of `item` to one in the coordinate space
  of this window. Does not update reactively.

  Equivalent to calling `window.contentItem.mapFromItem(item, x, y, width, height)`

  See also: `Item.mapFromItem`

**Signals**
- `windowConnected()` — handler `onWindowConnected`
- `resourcesLost()` — handler `onResourcesLost` — This signal is emitted when resources a window depends on to display are lost,
  or could not be acquired during window creation. The most common trigger for
  this signal is a lack of VRAM when creating or resizing a window.

  Following this signal, `closed` will be sent.
- `closed()` — handler `onClosed` — This signal is emitted when the window is closed by the user, the display server,
  or an error. It is not emitted when `visible` is set to false.

## Quickshell
*singleton* · extends `QtObject`

**Properties**
- `clipboardText`: string — The system clipboard.

  > [!WARNING]
  > Under wayland the clipboard will be empty unless a quickshell window is focused.
- `shellDir`: string [readonly] — The full path to the root directory of your shell.

  The root directory is the folder containing the entrypoint to your shell, often referred
  to as `shell.qml`.
- `screens`: list<ShellScreen> [readonly] — All currently connected screens.

  This property updates as connected screens change.

  #### Reusing a window on every screen
  ```qml
  ShellRoot {
    Variants {
      // see Variants for details
      variants: Quickshell.screens
      PanelWindow {
        property var modelData
        screen: modelData
      }
    }
  }
  ```

  This creates an instance of your window once on every screen.
  As screens are added or removed your window will be created or destroyed on those screens.
- `stateDir`: string [readonly] — The per-shell state directory.

  Usually `~/.local/state/quickshell/by-shell/<shell-id>`

  Can be overridden using `//@ pragma StateDir $BASE/path` in the root qml file, where `$BASE`
  corresponds to `$XDG_STATE_HOME` (usually `~/.local/state`).
- `watchFiles`: bool — If true then the configuration will be reloaded whenever any files change.
  Defaults to true.
- `processId`: int [readonly] — Quickshell's process id.
- `cacheDir`: string [readonly] — The per-shell cache directory.

  Usually `~/.cache/quickshell/by-shell/<shell-id>`

  Can be overridden using `//@ pragma CacheDir $BASE/path` in the root qml file, where `$BASE`
  corresponds to `$XDG_CACHE_HOME` (usually `~/.cache`).
- `configDir`: string [readonly] — > [!WARNING]
  > Deprecated: Renamed to `shellDir` for clarity.
- `dataDir`: string [readonly] — The per-shell data directory.

  Usually `~/.local/share/quickshell/by-shell/<shell-id>`

  Can be overridden using `//@ pragma DataDir $BASE/path` in the root qml file, where `$BASE`
  corresponds to `$XDG_DATA_HOME` (usually `~/.local/share`).
- `workingDirectory`: string — Quickshell's working directory. Defaults to whereever quickshell was launched from.
- `shellRoot`: string [readonly] — > [!WARNING]
  > Deprecated: Renamed to `shellDir` for consistency.

**Functions**
- `cachePath(path: string)`: string — Equivalent to `${Quickshell.cacheDir}/${path}`
- `configPath(path: string)`: string — > [!WARNING]
  > Deprecated: Renamed to `shellPath` for clarity.
- `dataPath(path: string)`: string — Equivalent to `${Quickshell.dataDir}/${path}`
- `env(variable: string)`: variant — Returns the string value of an environment variable or null if it is not set.
- `execDetached(context: )`: void — Launch a process detached from Quickshell.

  The context parameter can either be a list of command arguments or a JS object with the following fields:
  - `command`: A list containing the command and all its arguments. See `Process.command`.
  - `environment`: Changes to make to the process environment. See `Process.environment`.
  - `clearEnvironment`: Removes all variables from the environment if true.
  - `workingDirectory`: The working directory the command should run in.

  > [!WARNING]
  > This does not run command in a shell. All arguments to the command
  > must be in separate values in the list, e.g. `["echo", "hello"]`
  > and not `["echo hello"]`.
  >
  > Additionally, shell scripts must be run by your shell,
  > e.g. `["sh", "script.sh"]` instead of `["script.sh"]` unless the script
  > has a shebang.

  > [!NOTE]
  > You can use `["sh", "-c", <your command>]` to execute your command with
  > the system shell.

  This function is equivalent to `Process.startDetached`.
- `hasQtVersion(major: int, minor: int)`: bool — Check if Qt's version is at least `major.minor`.

  > [!NOTE]
  > You can version gate code blocks using Quickshell's preprocessor which
  > has the same function available.
  >
  > ```qml
  > //@ if hasVersion(6, 10)
  > ...
  > //@ endif
  > ```
- `hasThemeIcon(icon: string)`: bool — Check if specified icon has an available icon in your icon theme
- `hasVersion(major: int, minor: int, features: )`: bool — Check if Quickshell's version is at least `major.minor` and the listed
  unreleased features are available. If Quickshell is newer than the given version
  it is assumed that all unreleased features are present. The unreleased feature list
  may be omitted.

  > [!NOTE]
  > You can version gate code blocks using Quickshell's preprocessor which
  > has the same function available.
  >
  > ```qml
  > //@ if hasVersion(0, 3, ["feature"])
  > ...
  > //@ endif
  > ```
- `hasVersion(major: int, minor: int)`: bool
- `iconPath(icon: string)`: string — Returns a string usable for a `Image.source` for a given system icon.

  > [!NOTE]
  > By default, icons are loaded from the theme selected by the qt platform theme,
  > which means they should match with all other qt applications on your system.
  >
  > If you want to use a different icon theme, you can put `//@ pragma IconTheme <name>`
  > at the top of your root config file or set the `QS_ICON_THEME` variable to the name
  > of your icon theme.
- `iconPath(icon: string, check: bool)`: string — Setting the `check` parameter of `iconPath` to true will return an empty string
  if the icon does not exist, instead of an image showing a missing texture.
- `iconPath(icon: string, fallback: string)`: string — Setting the `fallback` parameter of `iconPath` will attempt to load the fallback
  icon if the requested one could not be loaded.
- `inhibitReloadPopup()`: void — When called from `reloadCompleted` or `reloadFailed`, prevents the
  default reload popup from displaying.

  The popup can also be blocked by setting `QS_NO_RELOAD_POPUP=1`.
- `reload(hard: bool)`: void — Reload the shell.

  `hard` - perform a hard reload. If this is false, Quickshell will attempt to reuse windows
  that already exist. If true windows will be recreated.

  See `Reloadable` for more information on what can be reloaded and how.
- `shellPath(path: string)`: string — Equivalent to `${Quickshell.configDir}/${path}`
- `statePath(path: string)`: string — Equivalent to `${Quickshell.stateDir}/${path}`

**Signals**
- `reloadFailed(errorString: string)` — handler `onReloadFailed` — The reload sequence has failed.
- `lastWindowClosed()` — handler `onLastWindowClosed` — Sent when the last window is closed.

  To make the application exit when the last window is closed run `Qt.quit()`.
- `reloadCompleted()` — handler `onReloadCompleted` — The reload sequence has completed successfully.

## QuickshellSettings
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Accessor for some options under the Quickshell type.

**Properties**
- `workingDirectory`: string — Quickshell's working directory. Defaults to whereever quickshell was launched from.
- `watchFiles`: bool — If true then the configuration will be reloaded whenever any files change.
  Defaults to true.

**Signals**
- `lastWindowClosed()` — handler `onLastWindowClosed` — Sent when the last window is closed.

  To make the application exit when the last window is closed run `Qt.quit()`.

## Region
*class* · extends `QtObject`

See `QsWindow.mask`.

**Properties**
- `y`: int — Defaults to 0. Does nothing if `item` is set.
- `item`: Item — The item that determines the geometry of the region.
  `item` overrides `x`, `y`, `width` and `height`.
- `intersection`: Intersection — The way this region interacts with its parent region. Defaults to `Combine`.
- `topLeftRadius`: int — Top-left corner radius. Only applies when `shape` is `Rect`.

  Defaults to `radius`, and may be reset by assigning `undefined`.
- `height`: int — Defaults to 0. Does nothing if `item` is set.
- `topRightRadius`: int — Top-right corner radius. Only applies when `shape` is `Rect`.

  Defaults to `radius`, and may be reset by assigning `undefined`.
- `x`: int — Defaults to 0. Does nothing if `item` is set.
- `regions`: list<Region> [readonly, default] — Regions to apply on top of this region.

  Regions can be nested to create a more complex region.
  For example this will create a square region with a cutout in the middle.
  ```qml
  Region {
    width: 100; height: 100;

    Region {
      x: 50; y: 50;
      width: 50; height: 50;
      intersection: Intersection.Subtract
    }
  }
  ```
- `bottomRightRadius`: int — Bottom-right corner radius. Only applies when `shape` is `Rect`.

  Defaults to `radius`, and may be reset by assigning `undefined`.
- `shape`: RegionShape — Defaults to `Rect`.
- `radius`: int — Corner radius for rounded rectangles. Only applies when `shape` is `Rect`. Defaults to 0.

  Acts as the default for `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`,
  and `bottomRightRadius`.
- `bottomLeftRadius`: int — Bottom-left corner radius. Only applies when `shape` is `Rect`.

  Defaults to `radius`, and may be reset by assigning `undefined`.
- `width`: int — Defaults to 0. Does nothing if `item` is set.

**Signals**
- `childrenChanged()` — handler `onChildrenChanged`
- `changed()` — handler `onChanged` — Triggered when the region's geometry changes.

  In some cases the region does not update automatically.
  In those cases you can emit this signal manually.

## RegionShape
*enum*

See `Region.shape`.

**Values:** `RegionShape.Rect`, `RegionShape.Ellipse`

## Reloadable
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Reloadables will attempt to take specific state from previous config revisions if possible.
Some examples are `ProxyWindowBase` and `PersistentProperties`

**Properties**
- `reloadableId`: string — An additional identifier that can be used to try to match a reloadable object to its
  previous state.

  Simply keeping a stable identifier across config versions (saves) is
  enough to help the reloader figure out which object in the old revision corresponds to
  this object in the current revision, and facilitate smoother reloading.

  Note that identifiers are scoped, and will try to do the right thing in context.
  For example if you have a `Variants` wrapping an object with an identified element inside,
  a scope is created at the variant level.

  ```qml
  Variants {
    // multiple variants of the same object tree
    variants: [ { foo: 1 }, { foo: 2 } ]

    // any non `Reloadable` object
    QtObject {
      FloatingWindow {
        // this FloatingWindow will now be matched to the same one in the previous
        // widget tree for its variant. "myFloatingWindow" refers to both the variant in
        // `foo: 1` and `foo: 2` for each tree.
        reloadableId: "myFloatingWindow"

        // ...
      }
    }
  }
  ```

## Retainable
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Retainable works as an attached property that allows objects to be
kept around (retained) after they would normally be destroyed, which
is especially useful for things like exit transitions.

An object that is retainable will have `Retainable` as an attached property.
All retainable objects will say that they are retainable on their respective
typeinfo pages.

> [!NOTE]
> Working directly with `Retainable` is often overly complicated and
> error prone. For this reason `RetainableLock` should
> usually be used instead.

**Properties**
- `retained`: bool [readonly] — If the object is currently in a retained state.

**Functions**
- `forceUnlock()`: void — Forcibly remove all locks, destroying the object.

  `unlock` should usually be preferred.
- `lock()`: void — Hold a lock on the object so it cannot be destroyed.

  A counter is used to ensure you can lock the object from multiple places
  and it will not be unlocked until the same number of unlocks as locks have occurred.

  > [!WARNING]
  > It is easy to forget to unlock a locked object.
  > Doing so will create what is effectively a memory leak.
  >
  > Using `RetainableLock` is recommended as it will help
  > avoid this scenario and make misuse more obvious.
- `unlock()`: void — Remove a lock on the object. See `lock` for more information.

**Signals**
- `aboutToDestroy()` — handler `onAboutToDestroy` — This signal is sent immediately before the object is destroyed.
  At this point destruction cannot be interrupted.
- `dropped()` — handler `onDropped` — This signal is sent when the object would normally be destroyed.

  If all signal handlers return and no locks are in place, the object will be destroyed.
  If at least one lock is present the object will be retained until all are removed.

## RetainableLock
*class* · extends `QtObject`

A RetainableLock provides extra safety and ease of use for locking
`Retainable` objects. A retainable object can be locked by multiple
locks at once, and each lock re-exposes relevant properties
of the retained objects.

#### Example
The code below will keep a retainable object alive for as long as the
RetainableLock exists.

```qml
RetainableLock {
  object: aRetainableObject
  locked: true
}
```

**Properties**
- `retained`: bool [readonly] — If the object is currently in a retained state.
- `locked`: bool — If the object should be locked.
- `object`: QtObject — The object to lock. Must be `Retainable`.

**Signals**
- `aboutToDestroy()` — handler `onAboutToDestroy` — Rebroadcast of the object's `Retainable.aboutToDestroy`.
- `dropped()` — handler `onDropped` — Rebroadcast of the object's `Retainable.dropped`.

## Scope
*class* · extends `Reloadable`

Convenience type equivalent to setting `Reloadable.reloadableId` for all children.

Note that this does not work for visible `Item`s (all widgets).

```qml
ShellRoot {
  Variants {
    variants: ...

    Scope {
      // everything in here behaves the same as if it was defined
      // directly in `Variants` reload-wise.
    }
  }
}

**Properties**
- `children`: list<QtObject> [readonly, default]

## ScriptModel
*class* · extends ``

ScriptModel is a QML [Data Model] that generates model operations based on changes
to a javascript expression attached to `values`.

### When should I use this
ScriptModel should be used when you would otherwise use a javascript expression as a model,
[QAbstractItemModel] is accepted, and the data is likely to change over the lifetime of the program.

When directly using a javascript expression as a model, types like `Repeater` or `ListView`
will destroy all created delegates, and re-create the entire list. In the case of `ListView` this
will also prevent animations from working. If you wrap your expression with ScriptModel, only new items
will be created, and ListView animations will work as expected.

### Example
```qml
// Will cause all delegates to be re-created every time filterText changes.
Repeater {
  model: myList.filter(entry => entry.name.startsWith(filterText))
  delegate: // ...
}

// Will add and remove delegates only when required.
Repeater {
  model: ScriptModel {
    values: myList.filter(entry => entry.name.startsWith(filterText))
  }

  delegate: // ...
}
```
[QAbstractItemModel]: https://doc.qt.io/qt-6/qabstractitemmodel.html
[Data Model]: https://doc.qt.io/qt-6/qtquick-modelviewsdata-modelview.html#qml-data-models

**Properties**
- `objectProp`: string — The property that javascript objects passed into the model will be compared with.

  For example, if `objectProp` is `"myprop"` then `{ myprop: "a", other: "y" }` and
  `{ myprop: "a", other: "z" }` will be considered equal.

  Defaults to `""`, meaning no key.
- `comparisonMode`: ObjectComparison — How values should be compared. Defaults to `ObjectComparison.Structure`.

  Identity based comparison is faster if usable for a given model, and often
  achievable with `objectProp`.
- `values`: list<>

## ShellRoot
*class* · extends `Scope`

Optional root config element, allowing some settings to be specified inline.

**Properties**
- `settings`: QuickshellSettings [readonly]

## ShellScreen
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Monitor object useful for setting the monitor for a `QsWindow`
or querying information about the monitor.

> [!WARNING]
> If the monitor is disconnected, then any stored copies of its ShellMonitor will
> be marked as dangling and all properties will return default values.
> Reconnecting the monitor will not reconnect it to the ShellMonitor object.

Due to some technical limitations, it was not possible to reuse the native qml `Screen` type.

**Properties**
- `height`: int [readonly]
- `name`: string [readonly] — The name of the screen as seen by the operating system.

  Usually something like `DP-1`, `HDMI-1`, `eDP-1`.
- `devicePixelRatio`: real [readonly] — The ratio between physical pixels and device-independent (scaled) pixels.
- `width`: int [readonly]
- `orientation`:  [readonly]
- `primaryOrientation`:  [readonly]
- `model`: string [readonly] — The model of the screen as seen by the operating system.
- `x`: int [readonly]
- `y`: int [readonly]
- `serialNumber`: string [readonly] — The serial number of the screen as seen by the operating system.
- `logicalPixelDensity`: real [readonly] — The number of device-independent (scaled) pixels per millimeter.
- `physicalPixelDensity`: real [readonly] — The number of physical pixels per millimeter.

**Functions**
- `toString()`: string

## Singleton
*class* · extends `Scope`

All singletons should inherit from this type.

## SystemClock
*enum* · extends `QtObject`

SystemClock is a view into the system's clock.
It updates at hour, minute, or second intervals depending on `precision`.

# Examples
```qml
SystemClock {
  id: clock
  precision: SystemClock.Seconds
}

Text {
  text: Qt.formatDateTime(clock.date, "hh:mm:ss - yyyy-MM-dd")
}
```

> [!WARNING]
> Clock updates will trigger within 50ms of the system clock changing,
> however this can be either before or after the clock changes (+-50ms). If you
> need a date object, use `date` instead of constructing a new one, or the time
> of the constructed object could be off by up to a second.

**Properties**
- `enabled`: bool — If the clock should update. Defaults to true.

  Setting enabled to false pauses the clock.
- `precision`: SystemClock — The precision the clock should measure at. Defaults to `SystemClock.Seconds`.
- `date`: date [readonly] — The current date and time.

  > [!TIP]
  > You can use `Qt.formatDateTime` to get the time as a string in
  > your format of choice.
- `hours`: int [readonly] — The current hour.
- `minutes`: int [readonly] — The current minute, or 0 if `precision` is `SystemClock.Hours`.
- `seconds`: int [readonly] — The current second, or 0 if `precision` is `SystemClock.Hours` or `SystemClock.Minutes`.

**Values:** `SystemClock.Hours`, `SystemClock.Minutes`, `SystemClock.Seconds`

## TransformWatcher
*class* · extends `QtObject`

The TransformWatcher monitors all properties that affect the geometry
of two `Item`s relative to eachother.

> [!NOTE]
> The algorithm responsible for determining the relationship
> between `a` and `b` is biased towards `a` being a parent of `b`,
> or `a` being closer to the common parent of `a` and `b` than `b`.

**Properties**
- `transform`: QtObject [readonly] — This property is updated whenever the geometry of any item in the path from `a` to `b` changes.

  Its value is undefined, and is intended to trigger an expression update.
- `a`: Item
- `commonParent`: Item — Known common parent of both `a` and `b`. Defaults to `null`.

  This property can be used to optimize the algorithm that figures out
  the relationship between `a` and `b`. Setting it to something that is not
  a common parent of both `a` and `b` will prevent the path from being determined
  correctly, and setting it to `null` will disable the optimization.
- `b`: Item

## Variants
*class* · extends `Reloadable`

Creates and destroys instances of the given component when the given property changes.

`Variants` is similar to `Repeater` except it is for *non `Item`* objects, and acts as
a reload scope.

Each non duplicate value passed to `model` will create a new instance of
`delegate` with a `modelData` property set to that value.

See `Quickshell.screens` for an example of using `Variants` to create copies of a window per
screen.

> [!WARNING]
> BUG: Variants currently fails to reload children if the variant set is changed as
> it is instantiated. (usually due to a mutation during variant creation)

**Properties**
- `delegate`: Component [default] — The component to create instances of.

  The delegate should define a `modelData` property that will be populated with a value
  from the `model`.
- `instances`: list<QtObject> [readonly] — Current instances of the delegate.
- `model`: list<variant> — The list of sets of properties to create instances with.
  Each set creates an instance of the component, which are updated when the input sets update.
