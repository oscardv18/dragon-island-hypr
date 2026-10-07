// =============================================================================
// dragon-island — KeybindsPanel.qml (SUPER + F1)
// Cheatsheet of the Hyprland keybinds, read live from Hyprland (Keybinds service),
// grouped by the "Grupo · Texto" descriptions of config/hypr/binds.lua.
// Keyboard: type to filter · ↑/↓ scroll · Esc closes.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    readonly property Item frameItem: card.visible ? card.frameItem : null   // blur region of the window
    readonly property var groups: shown ? Keybinds.search(search.text) : []

    // two balanced columns: heaviest groups first into the lighter column (weight = rows + header),
    // then each column keeps the binds.lua order
    readonly property var columns: {
        const items = root.groups.map((g, i) => ({ g: g, i: i, w: g.rows.length + 2 }));
        const cols = [[], []];
        const weight = [0, 0];
        for (const it of items.slice().sort((a, b) => b.w - a.w)) {
            const c = weight[0] <= weight[1] ? 0 : 1;
            cols[c].push(it);
            weight[c] += it.w;
        }
        return cols.map(col => col.sort((a, b) => a.i - b.i).map(it => it.g));
    }

    function focusSearch(): void { search.focusInput(); }

    onShownChanged: {
        if (shown) {
            search.text = "";
            flick.contentY = 0;
            Keybinds.refresh();     // binds change when the config is reloaded
        }
    }

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Atajos de teclado"
        popWidth: Math.min(Theme.keybindsWidth, root.width - Theme.barMarginSide * 2)
        originX: width / 2
        x: (root.width - width) / 2
        y: Math.max(Theme.barMarginTop + Theme.barHeight + Theme.popoverGap, (root.height - height) / 2)

        headerRight: UiText {
            text: Keybinds.loading ? "Leyendo…" : `${Keybinds.count} atajos`
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }

        InputField {
            id: search
            Layout.fillWidth: true
            icon: Icons.search
            placeholder: "Buscar un atajo o una acción…"
            onNavigate: d => flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height,
                                                                    flick.contentY + d * Theme.rowHeight * 2))
            onEscapePressed: ShellState.close()
        }

        UiText {
            visible: Keybinds.error.length > 0 || (root.groups.length === 0 && !Keybinds.loading)
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingMd
            Layout.bottomMargin: Theme.spacingMd
            horizontalAlignment: Text.AlignHCenter
            text: Keybinds.error.length > 0 ? Keybinds.error : `Ningún atajo coincide con «${search.text}»`
            color: Theme.textDim
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            // screen height minus the bar band (top and bottom) and the panel chrome (title, search, footer):
            // independent of card.y, which is computed from this height (no binding loop)
            Layout.preferredHeight: Math.min(contentHeight,
                root.height - (Theme.barMarginTop + Theme.barHeight + Theme.popoverGap) * 2 - Theme.keybindsChrome)
            contentHeight: columnsRow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            RowLayout {
                id: columnsRow
                width: flick.width
                spacing: Theme.spacingMd

                Repeater {
                    model: 2
                    delegate: ColumnLayout {
                        id: column
                        required property int index
                        Layout.preferredWidth: (columnsRow.width - Theme.spacingMd) / 2
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.spacingMd

                        Repeater {
                            model: root.columns[column.index]
                            delegate: Card {
                                id: groupCard
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.spacingSm

                                UiText { caption: true; text: groupCard.modelData.name }

                                Repeater {
                                    model: groupCard.modelData.rows
                                    delegate: RowLayout {
                                        id: bindRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSm

                                        UiText {
                                            Layout.fillWidth: true
                                            text: bindRow.modelData.text
                                            color: Theme.textSoft
                                        }
                                        ColumnLayout {
                                            spacing: Theme.spacingXs
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            Repeater {
                                                model: bindRow.modelData.combos
                                                delegate: KeyCombo {
                                                    required property var modelData
                                                    Layout.alignment: Qt.AlignRight
                                                    keys: modelData
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: "Ratón y paneles: docs/KEYBINDS.md · Esc cerrar"
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }
}
