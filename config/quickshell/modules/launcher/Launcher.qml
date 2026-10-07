// =============================================================================
// dragon-island — Launcher.qml
// App launcher (SUPER + Space): fuzzy search over DesktopEntries (Apps service).
// Keyboard: type to filter · ↑/↓ or Tab to move · Enter to launch · Esc to close.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    readonly property Item frameItem: card.visible ? card.frameItem : null   // blur region of the window
    property int current: 0
    readonly property var results: shown ? Apps.search(search.text) : []

    function focusSearch(): void { search.focusInput(); }

    function move(delta: int): void {
        if (results.length === 0) return;
        current = (current + delta + results.length) % results.length;
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function launch(entry): void {
        if (!entry) return;
        ShellState.close();
        Apps.launch(entry);
    }

    onShownChanged: {
        if (shown) {
            search.text = "";
            current = 0;
        }
    }
    onResultsChanged: current = 0

    PopoverFrame {
        id: card
        shown: root.shown
        popWidth: Theme.launcherWidth
        originX: width / 2
        x: (root.width - width) / 2
        y: Theme.launcherTop

        InputField {
            id: search
            Layout.fillWidth: true
            icon: Icons.search
            placeholder: "Buscar aplicaciones…"
            onNavigate: d => root.move(d)
            onAccepted: root.launch(root.results[root.current])
            onEscapePressed: ShellState.close()
        }

        UiText {
            visible: root.results.length === 0 && search.text.length > 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingMd
            Layout.bottomMargin: Theme.spacingMd
            horizontalAlignment: Text.AlignHCenter
            text: `Sin resultados para «${search.text}»`
            color: Theme.textDim
        }

        ListView {
            id: list
            visible: root.results.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.results.length, Theme.launcherRows) * (Theme.rowHeight + spacing)
            clip: true
            spacing: Theme.spacingXs
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.current
            model: ScriptModel {
                values: root.results
                comparisonMode: ObjectComparison.Identity
            }
            delegate: ListRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                iconSource: Apps.iconFor(modelData)
                title: modelData.name
                subtitle: modelData.genericName || modelData.comment || ""
                highlighted: index === root.current
                onClicked: root.launch(modelData)
                onHoveredChanged: if (hovered) root.current = index
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: `${Apps.count} aplicaciones · ↑↓ mover · Enter abrir · Esc cerrar`
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }
}
