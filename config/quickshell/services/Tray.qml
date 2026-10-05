// =============================================================================
// dragon-island — Tray.qml
// Service: system tray (StatusNotifierItem) for the right island
// =============================================================================
/**
 * Properties:
 *   - items: list<SystemTrayItem> [readonly] (Active / NeedsAttention only; Passive ones are hidden)
 *   - hasItems: bool [readonly]
 *
 * Functions:
 *   - activate(item): void            (left click; opens the menu if the item only has a menu)
 *   - secondaryActivate(item): void   (middle click)
 *   - scroll(item, delta: int): void
 *   - showMenu(item, window, x: int, y: int): void (right click: platform menu at window-relative x,y)
 *   - needsAttention(item): bool
 *   - tooltip(item): string
 */
pragma Singleton
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Singleton {
    id: root

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    readonly property bool hasItems: items.length > 0

    function activate(item): void {
        if (!item) return;
        if (item.onlyMenu && item.hasMenu) return;   // caller shows the menu instead
        item.activate();
    }

    function secondaryActivate(item): void { item?.secondaryActivate(); }
    function scroll(item, delta: int): void { item?.scroll(delta, false); }

    function showMenu(item, window, x: int, y: int): void {
        if (item?.hasMenu) item.display(window, x, y);
    }

    function needsAttention(item): bool { return item?.status === Status.NeedsAttention; }

    function tooltip(item): string {
        if (!item) return "";
        return item.tooltipTitle || item.title || item.id || "";
    }
}
