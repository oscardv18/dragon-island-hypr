// The whole explorer view (33-archivos-*), pure: FilesWindow injects the real services, tests/qml/files_mock.qml
// injects fixtures. Layout: sidebar · toolbar (back/forward/up, editable breadcrumbs, search, Compartir, list/grid)
// · tabs with the order caption · list or grid (+ preview panel) · status bar.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: root
    property var files: null
    property var ops: null
    property var devices: null
    property var archives: null
    property string initialPath: ""
    property bool active: true            // window visible: the current tab watches its folder
    property bool drawFrame: true         // false while the global window frame already outlines this window
    property real now: Date.now()
    signal closeRequested()
    readonly property FilesState state: FilesState { service: root.files; active: root.active }
    readonly property var tab: state.tab
    property bool editingPath: false

    implicitWidth: Theme.files.width
    implicitHeight: Theme.files.height
    radius: Theme.files.radius
    color: Theme.files.panel
    border.width: Theme.files.border
    border.color: Theme.files.buttonBorder
    focus: true
    Component.onCompleted: state.newTab(initialPath || files?.home || "/")

    function activate(entry): void {
        if (!entry || !tab) return;
        const p = tab.pathOf(entry);
        if (entry.kind === "dir" || (entry.kind === "link" && entry.link_dir)) tab.go(p);
        else files?.open(p);
    }
    function activateSelection(): void {
        const sel = tab?.selection.length ? tab.selection : (tab?.current ? [tab.current] : []);
        if (sel.length === 1) activate(sel[0]);
        else for (const e of sel) if (e.kind !== "dir") files?.open(tab.pathOf(e));
    }
    function editPath(): void { editingPath = true; Qt.callLater(() => pathInput.focusInput()); }
    function focusSearch(): void { searchInput.focusInput(); }
    function focusContent(): void { root.forceActiveFocus(); }
    readonly property int pageStep: state.viewMode === "cuadricula" ? grid.columns : 1

    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier, shift = e.modifiers & Qt.ShiftModifier;
        let handled = true;
        if (alt && e.key === Qt.Key_Left) tab?.back();
        else if (alt && e.key === Qt.Key_Right) tab?.forward();
        else if (alt && e.key === Qt.Key_Up) tab?.up();
        else if (e.key === Qt.Key_Backspace) tab?.up();
        else if (e.key === Qt.Key_Down) tab?.move(pageStep, e.modifiers);
        else if (e.key === Qt.Key_Up) tab?.move(-pageStep, e.modifiers);
        else if (e.key === Qt.Key_Right && state.viewMode === "cuadricula") tab?.move(1, e.modifiers);
        else if (e.key === Qt.Key_Left && state.viewMode === "cuadricula") tab?.move(-1, e.modifiers);
        else if (e.key === Qt.Key_Home) tab?.select(0, e.modifiers & Qt.ShiftModifier);
        else if (e.key === Qt.Key_End) tab?.select((tab?.shown.length ?? 0) - 1, e.modifiers & Qt.ShiftModifier);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) activateSelection();
        else if (ctrl && e.key === Qt.Key_L) editPath();
        else if (e.key === Qt.Key_Slash || (ctrl && e.key === Qt.Key_F)) focusSearch();
        else if (ctrl && e.key === Qt.Key_H) state.showHidden = !state.showHidden;
        else if (ctrl && e.key === Qt.Key_A) tab?.selectAll();
        else if (ctrl && e.key === Qt.Key_T) state.newTab(tab?.path);
        else if (ctrl && e.key === Qt.Key_W) { if (state.tabs.length > 1) state.closeTab(state.currentIndex); else closeRequested(); }
        else if (ctrl && (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)) state.cycleTab(shift || e.key === Qt.Key_Backtab ? -1 : 1);
        else if (ctrl && e.key === Qt.Key_1) state.viewMode = "lista";
        else if (ctrl && e.key === Qt.Key_2) state.viewMode = "cuadricula";
        else if (e.key === Qt.Key_F5 || (ctrl && e.key === Qt.Key_R)) tab?.reload();
        else if (e.key === Qt.Key_Escape) { if (state.search) state.search = ""; else tab?.clearSelection(); }
        else handled = false;
        e.accepted = handled;
    }

    FrameDecor { anchors.fill: parent; radius: root.radius; visible: root.drawFrame; z: 10 }

    Sidebar {
        id: sidebar
        width: Theme.files.sidebarWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        files: root.files
        devices: root.devices
        currentPath: root.tab?.path ?? ""
        onNavigate: p => root.tab?.go(p)
    }

    ColumnLayout {
        id: main
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Theme.files.padding
        anchors.leftMargin: Theme.files.padding + Theme.files.thinGap
        spacing: Theme.files.gap

        // ---- toolbar ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.files.toolbar
            spacing: Theme.files.inset
            FilesButton { round: true; icon: Icons.chevronLeft; enabled: root.tab?.canBack ?? false; onClicked: root.tab.back() }
            FilesButton { round: true; icon: Icons.chevronRight; enabled: root.tab?.canForward ?? false; onClicked: root.tab.forward() }
            FilesButton { round: true; icon: Icons.arrowUp; enabled: root.tab?.canUp ?? false; onClicked: root.tab.up() }
            Rectangle {
                id: crumbBox
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.files.toolbar
                radius: height / 2
                color: Theme.files.input
                border.width: Theme.files.border
                border.color: Theme.files.buttonBorder
                visible: !root.editingPath
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: root.editPath() }
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.files.inset + Theme.files.thinGap
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.files.smallGap
                    clip: true
                    Repeater {
                        model: F.crumbs(root.tab?.path ?? "", root.files?.home ?? "")
                        delegate: Row {
                            required property var modelData
                            required property int index
                            spacing: Theme.files.smallGap
                            UiText { visible: index > 0; text: "›"; color: Theme.textDim; size: Theme.files.body }
                            UiText {
                                readonly property bool last: index === F.crumbs(root.tab?.path ?? "", root.files?.home ?? "").length - 1
                                text: modelData.label
                                size: Theme.files.body
                                weight: last ? Theme.weightSemiBold : Theme.weightRegular
                                color: last ? Theme.text : crumbHit.containsMouse ? Theme.text : Theme.textSoft
                                MouseArea { id: crumbHit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab.go(modelData.path) }
                            }
                        }
                    }
                }
            }
            FilesInput {
                id: pathInput
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.files.toolbar
                visible: root.editingPath
                mono: true
                text: root.editingPath ? F.displayPath(root.tab?.path ?? "", root.files?.home ?? "") : ""
                onAccepted: { const p = F.expandPath(text, root.files?.home ?? "/", root.tab?.path); root.editingPath = false; if (p) root.tab.go(p); root.focusContent(); }
                onEscaped: { root.editingPath = false; root.focusContent(); }
                input.onActiveFocusChanged: if (!input.activeFocus) root.editingPath = false
            }
            FilesInput {
                id: searchInput
                Layout.preferredWidth: Theme.files.searchWidth
                Layout.preferredHeight: Theme.files.toolbar
                icon: Icons.search
                placeholder: "Buscar…"
                hint: "/"
                text: root.state.search
                onTextChanged: root.state.search = text
                onAccepted: { root.focusContent(); if (root.tab?.shown.length) root.tab.select(0, 0); }
                onEscaped: { root.state.search = ""; root.focusContent(); }
                input.Keys.onDownPressed: { root.focusContent(); if (root.tab?.shown.length) root.tab.select(0, 0); }
            }
            Row {
                spacing: Theme.files.thinGap
                FilesButton { icon: Icons.viewList; checked: root.state.viewMode === "lista"; primary: checked; implicitWidth: Theme.files.navButton; implicitHeight: Theme.files.navButton; onClicked: root.state.viewMode = "lista" }
                FilesButton { icon: Icons.viewGrid; checked: root.state.viewMode === "cuadricula"; primary: checked; implicitWidth: Theme.files.navButton; implicitHeight: Theme.files.navButton; onClicked: root.state.viewMode = "cuadricula" }
            }
        }

        // ---- tabs + order caption ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.files.tabsHeight
            spacing: Theme.files.inset
            Repeater {
                model: root.state.tabs
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.state.currentIndex
                    Layout.preferredHeight: Theme.files.tabsHeight
                    Layout.preferredWidth: Math.min(Theme.files.tabMaxWidth, chipRow.implicitWidth + Theme.files.inset * 2)
                    radius: Theme.files.chipRadius
                    color: tabDrop.containsDrag ? Theme.files.dropTarget : current ? Theme.files.selected : Theme.files.button
                    border.width: Theme.files.border
                    border.color: current ? Theme.files.selectedBorder : Theme.files.buttonBorder
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: e => { if (e.button === Qt.MiddleButton) root.state.closeTab(chip.index); else root.state.setCurrent(chip.index); } }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.files.inset
                        UiText { text: chip.modelData.title; size: Theme.files.small; color: chip.current ? Theme.text : Theme.textSoft; width: Math.min(implicitWidth, Theme.files.tabMaxWidth - Theme.files.inset * 4) }
                        UiText {
                            visible: root.state.tabs.length > 1
                            text: "×"; size: Theme.files.small; color: closeHit.containsMouse ? Theme.text : Theme.textDim
                            MouseArea { id: closeHit; anchors.fill: parent; anchors.margins: -Theme.files.thinGap; hoverEnabled: true; onClicked: root.state.closeTab(chip.index) }
                        }
                    }
                    DropArea {
                        id: tabDrop
                        anchors.fill: parent
                        keys: ["dragon-files"]
                        onEntered: root.state.setCurrent(chip.index)
                    }
                }
            }
            FilesButton { implicitWidth: Theme.files.tabsHeight; implicitHeight: Theme.files.tabsHeight; label: "+"; onClicked: root.state.newTab(root.tab?.path) }
            Item { Layout.fillWidth: true }
            UiText {
                text: root.state.sortCaption
                mono: true
                size: Theme.files.caption
                font.letterSpacing: Theme.files.captionTracking / 2
                color: Theme.textDim
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => { if (e.button === Qt.RightButton) root.state.showHidden = !root.state.showHidden; else root.state.cycleSort(); } }
            }
        }

        // ---- content ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.files.gap
            Item {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
                FileList {
                    id: list
                    anchors.fill: parent
                    visible: root.state.viewMode === "lista" && root.tab?.status === "ok" && !root.tab?.isNet && (root.tab?.shown.length ?? 0) > 0
                    tab: root.tab
                    view: root.state
                    now: root.now
                    onActivated: e => root.activate(e)
                }
                FileGrid {
                    id: grid
                    anchors.fill: parent
                    visible: root.state.viewMode === "cuadricula" && root.tab?.status === "ok" && !root.tab?.isNet && (root.tab?.shown.length ?? 0) > 0
                    tab: root.tab
                    files: root.files
                    onActivated: e => root.activate(e)
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.files.padding * 4
                    spacing: Theme.files.smallGap
                    visible: !list.visible && !grid.visible && !(root.tab?.isNet ?? false)
                    UiText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        size: Theme.files.title
                        color: root.tab?.status === "error" ? Theme.danger : Theme.textDim
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        text: root.tab?.status === "loading" ? "Leyendo la carpeta…"
                            : root.tab?.status === "error" ? root.tab.error
                            : root.state.search ? "Nada coincide con «" + root.state.search + "»"
                            : "Carpeta vacía"
                    }
                    UiText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: text.length > 0
                        size: Theme.files.small
                        color: Theme.textDim
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        text: root.tab?.status === "error" ? (root.tab.errorHint || "") : ""
                    }
                }
            }
        }

        // ---- status bar ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.files.statusHeight
            spacing: Theme.files.gap
            UiText {
                Layout.fillWidth: true
                mono: true
                size: Theme.files.mono
                color: Theme.textSoft
                text: root.tab ? F.selectionSummary(root.tab.selection, root.tab.shown.length) : ""
            }
            UiText {
                visible: (root.tab?.total ?? -1) > 0
                mono: true
                size: Theme.files.mono
                color: Theme.textSoft
                text: visible ? (F.formatSize(root.tab.free) + " libres de " + F.formatSize(root.tab.total)).toUpperCase() : ""
            }
        }
    }
}
