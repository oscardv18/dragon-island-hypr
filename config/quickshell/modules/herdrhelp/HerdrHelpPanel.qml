// =============================================================================
// dragon-island — HerdrHelpPanel.qml (SUPER + SHIFT + A): reference of herdr, to read, not to operate
// Tabs: Atajos (key caps, defaults + what you changed) · Comandos (the `herdr` CLI, usage straight from the binary)
// · Conceptos y estados. Data: services/HerdrHelp.qml. Keyboard: type to filter · Tab switches tab · ↑/↓ scroll · Esc closes.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    property string tab: "commands"            // "keys" | "commands" | "concepts"

    function focusSearch(): void { search.focusInput(); }

    onShownChanged: {
        if (shown) { search.text = ""; tab = "commands"; flick.contentY = 0; HerdrHelp.refresh(); }
    }
    onTabChanged: flick.contentY = 0

    readonly property string q: search.text.trim().toLowerCase()

    // ---- filtered data ----
    readonly property var keyGroups: {
        if (!root.shown) return [];
        const out = [];
        for (const g of HerdrHelp.keyGroups) {
            const rows = g.rows.filter(r => root.q === "" || r.text.toLowerCase().includes(root.q) || r.action.includes(root.q) || r.keys.join("+").toLowerCase().includes(root.q));
            if (rows.length > 0) out.push({ name: g.name, rows: rows });
        }
        return out;
    }
    // two balanced columns (weight = rows + header), keeping the order inside each column
    readonly property var keyColumns: {
        const cols = [[], []], w = [0, 0];
        for (const g of root.keyGroups) {
            const c = w[0] <= w[1] ? 0 : 1;
            cols[c].push(g);
            w[c] += g.rows.length + 2;
        }
        return cols;
    }
    readonly property var commandGroups: {
        if (!root.shown) return [];
        const out = [];
        for (const g of HerdrHelp.commandGroups) {
            const rows = g.rows.filter(r => root.q === "" || r.usage.toLowerCase().includes(root.q) || r.desc.toLowerCase().includes(root.q));
            if (rows.length > 0) out.push({ name: g.name, rows: rows });
        }
        return out;
    }
    readonly property var concepts: [
        { name: "Workspace", text: "Un proyecto: agrupa pestañas. Se elige con el selector o con «Ir a…»." },
        { name: "Pestaña", text: "Una disposición de paneles dentro de un workspace." },
        { name: "Panel", text: "Una terminal. Puede tener o no un agente de código dentro." },
        { name: "Agente", text: "Un asistente de código (claude, codex…) que herdr reconoce dentro de un panel y cuyo estado vigila." },
        { name: "Modo prefijo", text: "Se entra con la tecla prefijo; la siguiente tecla ejecuta una acción («Prefijo + N» = pulsar el prefijo, soltar y pulsar N)." }
    ]
    readonly property var states: HerdrHelp.states.filter(s => root.q === "" || s.state.includes(root.q) || s.text.toLowerCase().includes(root.q))
    readonly property var conceptRows: root.concepts.filter(c => root.q === "" || c.name.toLowerCase().includes(root.q) || c.text.toLowerCase().includes(root.q))

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Herdr · atajos y funciones"
        popWidth: Math.min(Theme.keybindsWidth, root.width - Theme.barMarginSide * 2)
        originX: width / 2
        x: (root.width - width) / 2
        y: Math.max(Theme.barMarginTop + Theme.barHeight + Theme.popoverGap, (root.height - height) / 2)

        headerRight: UiText {
            text: !HerdrHelp.available ? "herdr no instalado"
                  : (HerdrHelp.loading ? "Leyendo…" : `${HerdrHelp.version} · prefijo ${HerdrHelp.prefix}`)
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }

        Segmented {
            Layout.fillWidth: true
            model: [{ key: "keys", label: "Atajos" }, { key: "commands", label: "Comandos" }, { key: "concepts", label: "Conceptos y estados" }]
            current: root.tab
            onSelected: key => root.tab = key
        }

        InputField {
            id: search
            Layout.fillWidth: true
            icon: Icons.search
            placeholder: "Buscar un atajo, un comando o un estado…"
            onNavigate: d => flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + d * Theme.rowHeight * 2))
            onEscapePressed: ShellState.close()
            Keys.onTabPressed: root.tab = root.tab === "keys" ? "commands" : (root.tab === "commands" ? "concepts" : "keys")
        }

        UiText {
            visible: !HerdrHelp.available
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "No se encontró herdr en ~/.local/bin/herdr"
            color: Theme.textDim
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, root.height - (Theme.barMarginTop + Theme.barHeight + Theme.popoverGap) * 2 - Theme.keybindsChrome - 44)
            contentHeight: root.tab === "keys" ? keysRow.implicitHeight : (root.tab === "commands" ? cmdCol.implicitHeight : conceptCol.implicitHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // ---- shortcuts ----
            RowLayout {
                id: keysRow
                visible: root.tab === "keys"
                width: flick.width
                spacing: Theme.spacingMd
                Repeater {
                    model: 2
                    delegate: ColumnLayout {
                        id: column
                        required property int index
                        Layout.preferredWidth: (keysRow.width - Theme.spacingMd) / 2
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.spacingMd
                        Repeater {
                            model: root.keyColumns[column.index]
                            delegate: Card {
                                id: groupCard
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Theme.spacingSm
                                UiText { caption: true; text: groupCard.modelData.name }
                                Repeater {
                                    model: groupCard.modelData.rows
                                    delegate: RowLayout {
                                        id: keyRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSm
                                        UiText { Layout.fillWidth: true; text: keyRow.modelData.text; color: keyRow.modelData.unbound ? Theme.textDim : Theme.textSoft }
                                        Rectangle { visible: keyRow.modelData.custom; width: 6; height: 6; radius: 3; color: Theme.accent }
                                        KeyCombo { visible: !keyRow.modelData.unbound; keys: keyRow.modelData.keys }
                                        UiText { visible: keyRow.modelData.unbound; text: "sin asignar"; size: Theme.sizeCaption; color: Theme.textDim }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- commands ----
            ColumnLayout {
                id: cmdCol
                visible: root.tab === "commands"
                width: flick.width
                spacing: Theme.spacingMd
                Repeater {
                    model: root.commandGroups
                    delegate: Card {
                        id: cmdCard
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm
                        UiText { caption: true; text: `herdr ${cmdCard.modelData.name}` }
                        Repeater {
                            model: cmdCard.modelData.rows
                            delegate: ColumnLayout {
                                id: cmdRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                UiText { Layout.fillWidth: true; text: cmdRow.modelData.usage; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft; wrapMode: Text.WrapAnywhere; maximumLineCount: 3 }
                                UiText { visible: cmdRow.modelData.desc !== ""; Layout.fillWidth: true; text: cmdRow.modelData.desc; size: Theme.sizeCaption + 1; color: Theme.textDim }
                            }
                        }
                    }
                }
            }

            // ---- concepts and states ----
            ColumnLayout {
                id: conceptCol
                visible: root.tab === "concepts"
                width: flick.width
                spacing: Theme.spacingMd
                Card {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    UiText { caption: true; text: "Conceptos" }
                    Repeater {
                        model: root.conceptRows
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacingMd
                            UiText { Layout.preferredWidth: 110; text: modelData.name; weight: Theme.weightSemiBold }
                            UiText { Layout.fillWidth: true; text: modelData.text; color: Theme.textSoft; maximumLineCount: 3; wrapMode: Text.WordWrap }
                        }
                    }
                }
                Card {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    UiText { caption: true; text: "Estados de un agente (los mismos puntos de color del dashboard)" }
                    Repeater {
                        model: root.states
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.spacingMd
                            Rectangle { Layout.alignment: Qt.AlignVCenter; width: 8; height: 8; radius: 4; color: Theme.agentColor(modelData.state) }
                            UiText { Layout.preferredWidth: 90; text: modelData.state; mono: true; size: Theme.sizeCaption + 1 }
                            UiText { Layout.fillWidth: true; text: modelData.text; color: Theme.textSoft; maximumLineCount: 3; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }
        }

        UiText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: root.tab === "keys" ? "● = cambiado en tu config.toml · Tab cambia de pestaña · Esc cerrar" : "Tab cambia de pestaña · Esc cerrar"
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }
}
