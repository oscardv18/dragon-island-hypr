// =============================================================================
// dragon-island — WallpaperPanel.qml (SUPER + W)
// Wallpaper picker: tabs Todos / Imágenes / Animados, search, 16:9 thumbnails (radius 14) with GIF / VIDEO
// badges, the current one outlined in accent, a large preview of the hovered / selected one.
// Keyboard: type to filter · arrows move · Enter applies · Esc closes.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    property string tab: "all"        // "all" | "static" | "animated"
    property int current: 0
    property int hovered: -1

    readonly property int columns: 3
    readonly property var results: shown ? Wallpaper.search(search.text, tab) : []
    readonly property var previewItem: results[hovered >= 0 ? hovered : current] ?? null

    function focusSearch(): void { search.focusInput(); }

    function move(dx: int, dy: int): void {
        if (results.length === 0) return;
        root.hovered = -1;
        current = Math.max(0, Math.min(results.length - 1, current + dx + dy * columns));
        grid.positionViewAtIndex(current, GridView.Contain);
    }

    function applyAt(index: int): void {
        const it = results[index];
        if (it) Wallpaper.apply(it.path);
    }

    onShownChanged: {
        if (shown) {
            search.text = "";
            tab = "all";
            hovered = -1;
            Wallpaper.refresh();
            const at = Wallpaper.items.findIndex(i => i.path === Wallpaper.current);
            current = Math.max(0, at);
        }
    }
    onResultsChanged: current = Math.min(current, Math.max(0, results.length - 1))

    component TextButton: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        signal clicked()
        implicitHeight: Theme.touchTarget
        implicitWidth: btnRow.implicitWidth + Theme.spacingMd * 2
        radius: Theme.rowRadius
        color: btnMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: Theme.spacingSm
            Glyph { anchors.verticalCenter: parent.verticalCenter; icon: btn.icon; size: Theme.iconMd; color: Theme.textSoft }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: btn.label; weight: Theme.weightMedium }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Fondos de pantalla"
        popWidth: Math.min(Theme.wallpaperPanelWidth, root.width - Theme.barMarginSide * 2)
        originX: width / 2
        x: (root.width - width) / 2
        y: Math.max(Theme.barMarginTop + Theme.barHeight + Theme.popoverGap, (root.height - height) / 2)

        headerRight: UiText {
            text: Wallpaper.loading ? "Leyendo…" : `${root.results.length} fondos`
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Segmented {
                Layout.preferredWidth: Theme.wallpaperTabsWidth
                implicitHeight: Theme.touchTarget
                model: [{ key: "all", label: "Todos" }, { key: "static", label: "Imágenes" }, { key: "animated", label: "Animados" }]
                current: root.tab
                onSelected: key => { root.tab = key; root.current = 0; }
            }

            InputField {
                id: search
                Layout.fillWidth: true
                icon: Icons.search
                placeholder: "Buscar fondos…"
                gridNav: true
                onNavigateGrid: (dx, dy) => root.move(dx, dy)
                onNavigate: d => root.move(d, 0)
                onAccepted: root.applyAt(root.current)
                onEscapePressed: ShellState.close()
            }

            TextButton { icon: Icons.shuffle; label: "Aleatorio"; onClicked: Wallpaper.random() }
            TextButton { icon: Icons.folder; label: "Abrir carpeta"; onClicked: Wallpaper.openFolder() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            // ---- thumbnails ----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.wallpaperGridHeight

                UiText {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: Wallpaper.loading ? "Leyendo la carpeta…" : (search.text.length > 0 ? `Sin resultados para «${search.text}»` : `No hay fondos en ${Wallpaper.dir}`)
                    color: Theme.textDim
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: root.results.length > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / root.columns)
                    cellHeight: Math.round(cellWidth * 9 / 16) + Theme.spacingSm
                    currentIndex: root.current
                    model: ScriptModel {
                        values: root.results
                        objectProp: "path"
                    }

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: modelData.path === Wallpaper.current
                        readonly property bool selected: index === root.current
                        width: grid.cellWidth
                        height: grid.cellHeight

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXs
                            anchors.bottomMargin: Theme.spacingXs + Theme.spacingSm / 2
                            radius: Theme.wallpaperThumbRadius
                            color: Theme.surface2
                            border.width: cell.isCurrent ? 2 : (cell.selected ? 1 : 0)
                            border.color: cell.isCurrent ? Theme.accent : Theme.alpha(Theme.text, 0.5)

                            Image {
                                anchors.fill: parent
                                source: Wallpaper.thumbUrl(cell.modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 400
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.hoverOverlay
                                visible: cellMouse.containsMouse
                            }

                            // badge GIF / VIDEO
                            Rectangle {
                                visible: cell.modelData.kind !== "static"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.spacingXs + 2
                                radius: height / 2
                                height: 18
                                width: badge.implicitWidth + Theme.spacingSm * 2
                                color: Theme.alpha(Theme.island, 0.7)
                                UiText {
                                    id: badge
                                    anchors.centerIn: parent
                                    text: cell.modelData.kind === "video" ? "VIDEO" : "GIF"
                                    size: Theme.sizeCaption - 1
                                    weight: Theme.weightBold
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.hovered = cell.index
                                onExited: if (root.hovered === cell.index) root.hovered = -1
                                onClicked: { root.current = cell.index; Wallpaper.apply(cell.modelData.path); }
                            }
                        }
                    }
                }
            }

            // ---- large preview ----
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: Theme.wallpaperPreviewWidth
                Layout.maximumWidth: Theme.wallpaperPreviewWidth
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingSm

                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(width * 9 / 16)
                    radius: Theme.wallpaperThumbRadius
                    color: Theme.surface2

                    Loader {
                        anchors.fill: parent
                        active: root.shown && root.previewItem !== null
                        sourceComponent: root.previewItem?.kind === "animated" ? animatedPreview : stillPreview
                    }

                    Component {
                        id: stillPreview
                        Item {
                            // images: the picture itself; videos: the poster frame (never decode a video here)
                            Image {
                                anchors.fill: parent
                                source: root.previewItem?.kind === "static" ? `file://${root.previewItem.path}` : Wallpaper.thumbUrl(root.previewItem)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 640
                            }
                            Glyph {
                                visible: root.previewItem?.kind === "video"
                                anchors.centerIn: parent
                                icon: Icons.play
                                size: Theme.iconLg * 2
                                color: Theme.alpha(Theme.text, 0.85)
                            }
                        }
                    }
                    Component {
                        id: animatedPreview
                        AnimatedImage {
                            source: `file://${root.previewItem.path}`
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            playing: true
                        }
                    }
                }

                UiText {
                    Layout.fillWidth: true
                    text: root.previewItem?.name ?? ""
                    size: Theme.sizeBodyLg
                    weight: Theme.weightSemiBold
                }
                UiText {
                    Layout.fillWidth: true
                    text: {
                        const k = root.previewItem?.kind;
                        const base = k === "video" ? "Video" : (k === "animated" ? "GIF animado" : (k === "static" ? "Imagen" : ""));
                        return root.previewItem && root.previewItem.path === Wallpaper.current ? `${base} · fondo actual` : base;
                    }
                    color: Theme.textDim
                }
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: `${Wallpaper.dir} · ←↑↓→ mover · Enter aplicar · Esc cerrar`
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }
}
