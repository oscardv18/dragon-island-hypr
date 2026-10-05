// =============================================================================
// dragon-island — Apps.qml
// Service: Desktop Applications & Launcher Provider
// =============================================================================
/**
 * Properties:
 *   - list: list<DesktopEntry> [readonly] (alphabetically sorted applications)
 *   - count: int [readonly]
 *
 * Functions:
 *   - search(query: string): list<DesktopEntry>
 *   - launch(entry: DesktopEntry): void
 *   - launchById(id: string): void
 *   - iconFor(entry: DesktopEntry): string
 *
 * Signals:
 *   - launched(name: string)
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var list: {
        const apps = DesktopEntries.applications.values.slice();
        return apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    }

    readonly property int count: list.length

    function search(query: string): var {
        if (!query || query.trim().length === 0) {
            return root.list;
        }
        const q = query.trim().toLowerCase();
        return root.list.filter(app => {
            const nameMatch = (app.name || "").toLowerCase().includes(q);
            const genMatch = (app.genericName || "").toLowerCase().includes(q);
            const commMatch = (app.comment || "").toLowerCase().includes(q);
            const keyMatch = app.keywords && app.keywords.some(k => k.toLowerCase().includes(q));
            return nameMatch || genMatch || commMatch || keyMatch;
        });
    }

    function launch(entry: DesktopEntry): void {
        if (entry) {
            entry.execute();
            root.launched(entry.name);
        }
    }

    function launchById(id: string): void {
        const entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
        if (entry) {
            entry.execute();
            root.launched(entry.name);
        }
    }

    function iconFor(entry: DesktopEntry): string {
        if (!entry || !entry.icon) return "";
        return Quickshell.iconPath(entry.icon);
    }

    signal launched(name: string)
}
