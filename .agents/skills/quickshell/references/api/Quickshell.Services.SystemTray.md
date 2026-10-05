# Quickshell.Services.SystemTray

`import Quickshell.Services.SystemTray`

Types for implementing a system tray

## Category
*enum*

See `StatusNotifierItem.category`.

**Values:** `Category.SystemServices`, `Category.Hardware`, `Category.ApplicationStatus`, `Category.Communications`

## Status
*enum*

See `StatusNotifierItem.status`.

**Values:** `Status.NeedsAttention`, `Status.Active`, `Status.Passive`

## SystemTray
*singleton* · extends `QtObject`

Referencing the SystemTray singleton will make quickshell start tracking
system tray contents, which are updated as the tray changes, and can be
accessed via the `items` property.

**Properties**
- `items`: ObjectModel<SystemTrayItem> [readonly] — List of all system tray icons.

## SystemTrayItem
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A system tray item, roughly conforming to the [kde/freedesktop spec]
(there is no real spec, we just implemented whatever seemed to actually be used).

[kde/freedesktop spec]: https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/StatusNotifierItem/

**Properties**
- `tooltipTitle`: string [readonly]
- `id`: string [readonly] — A name unique to the application, such as its name.
- `menu`:  [readonly] — A handle to the menu associated with this tray item, if any.

  Can be displayed with `QsMenuAnchor` or `QsMenuOpener`.
- `icon`: string [readonly] — Icon source string, usable as an Image source.
- `onlyMenu`: bool [readonly] — If this tray item only offers a menu and activation will do nothing.
- `status`: Status [readonly]
- `title`: string [readonly] — Text that describes the application.
- `tooltipDescription`: string [readonly]
- `hasMenu`: bool [readonly] — If this tray item has an associated menu accessible via `display` or `menu`.
- `category`: Category [readonly]

**Functions**
- `activate()`: void — Primary activation action, generally triggered via a left click.
- `display(parentWindow: QtObject, relativeX: int, relativeY: int)`: void — Display a platform menu at the given location relative to the parent window.
- `scroll(delta: int, horizontal: bool)`: void — Scroll action, such as changing volume on a mixer.
- `secondaryActivate()`: void — Secondary activation action, generally triggered via a middle click.

**Signals**
- `ready()` — handler `onReady`
