// =============================================================================
// dragon-island — ClipboardPanel.qml (SUPER + SHIFT + V)
// Clipboard history (cliphist): text and images with previews.
// Keyboard: type to filter · ↑/↓ or Tab · Enter copies · Supr deletes the entry · Esc closes.
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
    readonly property Item frameItem: card.visible ? card.frameItem : null   // blur region of the window
    property int current: 0
    readonly property var results: shown ? Clipboard.search(search.text) : []

    function focusSearch(): void { search.focusInput(); }

    function move(delta: int): void {
        if (results.length === 0) return;
        current = (current + delta + results.length) % results.length;
        list.positionViewAtIndex(current, ListView.Contain);
    }

    function pick(entry): void {
        if (!entry) return;
        ShellState.close();
        Clipboard.copy(entry);
    }

    onShownChanged: {
        if (shown) {
            search.text = "";
            current = 0;
            Clipboard.refresh();
        }
    }
    onResultsChanged: current = Math.min(current, Math.max(0, results.length - 1))

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Portapapeles"
        popWidth: Theme.launcherWidth
        originX: width / 2
        x: (root.width - width) / 2
        y: Theme.launcherTop

        headerRight: Capsule {
            visible: Clipboard.entries.length > 0
            onClicked: Clipboard.wipe()
            Glyph { icon: Icons.broom; size: Theme.iconSm; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
            UiText { text: "Borrar historial"; size: Theme.sizeCaption + 1; anchors.verticalCenter: parent.verticalCenter }
        }

        InputField {
            id: search
            Layout.fillWidth: true
            icon: Icons.search
            placeholder: "Buscar en el historial…"
            onNavigate: d => root.move(d)
            onAccepted: root.pick(root.results[root.current])
            onEscapePressed: ShellState.close()
            // Supr with an empty search box deletes the highlighted entry
            onDeleteOnEmpty: Clipboard.remove(root.results[root.current])
        }

        UiText {
            visible: root.results.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingMd
            Layout.bottomMargin: Theme.spacingMd
            horizontalAlignment: Text.AlignHCenter
            text: !Clipboard.available ? "cliphist no está instalado"
                  : (search.text.length > 0 ? `Nada coincide con «${search.text}»` : "El historial está vacío")
            color: Theme.textDim
        }

        ListView {
            id: list
            visible: root.results.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Theme.launcherRows * (Theme.rowHeight + spacing))
            clip: true
            spacing: Theme.spacingXs
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.current
            model: ScriptModel {
                values: root.results
                objectProp: "id"
            }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: index === root.current
                readonly property string thumb: Clipboard.thumbnail(modelData)
                width: ListView.view.width
                implicitHeight: modelData.isImage ? Theme.clipThumbHeight + Theme.spacingSm * 2 : Theme.rowHeight

                Component.onCompleted: Clipboard.requestThumbnail(modelData)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rowRadius
                    color: row.selected || rowMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.durHover } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMd
                    anchors.rightMargin: Theme.spacingSm
                    spacing: Theme.spacingSm

                    ClippingRectangle {
                        visible: row.modelData.isImage
                        Layout.preferredWidth: Theme.clipThumbHeight * 16 / 9
                        Layout.preferredHeight: Theme.clipThumbHeight
                        radius: Theme.capsuleRadius
                        color: Theme.surface3
                        Image {
                            anchors.fill: parent
                            source: row.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.height: Theme.clipThumbHeight * 2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        UiText {
                            Layout.fillWidth: true
                            text: row.modelData.isImage ? "Imagen" : row.modelData.text.replace(/\s+/g, " ")
                            weight: Theme.weightMedium
                        }
                        UiText {
                            Layout.fillWidth: true
                            visible: row.modelData.isImage
                            text: row.modelData.meta
                            size: Theme.sizeCaption
                            color: Theme.textDim
                        }
                    }

                    IconButton {
                        icon: Icons.close
                        size: Theme.capsuleHeight - Theme.spacingXs
                        iconSize: Theme.iconSm
                        radius: Theme.capsuleRadius
                        bgColor: Theme.transparent
                        opacity: rowMouse.containsMouse || row.selected ? 1 : 0
                        onClicked: Clipboard.remove(row.modelData)
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    anchors.rightMargin: Theme.capsuleHeight
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = row.index
                    onClicked: root.pick(row.modelData)
                }
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "↑↓ mover · Enter copiar · Supr borrar · Esc cerrar"
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }
}
