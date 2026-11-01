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
    // ---- operations (d2): the view only asks; FileOps runs ----
    function pasteInto(dir): void {
        const cb = files?.clipboard;
        if (!ops || !cb?.paths?.length || !dir) return;
        if (cb.mode === "cut") { ops.move(cb.paths, dir); files.setClipboard("", []); }
        else ops.copy(cb.paths, dir);
    }
    // Drop rule: Ctrl copies, Shift moves; otherwise move on the same device and copy across devices (like most
    // file managers). Dropping on the trash trashes. Dropping where the files already are does nothing.
    function dropInto(dir, paths, mods): void {
        if (!ops || !paths?.length || !dir) return;
        if (dir.indexOf("trash:") === 0) { ops.trash(paths); return; }
        const moving = paths.filter(p => F.parent(p) !== dir && p !== dir && dir.indexOf(p + "/") !== 0);
        if (!moving.length) return;
        if (moving.length === 1 && archives && F.isArchive({ name: F.basename(moving[0]), kind: "file" }) && !(mods & (Qt.ControlModifier | Qt.ShiftModifier))) {
            dropMenu.dir = dir; dropMenu.paths = moving;
            menu.popup(lastPointer.x, lastPointer.y, [
                { label: "Mover aquí", action: "drop:move", icon: Icons.arrowRight },
                { label: "Copiar aquí", action: "drop:copy", icon: Icons.copy },
                { label: "Extraer aquí", action: "drop:extract", icon: Icons.fileArchive }]);
            return;
        }
        const copy = (mods & Qt.ControlModifier) || (!(mods & Qt.ShiftModifier) && !F.sameDevice(devices?.devices ?? [], moving[0], dir));
        if (copy) ops.copy(moving, dir); else ops.move(moving, dir);
    }
    QtObject { id: dropMenu; property string dir: ""; property var paths: [] }
    property point lastPointer: Qt.point(width / 2, height / 2)
    function askRename(): void {
        const e = tab?.focusEntry;
        if (!e) return;
        prompt.purpose = "rename"; prompt.target = tab.pathOf(e);
        prompt.ask({ title: "Renombrar", value: e.name, selectStem: e.kind !== "dir", buttons: [{ label: "Cancelar", action: "cancel" }, { label: "Renombrar", action: "ok", primary: true }] });
    }
    function askMkdir(): void {
        if (!tab || tab.special) return;
        prompt.purpose = "mkdir"; prompt.target = tab.path;
        prompt.ask({ title: "Nueva carpeta", value: "", placeholder: "Nombre de la carpeta", buttons: [{ label: "Cancelar", action: "cancel" }, { label: "Crear", action: "ok", primary: true }] });
    }
    function askDelete(): void {
        const paths = tab?.selectedPaths() ?? [];
        if (!paths.length) return;
        prompt.purpose = "delete"; prompt.targets = paths;
        prompt.ask({ title: "Eliminar para siempre", input: false, danger: true,
                     message: (paths.length === 1 ? "«" + F.basename(paths[0]) + "»" : paths.length + " elementos") + " se borrarán sin pasar por la papelera. No se puede deshacer.",
                     buttons: [{ label: "Cancelar", action: "cancel" }, { label: "Eliminar", action: "ok", danger: true, primary: true }] });
    }
    function askConflict(op): void {
        if (!op?.conflict) return;
        prompt.purpose = "conflict"; prompt.opId = op.id;
        prompt.ask({ title: "Ya existe un archivo", input: false, check: "Hacer lo mismo con los demás",
                     message: "«" + F.basename(op.conflict.file) + "» ya está en " + F.displayPath(F.parent(op.conflict.dest || op.dest), files?.home ?? "") + ".",
                     buttons: [{ label: "Omitir", action: "skip" }, { label: "Renombrar", action: "rename" }, { label: "Reemplazar", action: "overwrite", primary: true }] });
    }
    function trashSelection(): void { const p = tab?.selectedPaths() ?? []; if (p.length && ops) ops.trash(p); }
    function contextMenuFor(entry, x, y): void {
        lastPointer = Qt.point(x, y);
        const sel = tab?.selectedPaths() ?? [];
        const one = entry && sel.length <= 1;
        const isArch = one && F.isArchive(entry);
        const items = [];
        if (entry) {
            items.push({ label: "Abrir", action: "open", hint: "↵", icon: Icons.folderOutline });
            if (one && entry.kind !== "dir") items.push({ label: "Abrir con…", action: "openWith", icon: Icons.apps });
            if (isArch && archives) { items.push({ separator: true }); items.push({ label: "Extraer aquí", action: "extractHere", icon: Icons.fileArchive }); items.push({ label: "Extraer en…", action: "extractTo" }); }
            if (archives) items.push({ label: "Comprimir…", action: "compress", icon: Icons.fileArchive });
            items.push({ separator: true });
            items.push({ label: "Copiar", action: "copy", hint: "Ctrl+C", icon: Icons.copy });
            items.push({ label: "Cortar", action: "cut", hint: "Ctrl+X" });
            items.push({ label: "Renombrar…", action: "rename", hint: "F2", icon: Icons.pencil, enabled: one });
            items.push({ separator: true });
            items.push({ label: "Mover a la papelera", action: "trash", hint: "Supr", icon: Icons.trash });
            items.push({ label: "Eliminar…", action: "delete", hint: "Mayús+Supr", danger: true });
            items.push({ separator: true });
            if (one && entry.kind === "dir") items.push({ label: "Compartir en la red…", action: "share", icon: Icons.share, enabled: !!shareEnabled });
            items.push({ label: "Enviar al agente", action: "agent", icon: Icons.robot, enabled: files?.composerAvailable ?? false });
        } else {
            items.push({ label: "Nueva carpeta…", action: "mkdir", hint: "Ctrl+Mayús+N", icon: Icons.plus, enabled: !tab?.special });
            items.push({ label: "Pegar", action: "paste", hint: "Ctrl+V", enabled: (files?.clipboard?.paths?.length ?? 0) > 0 });
            if (ops?.canUndo) items.push({ label: ops.undoLabel, action: "undo", hint: "Ctrl+Z" });
            items.push({ separator: true });
            items.push({ label: "Terminal aquí", action: "terminal", icon: Icons.terminal, enabled: !tab?.special });
            items.push({ label: "Compartir esta carpeta…", action: "shareHere", icon: Icons.share, enabled: !!shareEnabled && !tab?.special });
            items.push({ label: state.showHidden ? "Ocultar archivos ocultos" : "Mostrar archivos ocultos", action: "hidden", hint: "Ctrl+H" });
        }
        menu.popup(x, y, items);
    }
    property bool shareEnabled: false
    function openWithMenu(entry): void {
        const p = tab.pathOf(entry);
        files?.openWithList(p, r => {
            const apps = r.ok ? (r.apps ?? []) : [];
            openWithTarget = p;
            menu.popup(lastPointer.x, lastPointer.y, apps.length ? apps.map(a => ({ label: a.name, action: "with:" + a.id, hint: a.default ? "predet." : "" }))
                                                               : [{ label: "No hay aplicaciones para este tipo", action: "", enabled: false }]);
        });
    }
    property string openWithTarget: ""
    function runAction(action, entry): void {
        const paths = tab?.selectedPaths() ?? [];
        switch (action) {
        case "open": if (entry) { if (paths.length > 1) activateSelection(); else activate(entry); } break;
        case "openWith": if (entry) openWithMenu(entry); break;
        case "copy": files?.setClipboard("copy", paths); break;
        case "cut": files?.setClipboard("cut", paths); break;
        case "paste": pasteInto(tab?.path); break;
        case "rename": askRename(); break;
        case "mkdir": askMkdir(); break;
        case "trash": trashSelection(); break;
        case "delete": askDelete(); break;
        case "undo": ops?.undo(); break;
        case "terminal": files?.terminalHere(entry && entry.kind === "dir" ? tab.pathOf(entry) : tab.path); break;
        case "agent": files?.sendToAgent(paths.length ? paths : [tab.path]); break;
        case "hidden": state.showHidden = !state.showHidden; break;
        case "drop:move": ops?.move(dropMenu.paths, dropMenu.dir); break;
        case "drop:copy": ops?.copy(dropMenu.paths, dropMenu.dir); break;
        default:
            if (action.indexOf("with:") === 0) files?.openWith(openWithTarget, action.slice(5));
            else extraAction(action, entry, paths);
        }
    }
    // archives (d4); sharing extends this in d6
    function extraAction(action, entry, paths): void {
        const p = entry && tab ? tab.pathOf(entry) : "";
        if (action === "extractHere" && p) extractHere(p);
        else if (action === "extractTo" && p) extractDialog.open(p, "", "");
        else if (action === "test" && p) archives?.test(p);
        else if (action === "drop:extract") extractDialog.open(dropMenu.paths[0], F.join(dropMenu.dir, F.archiveStem(F.basename(dropMenu.paths[0]))) + "/", "");
        else if (action === "compress") askCompress(paths);
        else extraAction2(action, entry, paths);
    }
    function extraAction2(action, entry, paths): void {}
    function extractHere(p): void {
        if (!archives) return;
        if (archives.cache[p]?.encrypted) { extractDialog.open(p, "", "password_required"); return; }
        archives.extract(p, F.parent(p), { ownFolder: true, conflict: "ask" }, r => {
            const code = r.error?.code ?? "";
            if (["password_required", "bad_password", "bomb_suspected"].indexOf(code) >= 0) { ops?.dismissError(); extractDialog.open(p, "", code); }
        });
    }
    function askCompress(paths): void {
        if (!paths.length || !tab || tab.special) return;
        prompt.purpose = "compress"; prompt.targets = paths;
        const base = paths.length === 1 ? F.archiveStem(F.basename(paths[0])) : F.basename(tab.path);
        prompt.ask({ title: "Comprimir " + (paths.length === 1 ? "«" + F.basename(paths[0]) + "»" : paths.length + " elementos"), value: base,
                     placeholder: "Nombre del archivo", message: "Se crea en esta carpeta. Elige el formato:",
                     buttons: [{ label: "Cancelar", action: "cancel" }, { label: "ZIP", action: "zip" }, { label: "7Z", action: "7z" }, { label: "TAR.ZST", action: "tar.zst", primary: true }] });
    }
    // ---- devices (d3) ----
    function deviceAction(d, action): void {
        if (!devices || !d) return;
        if (action === "eject") {
            // leave the device first so its folder is not kept busy by this window
            for (const t of state.tabs) if (d.mountpoint && (t.path === d.mountpoint || t.path.indexOf(d.mountpoint + "/") === 0)) t.go(files?.home ?? "/");
            if (d.removable || d.kind === "mtp") devices.eject(d.id); else devices.unmount(d.id);
        } else if (action === "unlock") {
            prompt.purpose = "unlock"; prompt.target = d.id;
            const err = devices.errors?.[d.id] ?? "";
            prompt.ask({ title: "Abrir volumen cifrado", password: true, placeholder: "Contraseña", danger: !!err,
                         message: err ? err + ". Vuelve a intentarlo." : "«" + d.label + "» está cifrado. La contraseña se pasa por la entrada estándar y no se guarda.",
                         buttons: [{ label: "Cancelar", action: "cancel" }, { label: "Abrir", action: "ok", primary: true }] });
        } else if (d.mounted && d.mountpoint) tab?.go(d.mountpoint);
        else devices.mount(d.id, r => { if (r.ok) tab?.go(r.mountpoint ?? devices.deviceById(d.id)?.mountpoint ?? ""); });
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
        else if (ctrl && shift && e.key === Qt.Key_N) askMkdir();
        else if (ctrl && e.key === Qt.Key_C) runAction("copy", tab?.focusEntry);
        else if (ctrl && e.key === Qt.Key_X) runAction("cut", tab?.focusEntry);
        else if (ctrl && e.key === Qt.Key_V) pasteInto(tab?.path);
        else if (ctrl && e.key === Qt.Key_Z) ops?.undo();
        else if (e.key === Qt.Key_F2) askRename();
        else if (e.key === Qt.Key_Delete && shift) askDelete();
        else if (e.key === Qt.Key_Delete) trashSelection();
        else if (e.key === Qt.Key_Menu || (shift && e.key === Qt.Key_F10)) contextMenuFor(tab?.focusEntry, content.x + main.x + content.width / 3, content.y + main.y + content.height / 3);
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
        onDropOn: (path, paths, mods) => root.dropInto(path, paths, mods)
        onDeviceAction: (d, a) => root.deviceAction(d, a)
        onNetAction: (item, a) => { if (a === "connect") netView.connectTo(item.uri); }
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
                    onContextMenu: (e, x, y) => { const p = mapToItem(root, x, y); root.contextMenuFor(e, p.x, p.y); }
                    onDropOn: (path, paths, mods) => root.dropInto(path, paths, mods)
                }
                FileGrid {
                    id: grid
                    anchors.fill: parent
                    visible: root.state.viewMode === "cuadricula" && root.tab?.status === "ok" && !root.tab?.isNet && (root.tab?.shown.length ?? 0) > 0
                    tab: root.tab
                    files: root.files
                    onActivated: e => root.activate(e)
                    onContextMenu: (e, x, y) => { const p = mapToItem(root, x, y); root.contextMenuFor(e, p.x, p.y); }
                    onDropOn: (path, paths, mods) => root.dropInto(path, paths, mods)
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
                NetView {
                    id: netView
                    anchors.fill: parent
                    visible: root.tab?.isNet ?? false
                    active: visible && root.active
                    devices: root.devices
                    files: root.files
                    onNavigate: p => root.tab?.go(p)
                }
                // drop on the empty part of the folder = into the folder itself
                DropArea {
                    anchors.fill: parent
                    z: -1
                    keys: ["dragon-files"]
                    onDropped: d => { root.lastPointer = mapToItem(root, d.x, d.y); root.dropInto(root.tab?.path, d.source?.dragPaths ?? [], d.source?.dragModifiers ?? 0); d.accept(); }
                }
            }
            Preview {
                id: preview
                Layout.preferredWidth: Theme.files.previewWidth
                Layout.fillHeight: true
                visible: !(root.tab?.isNet ?? false) && root.width >= Theme.files.previewMinWindow
                tab: root.tab
                files: root.files
                archives: root.archives
                now: root.now
                onAction: (name, entry) => root.runAction(name, entry)
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
                text: root.tab?.isNet ? netView.hosts.length + (netView.hosts.length === 1 ? " equipo · " : " equipos · ") + netView.connectedCount + (netView.connectedCount === 1 ? " conectado" : " conectados")
                    : root.tab ? F.selectionSummary(root.tab.selection, root.tab.shown.length) : ""
            }
            OpsBar {
                ops: root.ops
                devices: root.devices
                onConflictRequested: op => root.askConflict(op)
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

    FilesMenu {
        id: menu
        z: 20
        onPicked: a => root.runAction(a, root.tab?.focusEntry)
        onVisibleChanged: if (!visible) root.focusContent()
    }
    ExtractDialog {
        id: extractDialog
        z: 25
        archives: root.archives
        ops: root.ops
        home: root.files?.home ?? ""
        free: root.tab?.free ?? -1
        onClosed: root.focusContent()
    }
    FilesPrompt {
        id: prompt
        z: 30
        onVisibleChanged: if (visible) menu.close()
        property string purpose: ""
        property string target: ""
        property var targets: []
        property int opId: -1
        onAnswered: (action, value, checked) => {
            const name = value.trim();
            if (purpose === "rename" && action === "ok" && name && name !== F.basename(target) && name.indexOf("/") < 0) root.ops?.rename(target, name);
            else if (purpose === "mkdir" && action === "ok" && name && name.indexOf("/") < 0) root.ops?.mkdir(target, name);
            else if (purpose === "delete" && action === "ok") root.ops?.remove(targets);
            else if (purpose === "conflict" && action !== "cancel") root.ops?.answer(opId, action, checked);
            else if (purpose === "compress" && action !== "cancel" && name && name.indexOf("/") < 0) root.archives?.create(action, F.join(root.tab.path, name + "." + action), targets);
            else if (purpose === "unlock" && action === "ok" && value) {
                const id = target;
                root.devices?.unlock(id, value, r => {
                    if (r.ok) { const d = root.devices.deviceById(id); if (r.mountpoint || d?.mountpoint) root.tab?.go(r.mountpoint ?? d.mountpoint); }
                    else root.deviceAction(root.devices.deviceById(id) ?? { id: id, label: id }, "unlock");
                });
            }
            root.focusContent();
        }
    }
    // a conflict question pops up by itself for the window that is in front
    Connections {
        target: root.ops
        ignoreUnknownSignals: true
        function onActiveChanged() { if (root.active && root.ops.active?.state === "conflict" && !prompt.visible) root.askConflict(root.ops.active); }
        // reload at once the folders an operation touched (the watcher may be polling once a second)
        function onFinished(op) {
            const dirs = [op.dest, F.parent(op.dest ?? "")].concat((op.sources ?? []).map(p => F.parent(p)));
            for (const t of root.state.tabs) if (dirs.indexOf(t.path) >= 0) t.reload();
        }
    }
}
