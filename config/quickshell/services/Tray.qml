// =============================================================================
// dragon-island — Tray.qml
// Service: system tray (StatusNotifierItem) for the right island
// =============================================================================
/**
 * Referencing SystemTray makes Quickshell the tray host (it also provides the
 * org.kde.StatusNotifierWatcher when no one else does), so apps such as Proton VPN
 * detect a tray and minimize to it.
 *
 * Properties:
 *   - items: list<SystemTrayItem> [readonly] (Active / NeedsAttention only; Passive ones are hidden)
 *   - hasItems: bool [readonly]
 *
 * Functions:
 *   - iconSource(item, failed: bool): string (Image source: theme name → Quickshell.iconPath,
 *                                     "?path=" → <dir>/<name>.png; failed = the first source
 *                                     didn't load → theme lookup by name with a generic fallback)
 *   - click(item, anchor): void       (left click: activate, or open the menu if the item only has a menu)
 *   - secondaryActivate(item): void   (middle click)
 *   - scroll(item, dx: int, dy: int): void (wheel; the dominant axis is sent, apps ignore it if unsupported)
 *   - openMenu(anchor): void          (right click: QsMenuAnchor bound to item.menu)
 *   - needsAttention(item): bool
 *   - tooltip(item): string
 */
pragma Singleton
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick

Singleton {
    id: root

    readonly property string fallbackIcon: "application-x-executable"

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
    readonly property bool hasItems: items.length > 0

    function iconSource(item, failed: bool): string {
        const icon = item?.icon ?? "";
        const pathAt = icon.indexOf("?path=");
        const base = pathAt >= 0 ? icon.slice(0, pathAt) : icon;
        const name = base.slice(base.lastIndexOf("/") + 1);
        if (icon === "" || failed) return Quickshell.iconPath(name || fallbackIcon, fallbackIcon);
        // Apps that ship their own icon dir (IconThemePath) come as "image://icon/<name>?path=<dir>",
        // which the theme provider can't resolve: load the file from that dir instead.
        if (pathAt >= 0) return `file://${icon.slice(pathAt + 6)}/${name}.png`;
        // Bare theme names (no scheme): resolve through the icon theme
        if (!icon.includes(":/")) return Quickshell.iconPath(icon, fallbackIcon);
        return icon;
    }

    function click(item, anchor): void {
        if (!item) return;
        if (item.onlyMenu && item.hasMenu) openMenu(anchor);
        else item.activate();
    }

    function secondaryActivate(item): void { item?.secondaryActivate(); }

    function scroll(item, dx: int, dy: int): void {
        if (!item) return;
        if (Math.abs(dx) > Math.abs(dy)) item.scroll(dx, true);
        else if (dy !== 0) item.scroll(dy, false);
    }

    function openMenu(anchor): void {
        if (!anchor?.menu) return;
        if (anchor.visible) anchor.close();
        else anchor.open();
    }

    function needsAttention(item): bool { return item?.status === Status.NeedsAttention; }

    function tooltip(item): string {
        if (!item) return "";
        return item.tooltipTitle || item.title || item.id || "";
    }
}
