# Quickshell.WindowManager

`import Quickshell.WindowManager`

Window manager interface

## ScreenProjection
*class* · extends `WindowsetProjection` · uncreatable (obtained from other objects)

A ScreenProjection is a special type of `WindowsetProjection` which aggregates
all windowsets across all projections covering a specific screen.

When used with `Windowset.setProjection`, an arbitrary projection on the screen
will be picked. Usually there is only one.

Use `WindowManager.screenProjection` to get a ScreenProjection for a given screen.

## WindowManager
*singleton* · extends `QtObject`

Window management interfaces exposed by the window manager.

**Properties**
- `windowsets`: list<Windowset> [readonly] — All windowsets tracked by the WM across all projections.
- `windowsetProjections`: list<WindowsetProjection> [readonly] — All windowset projections tracked by the WM. Does not include
  internal projections from `screenProjection`.

**Functions**
- `screenProjection(screen: ShellScreen)`: ScreenProjection — Returns an internal WindowsetProjection that covers a single screen and contains all
  windowsets on that screen, regardless of the WM-specified projection. Depending on
  how the WM lays out its actual projections, multiple ScreenProjections may contain
  the same Windowsets.

## Windowset
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A Windowset is a generic type that encompasses both "Workspaces" and "Tags" in window managers.
Because the definition encompasses both you may not necessarily need all features.

**Properties**
- `active`: bool [readonly] — True if the windowset is currently active. In a workspace based WM, this means the
  represented workspace is current. In a tag based WM, this means the represented tag
  is active.
- `coordinates`: list<int> [readonly] — Coordinates of the workspace, represented as an N-dimensional array. Most WMs
  will only expose one coordinate. If more than one is exposed, the first is
  conventionally X, the second Y, and the third Z.
- `canRemove`: bool [readonly] — If true, the windowset can be removed. This may be done implicitly by the WM as well.
- `name`: string [readonly] — Human readable name of the windowset.
- `urgent`: bool [readonly] — If true, a window in this windowset has been marked as urgent.
- `canDeactivate`: bool [readonly] — If true, the windowset can be deactivated. In a workspace based WM, deactivation is usually implicit
  and based on activation of another workspace.
- `projection`: WindowsetProjection [readonly] — The projection this windowset is a member of. A projection is the set of screens covered by
  a windowset.
- `id`: string [readonly] — A persistent internal identifier for the windowset. This property should be identical
  across restarts and destruction/recreation of a windowset.
- `canActivate`: bool [readonly] — If true, the windowset can be activated. In a workspace based WM, this will make the workspace
  current, in a tag based wm, the tag will be activated.
- `shouldDisplay`: bool [readonly] — If false, this windowset should generally be hidden from workspace pickers.
- `canSetProjection`: bool [readonly] — If true, the windowset can be moved to a different projection.

**Functions**
- `activate()`: void — Activate the windowset, making it the current workspace on a workspace based WM, or activating
  the tag on a tag based WM. Requires `canActivate`.
- `deactivate()`: void — Deactivate the windowset, hiding it. Requires `canDeactivate`.
- `remove()`: void — Remove or destroy the windowset. Requires `canRemove`.
- `setProjection(projection: WindowsetProjection)`: void — Move the windowset to a different projection. A projection represents the set of screens
  a workspace spans. Requires `canSetProjection`.

## WindowsetProjection
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A WindowsetProjection represents a space that can be occupied by one or more `Windowset`s.
The space is one or more screens. Multiple projections may occupy the same screens.

`WindowManager.screenProjection` can be used to get a projection representing all
`Windowset`s on a given screen regardless of the WM's actual projection layout.

**Properties**
- `windowsets`: list<Windowset> [readonly] — Windowsets that are currently present on the projection.
- `screens`: list<ShellScreen> [readonly] — Screens the windowset projection spans, often a single screen or all screens.
