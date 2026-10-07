// =============================================================================
// dragon-island — StorePanel.qml (SUPER + I): the "Tienda" for pacman + AUR
// Tabs Buscar · Instalados · Actualizaciones · Limpieza. Left: list (search on top, keyboard navigation);
// right: details of the focused package. Installing / removing runs in a floating Ghostty (bin/dragon-pkg), never
// in Quickshell: no passwords here. Data and actions: services/Store.qml.
// Keyboard: type to search · ↑↓ move · Tab (or Space on an empty field) marks · Enter acts · Esc closes.
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
    property string tab: "search"          // "search" | "installed" | "updates" | "clean"
    property int current: 0
    property string overlay: ""            // "" | "pkgbuild" | "confirm"
    property var confirm: ({ kind: "", title: "", names: [] })
    property bool criticalAck: false

    function focusSearch(): void { search.focusInput(); }

    // ---- what the list shows ----
    readonly property string filter: search.text.trim().toLowerCase()
    readonly property var items: {
        if (!root.shown) return [];
        switch (root.tab) {
            case "search":    return Store.results;
            case "installed": return Store.installed.filter(p => root.filter.length === 0 || p.name.toLowerCase().includes(root.filter));
            case "updates":   return Store.updates.filter(u => root.filter.length === 0 || u.name.toLowerCase().includes(root.filter));
            default:          return Store.orphans.map(n => ({ name: n }));
        }
    }
    readonly property var focused: items[current] ?? null
    readonly property bool hasSelection: Store.selectedCount > 0
    // what Enter / the main button acts on: the marked packages, else the focused one
    readonly property var targets: {
        if (root.hasSelection) return Object.keys(Store.selected).map(n => ({ name: n, repo: Store.selected[n].repo }));
        if (root.focused && (root.tab === "search" || root.tab === "installed")) return [{ name: root.focused.name, repo: root.focused.repo ?? (root.focused.aur ? "aur" : "official") }];
        return [];
    }

    function itemRepo(it): string { return it.repo ?? (it.aur ? "aur" : "official"); }

    onTabChanged: {
        current = 0;
        overlay = "";
        Store.clearSelection();
        if (tab === "installed") Store.loadInstalled();
        else if (tab === "updates") Store.loadUpdates();
        else if (tab === "clean") Store.loadClean();
        else Store.search(search.text);
        detailTimer.restart();
    }
    onCurrentChanged: detailTimer.restart()
    onItemsChanged: { if (current >= items.length) current = Math.max(0, items.length - 1); detailTimer.restart(); }

    onShownChanged: {
        if (shown) {
            overlay = "";
            tab = "search";
            Store.clearSelection();
            search.text = Store.pendingQuery;       // "+name" from the orbital launcher
            Store.pendingQuery = "";
            Store.refreshLists();
            if (search.text.length > 0) Store.search(search.text);
            current = 0;
        }
    }

    // search: debounce 200 ms; details of the focused package: 300 ms after it stops moving, in the background
    Timer { id: searchTimer; interval: 200; onTriggered: if (root.tab === "search") Store.search(search.text) }
    Timer {
        id: detailTimer
        interval: 300
        onTriggered: {
            const it = root.focused;
            if (!it || root.tab === "clean") return;
            if (root.tab === "search") Store.loadInfo(it);
            else Store.loadInstalledInfo(it.name);
        }
    }

    function move(d: int): void {
        if (items.length === 0) return;
        current = Math.max(0, Math.min(items.length - 1, current + d));
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function toggleCurrent(): void {
        if (!focused || (tab !== "search" && tab !== "installed")) return;
        Store.toggleSelect({ name: focused.name, repo: itemRepo(focused) });
        move(1);
    }

    // ---- actions ----
    function act(): void {
        if (overlay.length > 0) return;
        if (tab === "search") { if (targets.length > 0) Store.install(targets); }
        else if (tab === "installed") askRemove(targets.map(t => t.name));
        else if (tab === "updates") Store.updateAll();
    }

    function askRemove(names: var): void {
        if (names.length === 0) return;
        confirm = { kind: "remove", title: names.length === 1 ? `Eliminar ${names[0]}` : `Eliminar ${names.length} paquetes`, names: names };
        criticalAck = false;
        Store.previewRemoval(names);
        overlay = "confirm";
    }
    function askClean(kind: string): void {
        if (kind === "orphans") confirm = { kind: "orphans", title: `Eliminar ${Store.orphans.length} huérfanos`, names: Store.orphans };
        else confirm = { kind: "cache", title: "Limpiar la caché de paquetes", names: [] };
        criticalAck = false;
        overlay = "confirm";
    }
    readonly property var criticalHit: (root.confirm.kind === "orphans" ? Store.orphans : (Store.removePreview.ok.length > 0 ? Store.removePreview.ok : root.confirm.names)).filter(n => Store.isCritical(n))
    function doConfirm(): void {
        if (confirm.kind === "remove") Store.remove(confirm.names);
        else if (confirm.kind === "orphans") Store.clean("orphans");
        else if (confirm.kind === "cache") Store.clean("cache");
        overlay = "";
    }

    function showPkgbuild(name: string): void {
        Store.loadPkgbuild(name);
        overlay = "pkgbuild";
    }

    // ---- pieces ----
    component TextButton: Rectangle {
        id: btn
        property string label: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        implicitHeight: Theme.touchTarget - 6
        implicitWidth: row.implicitWidth + Theme.spacingMd * 2
        radius: Theme.rowRadius
        opacity: enabled ? 1 : 0.4
        color: danger ? Theme.alpha(Theme.error, btnMouse.containsMouse ? 0.45 : 0.3) : (btnMouse.containsMouse ? Theme.surfaceHi : Theme.surface2)
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
        BrandFill { anchors.fill: parent; radius: parent.radius; visible: btn.primary }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Theme.spacingSm
            Glyph { visible: btn.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; icon: btn.icon; size: Theme.iconMd; color: btn.primary ? Theme.onBrand : Theme.textSoft }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: btn.label; weight: Theme.weightMedium; color: btn.primary ? Theme.onBrand : Theme.text }
        }
        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; enabled: btn.enabled; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    component Badge: Rectangle {
        property string text: ""
        property color tone: Theme.textDim
        implicitHeight: 17
        implicitWidth: badgeText.implicitWidth + Theme.spacingSm * 2
        radius: height / 2
        color: Theme.alpha(tone, 0.2)
        UiText { id: badgeText; anchors.centerIn: parent; text: parent.text; size: Theme.sizeCaption - 1; weight: Theme.weightSemiBold; color: parent.tone }
    }

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Tienda"
        popWidth: Math.min(Theme.storeWidth, root.width - Theme.barMarginSide * 2)
        originX: width / 2
        x: (root.width - width) / 2
        y: Math.max(Theme.barMarginTop + Theme.barHeight + Theme.popoverGap, (root.height - height) / 2)

        headerRight: UiText {
            text: Store.selectedCount > 0 ? `${Store.selectedCount} seleccionados` : (Store.helper.length > 0 ? `pacman + ${Store.helper}` : "pacman")
            size: Theme.sizeCaption + 1
            color: Store.selectedCount > 0 ? Theme.accent : Theme.textDim
        }

        // ---- tabs + search ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Segmented {
                Layout.preferredWidth: 440
                Layout.fillWidth: false
                implicitHeight: Theme.touchTarget
                model: [{ key: "search", label: "Buscar" }, { key: "installed", label: "Instalados" },
                        { key: "updates", label: Updates.count > 0 ? `Actualizaciones (${Updates.count})` : "Actualizaciones" }, { key: "clean", label: "Limpieza" }]
                current: root.tab
                onSelected: key => root.tab = key
            }

            InputField {
                id: search
                Layout.fillWidth: true
                icon: Icons.search
                placeholder: root.tab === "search" ? "Buscar en repos y AUR…" : "Filtrar…"
                selectKeys: true
                onTextChanged: { if (root.tab === "search") searchTimer.restart(); root.current = 0; }
                onNavigate: d => root.move(d)
                onToggleRequested: root.toggleCurrent()
                onAccepted: root.act()
                onEscapePressed: { if (root.overlay.length > 0) root.overlay = ""; else ShellState.close(); }
            }
        }

        // ---- body ----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.storeBodyHeight

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingMd

                // ---- list ----
                Item {
                    Layout.preferredWidth: Theme.storeListWidth
                    Layout.fillHeight: true

                    UiText {
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingLg
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        visible: root.items.length === 0
                        color: Theme.textDim
                        text: {
                            if (root.tab === "search") return Store.searching ? "Buscando…" : (search.text.trim().length === 0 ? "Escribe para buscar en los repositorios oficiales y en el AUR" : `Sin resultados para «${search.text}»`);
                            if (root.tab === "installed") return "Sin paquetes";
                            if (root.tab === "updates") return Store.updatesLoading ? "Comprobando actualizaciones…" : "Todo al día";
                            return "No hay huérfanos";
                        }
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: root.items.length > 0
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.current
                        model: ScriptModel { values: root.items; objectProp: "name" }

                        delegate: Rectangle {
                            id: rowItem
                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: index === root.current
                            readonly property bool marked: Store.isSelected(modelData.name)
                            width: ListView.view.width
                            height: 38
                            radius: Theme.rowRadius - 2
                            color: isCurrent ? Theme.surfaceHi : (rowMouse.containsMouse ? Theme.surface2 : Theme.transparent)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingSm
                                anchors.rightMargin: Theme.spacingSm
                                spacing: Theme.spacingSm

                                // checkbox (search / installed)
                                Rectangle {
                                    visible: root.tab === "search" || root.tab === "installed"
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    radius: 5
                                    color: rowItem.marked ? Theme.accent : Theme.transparent
                                    border.width: 1.5
                                    border.color: rowItem.marked ? Theme.accent : Theme.muted
                                    Glyph { anchors.centerIn: parent; visible: rowItem.marked; icon: Icons.check; size: 11; color: Theme.onBrand }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Store.toggleSelect({ name: rowItem.modelData.name, repo: root.itemRepo(rowItem.modelData) })
                                    }
                                }

                                UiText {
                                    Layout.fillWidth: true
                                    text: rowItem.modelData.name
                                    weight: Theme.weightMedium
                                }

                                // updates: old → new
                                UiText {
                                    visible: root.tab === "updates"
                                    text: `${rowItem.modelData.old} → ${rowItem.modelData.new}`
                                    mono: true
                                    size: Theme.sizeCaption
                                    color: Theme.textDim
                                    Layout.maximumWidth: 150
                                }
                                UiText {
                                    visible: root.tab === "search" && (rowItem.modelData.version ?? "").length > 0
                                    text: rowItem.modelData.version ?? ""
                                    mono: true
                                    size: Theme.sizeCaption
                                    color: Theme.textDim
                                    Layout.maximumWidth: 80
                                }
                                Badge { visible: root.tab === "search" && rowItem.modelData.installed === true; text: "Instalado"; tone: Theme.ok }
                                Badge {
                                    visible: (root.tab === "search" || root.tab === "updates") && (rowItem.modelData.repo ?? "") !== ""
                                    text: (rowItem.modelData.repo === "aur") ? "AUR" : "Oficial"
                                    tone: (rowItem.modelData.repo === "aur") ? Theme.warn : Theme.cyan
                                }
                                Badge { visible: root.tab === "installed" && rowItem.modelData.aur === true; text: "AUR"; tone: Theme.warn }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                anchors.leftMargin: 32
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.current = rowItem.index
                                onDoubleClicked: { root.current = rowItem.index; root.act(); }
                            }
                        }
                    }
                }

                // ---- details ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.cardRadius - 4
                    color: Theme.alpha(Theme.surface1, 0.55)

                    Flickable {
                        id: detailFlick
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        clip: true
                        contentHeight: detailCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: detailCol
                            width: detailFlick.width
                            spacing: Theme.spacingSm

                            // ---- search / installed: package details ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: (root.tab === "search" || root.tab === "installed") && root.focused !== null
                                spacing: Theme.spacingSm

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm
                                    UiText {
                                        Layout.fillWidth: true
                                        text: root.focused?.name ?? ""
                                        size: Theme.sizeTitle
                                        weight: Theme.weightSemiBold
                                    }
                                    Badge { visible: root.focused && root.itemRepo(root.focused) === "aur"; text: "AUR"; tone: Theme.warn }
                                }

                                // AUR: out of date / orphan, highlighted
                                UiText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    color: Theme.warn
                                    weight: Theme.weightSemiBold
                                    text: {
                                        const d = Store.details;
                                        const out = [];
                                        if (d["Out-of-date"] && d["Out-of-date"] !== "No") out.push(`Desactualizado (${d["Out-of-date"]})`);
                                        if (d["Maintainer"] === "None") out.push("Huérfano: sin mantenedor");
                                        return out.join(" · ");
                                    }
                                }

                                Repeater {
                                    model: {
                                        const labels = [["Description", "Descripción"], ["Version", "Versión"], ["Repository", "Repositorio"],
                                                        ["Download Size", "Descarga"], ["Installed Size", "Instalado"], ["Install Date", "Instalado el"],
                                                        ["Licenses", "Licencia"], ["URL", "URL"], ["Depends On", "Dependencias"],
                                                        ["Votes", "Votos"], ["Popularity", "Popularidad"], ["Maintainer", "Mantenedor"], ["Last Modified", "Modificado"]];
                                        return labels.filter(l => (Store.details[l[0]] ?? "").length > 0 && Store.details[l[0]] !== "None").map(l => ({ label: l[1], value: Store.details[l[0]] }));
                                    }
                                    delegate: ColumnLayout {
                                        id: kv
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 0
                                        UiText { caption: true; text: kv.modelData.label }
                                        UiText {
                                            Layout.fillWidth: true
                                            text: kv.modelData.value
                                            wrapMode: Text.Wrap
                                            maximumLineCount: kv.modelData.label === "Descripción" ? 4 : 3
                                            size: Theme.sizeBody
                                            color: Theme.textSoft
                                        }
                                    }
                                }

                                UiText {
                                    visible: Store.detailsLoading
                                    text: "Cargando detalles…"
                                    color: Theme.textDim
                                    size: Theme.sizeCaption + 1
                                }

                                UiText {
                                    visible: root.focused && root.itemRepo(root.focused) === "aur"
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    text: "Paquete de la comunidad: revisa el PKGBUILD antes de instalar."
                                    size: Theme.sizeCaption + 1
                                    color: Theme.warn
                                }
                            }

                            // ---- updates ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "updates"
                                spacing: Theme.spacingSm
                                UiText { text: "Actualizaciones"; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
                                UiText { Layout.fillWidth: true; text: `${Updates.repoCount} oficiales · ${Updates.aurCount} del AUR`; color: Theme.textSoft }
                                UiText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 6
                                    text: "«Actualizar todo» abre una terminal con " + (Store.helper.length > 0 ? `${Store.helper} -Syu` : "sudo pacman -Syu") + ": siempre el sistema completo, nunca actualizaciones parciales."
                                    color: Theme.textDim
                                    size: Theme.sizeCaption + 1
                                }
                            }

                            // ---- cleanup ----
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "clean"
                                spacing: Theme.spacingMd
                                UiText { text: "Limpieza"; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXs
                                    UiText { caption: true; text: "Huérfanos" }
                                    UiText { Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 3; color: Theme.textSoft; text: `${Store.orphans.length} paquetes instalados como dependencia que ya nadie necesita (pacman -Qdtq).` }
                                    TextButton { danger: true; enabled: Store.orphans.length > 0; label: "Eliminar huérfanos"; onClicked: root.askClean("orphans") }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXs
                                    UiText { caption: true; text: "Caché de paquetes" }
                                    UiText { Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 3; color: Theme.textSoft; text: `${Store.cacheSize || "…"} en /var/cache/pacman/pkg · ${Store.cacheOld} versiones viejas que paccache borraría (se conservan las 3 últimas).` }
                                    TextButton { label: "Limpiar caché"; onClicked: root.askClean("cache") }
                                }
                            }
                        }
                    }
                }
            }

            // ---- PKGBUILD viewer ----
            Rectangle {
                anchors.fill: parent
                visible: root.overlay === "pkgbuild"
                radius: Theme.cardRadius - 4
                color: Theme.alpha(Theme.island, 0.98)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm
                    RowLayout {
                        Layout.fillWidth: true
                        UiText { Layout.fillWidth: true; text: `PKGBUILD · ${Store.pkgbuildFor}`; weight: Theme.weightSemiBold; size: Theme.sizeBodyLg }
                        TextButton { label: "Cerrar"; onClicked: root.overlay = "" }
                    }
                    UiText { Layout.fillWidth: true; text: "Paquete de la comunidad: revisa lo que ejecuta antes de instalarlo."; color: Theme.warn; size: Theme.sizeCaption + 1 }
                    Flickable {
                        id: pkgFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: pkgText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        TextEdit {
                            id: pkgText
                            width: pkgFlick.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            text: Store.pkgbuildLoading ? "Descargando el PKGBUILD…" : (Store.pkgbuild.length > 0 ? Store.pkgbuild : "(vacío)")
                            color: Theme.textSoft
                            selectionColor: Theme.alpha(Theme.accent, 0.5)
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // ---- confirmation (remove / orphans / cache) ----
            Rectangle {
                anchors.fill: parent
                visible: root.overlay === "confirm"
                radius: Theme.cardRadius - 4
                color: Theme.alpha(Theme.island, 0.98)
                border.width: 1
                border.color: Theme.alpha(Theme.error, 0.6)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    UiText { Layout.fillWidth: true; text: root.confirm.title; size: Theme.sizeTitle; weight: Theme.weightSemiBold; color: Theme.error }

                    UiText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        color: Theme.textSoft
                        text: root.confirm.kind === "cache"
                            ? "Se borrarán las versiones viejas de los paquetes en caché (paccache -r), conservando las 3 últimas de cada uno."
                            : (Store.previewing ? "Calculando qué dependencias se irán también…" : "Estos paquetes se eliminarán, con sus dependencias que nadie más necesita (pacman -Rns):")
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: root.confirm.kind !== "cache"
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.confirm.kind === "orphans" ? Store.orphans : (Store.removePreview.ok.length > 0 ? Store.removePreview.ok : root.confirm.names)
                        delegate: UiText {
                            required property string modelData
                            width: ListView.view.width
                            text: `${root.confirm.names.indexOf(modelData) >= 0 || root.confirm.kind === "orphans" ? "•" : "↳"} ${modelData}${root.confirm.names.indexOf(modelData) < 0 && root.confirm.kind === "remove" ? "  (dependencia)" : ""}`
                            color: Store.isCritical(modelData) ? Theme.error : Theme.text
                            mono: true
                            size: Theme.sizeCaption + 1
                        }
                    }
                    Item { visible: root.confirm.kind === "cache"; Layout.fillHeight: true }

                    // pacman refuses: a package still needs one of them
                    UiText {
                        Layout.fillWidth: true
                        visible: Store.removePreview.err.length > 0 && root.confirm.kind === "remove"
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        color: Theme.warn
                        text: Store.removePreview.err.join("\n")
                        size: Theme.sizeCaption
                        mono: true
                    }

                    // critical packages: explicit confirmation
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.criticalHit.length > 0
                        spacing: Theme.spacingSm
                        ToggleSwitch { checked: root.criticalAck; onToggled: root.criticalAck = !root.criticalAck }
                        UiText {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            color: Theme.error
                            weight: Theme.weightSemiBold
                            size: Theme.sizeCaption + 1
                            text: `Incluye paquetes críticos (${root.criticalHit.slice(0, 4).join(", ")}${root.criticalHit.length > 4 ? "…" : ""}): el sistema o la sesión pueden dejar de funcionar. Entiendo el riesgo.`
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm
                        Item { Layout.fillWidth: true }
                        TextButton { label: "Cancelar"; onClicked: root.overlay = "" }
                        TextButton {
                            danger: true
                            label: root.confirm.kind === "cache" ? "Limpiar" : "Eliminar"
                            enabled: !Store.previewing && (root.criticalHit.length === 0 || root.criticalAck)
                            onClicked: root.doConfirm()
                        }
                    }
                }
            }
        }

        // ---- actions ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            UiText {
                Layout.fillWidth: true
                color: Theme.textDim
                size: Theme.sizeCaption
                elide: Text.ElideRight
                text: root.tab === "search" ? "Tab marca · Enter instala · el AUR pide revisar el PKGBUILD en la terminal"
                    : (root.tab === "installed" ? "Tab marca · Enter elimina (pide confirmación)" : "Todo lo que pide contraseña se ejecuta en una terminal")
            }

            TextButton {
                visible: root.tab === "search" && root.focused !== null && root.itemRepo(root.focused) === "aur"
                label: "Ver PKGBUILD"
                onClicked: root.showPkgbuild(root.focused.name)
            }
            TextButton {
                visible: root.tab === "search"
                primary: true
                enabled: root.targets.length > 0
                label: root.targets.length > 1 ? `Instalar (${root.targets.length})` : "Instalar"
                onClicked: root.act()
            }
            TextButton {
                visible: root.tab === "installed"
                danger: true
                enabled: root.targets.length > 0
                label: root.targets.length > 1 ? `Eliminar (${root.targets.length})` : "Eliminar"
                onClicked: root.act()
            }
            TextButton { visible: root.tab === "updates"; label: "Comprobar"; onClicked: Store.loadUpdates() }
            TextButton {
                visible: root.tab === "updates"
                primary: true
                enabled: Updates.count > 0
                label: "Actualizar todo"
                onClicked: Store.updateAll()
            }
        }
    }
}
