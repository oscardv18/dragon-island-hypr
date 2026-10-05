# Quickshell.DBusMenu

`import Quickshell.DBusMenu`

Types related to DBusMenu (used in system tray)

## DBusMenuHandle
*class* · extends `QtObject` · uncreatable (obtained from other objects)

Handle to a menu tree provided by a remote process.

**Properties**
- `menu`: DBusMenuItem [readonly]

## DBusMenuItem
*class* · extends `QsMenuEntry` · uncreatable (obtained from other objects)

Menu item shared by an external program via the
[DBusMenu specification](https://github.com/AyatanaIndicators/libdbusmenu/blob/master/libdbusmenu-glib/dbus-menu.xml).

**Properties**
- `menuHandle`: DBusMenuHandle [readonly] — Handle to the root of this menu.

**Functions**
- `updateLayout()`: void — Refreshes the menu contents.

  Usually you shouldn't need to call this manually but some applications providing
  menus do not update them correctly. Call this if menus don't update their state.

  The `layoutUpdated` signal will be sent when a response is received.

**Signals**
- `layoutUpdated()` — handler `onLayoutUpdated`
