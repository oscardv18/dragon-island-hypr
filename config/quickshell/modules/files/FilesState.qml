// State of one explorer window: its tabs and the view options they share (list/grid, order, hidden files, search).
// Pure; FilesWindow (real services) and tests/qml/files_mock.qml (fixtures) create it with injected services.
import QtQuick
import "files.js" as F

QtObject {
    id: state
    property var service: null
    property bool active: true            // the window is on screen: only then the current tab watches its folder
    property var tabs: []
    property int currentIndex: 0
    readonly property var tab: tabs[currentIndex] ?? null
    property string viewMode: "lista"     // lista | cuadricula
    property string sortKey: "name"
    property bool sortDesc: false
    property bool dirsFirst: true
    property bool showHidden: false
    property string search: ""

    property Component _tabComponent: Component { FilesTab {} }

    function newTab(path): void {
        const t = _tabComponent.createObject(state, { service: state.service, view: state });
        tabs = tabs.concat([t]);
        setCurrent(tabs.length - 1);
        t.go(path || service?.home || "/");
    }
    function closeTab(i): void {
        if (tabs.length <= 1 || i < 0 || i >= tabs.length) return;
        const t = tabs[i];
        t.setWatching(false);
        const rest = tabs.slice(); rest.splice(i, 1);
        const keep = tab === t ? null : tab;
        tabs = rest;
        currentIndex = keep ? rest.indexOf(keep) : Math.min(i, rest.length - 1);
        _syncWatch();
        t.destroy();
    }
    function setCurrent(i): void {
        if (i < 0 || i >= tabs.length) return;
        currentIndex = i;
        search = "";
        _syncWatch();
    }
    function cycleTab(delta): void { if (tabs.length) setCurrent((currentIndex + delta + tabs.length) % tabs.length); }
    function go(path): void { tab?.go(path); }
    function setSort(key): void {
        if (sortKey === key) sortDesc = !sortDesc;
        else { sortKey = key; sortDesc = key === "mtime" || key === "size"; }
    }
    function cycleSort(): void {
        const keys = ["name", "size", "mtime", "type"];
        setSort(keys[(keys.indexOf(sortKey) + 1) % keys.length]);
    }
    function _syncWatch(): void { for (let i = 0; i < tabs.length; i++) tabs[i].setWatching(active && i === currentIndex); }
    onActiveChanged: _syncWatch()
    readonly property string sortCaption: F.sortCaption(sortKey, sortDesc, showHidden, dirsFirst)
    Component.onDestruction: { for (const t of tabs) t.setWatching(false); }
}
