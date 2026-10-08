// =============================================================================
// dragon-island — Launcher.qml: the orbital launcher (SUPER + Space)
// Logic wrapper around LauncherView (the visual layer: neural core as the planet, search field in its centre,
// apps on a tilted ring). Lives inside LauncherWindow (the one "dragon-launcher" window), next to the power
// menu, clipboard history and shortcuts.
//   entries      : favourites first, then the most launched, then alphabetical (Apps.search("") order); the view
//                  re-ranks by match quality while typing and keeps this order for ties
//   =expression  : the result shows under the field, Enter copies it      >command : Enter runs it in Ghostty
//   +name        : Enter opens the Tienda (pacman + AUR) searching for «name»
//   Ctrl+I       : no match → open the Tienda searching for the query      Ctrl+F : pin / unpin the app in front
//   ← → Tab / wheel turn the ring · Enter launches · Esc clears, then closes
// =============================================================================
import Quickshell
import QtQuick
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    readonly property string query: view.query

    readonly property string calcResult: query.startsWith("=") ? Apps.calc(query.slice(1)) : ""
    readonly property bool isCommand: query.startsWith(">")
    readonly property bool isStore: query.startsWith("+")
    readonly property bool special: query.startsWith("=") || isCommand || isStore
    readonly property var frontApp: view.n > 0 ? view.filtered[view.sel] : null

    // [{ id, name, subtitle, icon }] — icon is a file:// URL (or the icon theme's image provider URL)
    readonly property var entries: {
        const all = Apps.search("");
        const favs = Apps.favorites.map(id => all.find(e => e.id === id)).filter(e => e);
        return favs.concat(all.filter(e => favs.indexOf(e) < 0)).map(e => ({
            id: e.id,
            name: e.name || "",
            subtitle: e.genericName || e.comment || "",
            icon: Apps.iconFor(e)
        }));
    }

    function focusSearch(): void { view.focusInput(); }

    function openStore(): void {
        Store.pendingQuery = (isStore ? query.slice(1) : query).trim();
        ShellState.close();
        ShellState.open("store");
    }

    function accept(): void {
        if (calcResult.length > 0) { Apps.copy(calcResult); ShellState.close(); }
        else if (isStore) openStore();
        else if (isCommand) { const c = query.slice(1).trim(); if (c.length > 0) { ShellState.close(); Apps.runInTerminal(c); } }
    }

    LauncherView {
        id: view
        anchors.fill: parent
        apps: root.entries
        open: root.shown
        uiFont: Theme.fontUi
        monoFont: Theme.fontMono
        reducedMotion: !Theme.animationsEnabled
        onActivated: id => { ShellState.close(); Apps.launchById(id); }
        onCloseRequested: ShellState.close()
    }

    // the view only knows apps: the special prefixes are handled here, before the view sees Enter
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.shown && root.special
        onActivated: root.accept()
    }
    Shortcut {
        sequence: "Ctrl+I"
        enabled: root.shown && root.query.trim().length > 0 && (view.noMatch || root.isStore)
        onActivated: root.openStore()
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.shown && root.frontApp !== null
        onActivated: Apps.toggleFavorite(DesktopEntries.byId(root.frontApp.id))
    }

    // result / hint under the search field
    UiText {
        visible: root.shown && (root.calcResult.length > 0 || root.special || view.noMatch)
        x: view.cx - width / 2
        y: view.cy + 34 * view.s
        z: 20
        mono: root.calcResult.length > 0
        size: root.calcResult.length > 0 ? Theme.sizeGreeting : Theme.sizeCaption + 1
        weight: root.calcResult.length > 0 ? Theme.weightSemiBold : Theme.weightRegular
        color: root.calcResult.length > 0 ? Theme.accent : Theme.textDim
        shadow: true
        text: root.calcResult.length > 0 ? `= ${root.calcResult}`
            : root.isStore ? "Enter: buscar en la Tienda (pacman + AUR)"
            : root.isCommand ? "Enter: ejecutar en Ghostty"
            : root.query.startsWith("=") ? "Escribe una operación"
            : "Ctrl+I: buscar en la Tienda (pacman + AUR)"
    }
}
