// The command line of the isla de mando (31-isla-mando-busqueda.png): a 34 px field with the mode chips = > ? @ IA.
// It drives the SAME services/Search.qml as the launcher (the launcher is closed while the island is open: one panel
// at a time); `IA` is the island's own mode: Enter opens the drop-down terminal with `claude "<query>"` typed in.
// ↑ ↓ move the selection, Enter runs it, Esc clears (a second Esc closes the island). SUPER + / focuses it.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    property string screenName: ""
    property bool iaMode: false
    property int selection: 0
    readonly property bool active: input.text.length > 0 || iaMode
    readonly property string query: iaMode ? input.text.trim() : Search.query
    // up to 4 results; with text, an «ask Claude» row too (first in IA mode, the only one)
    readonly property var results: {
        if (!root.active) return [];
        const ia = root.query.length > 0 ? [{ id: "ia", title: `Preguntar a Claude: «${root.query}»`, sub: "claude", kind: "ia" }] : [];
        if (root.iaMode) return ia;
        return Search.results.slice(0, Theme.cmdResults - ia.length).map(r => Object.assign({}, r)).concat(ia);
    }

    function clear(): void { input.text = ""; root.iaMode = false; root.selection = 0; Search.reset(); }
    function setMode(prefix: string): void {
        if (prefix === "ia") { root.iaMode = !root.iaMode; if (root.iaMode) input.text = Search.query; }
        else { root.iaMode = false; input.text = prefix + Search.query; }
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }
    function run(r): void {
        if (!r) return;
        if (r.kind === "ia") { Dropdown.askClaude(root.query); ShellState.close(); return; }
        if (Search.run(r)) ShellState.close();
    }
    function focusLine(): void {
        if (ShellState.commandText.length > 0) { input.text = ShellState.commandText; ShellState.commandText = ""; }
        input.forceActiveFocus();
    }

    radius: height / 2
    color: Theme.cmdFill
    border.width: 1
    border.color: input.activeFocus ? Theme.alpha(Theme.cyan, 0.5) : Theme.cmdEdge
    Behavior on border.color { ColorAnimation { duration: Theme.durHover } }

    // SUPER + / (qs ipc call shell command): open the island with the line focused
    Connections {
        target: ShellState
        function onCommandFocusChanged() { Qt.callLater(root.focusLine); }
    }
    Component.onCompleted: if (ShellState.commandFocus > 0 && ShellState.nookTab === "nook") Qt.callLater(root.focusLine)
    Component.onDestruction: if (root.active) Search.reset()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingXs + 2
        spacing: Theme.spacingSm

        UiText { text: "›"; color: root.iaMode ? Theme.pink : Theme.cyan; size: Theme.sizeBodyLg; weight: Theme.weightSemiBold }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.sizeBody + 1
            selectionColor: Theme.alpha(Theme.cyan, 0.35)
            clip: true
            onTextChanged: { if (!root.iaMode) Search.text = text; root.selection = 0; }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: root.iaMode ? "Pregunta a Claude…" : "Pregunta, ejecuta o busca…"
                color: Theme.textDim
                font: input.font
            }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Down) { root.selection = Math.min(root.results.length - 1, root.selection + 1); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { root.selection = Math.max(0, root.selection - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.run(root.results[root.selection]); e.accepted = true; }
                else if (e.key === Qt.Key_Escape) {
                    if (root.active) { root.clear(); e.accepted = true; }
                    else { ShellState.close(); e.accepted = true; }
                }
            }
        }

        Repeater {
            model: [{ p: "=", c: Theme.warn }, { p: ">", c: Theme.cyan }, { p: "?", c: Theme.textSoft }, { p: "@", c: Theme.ok }, { p: "ia", c: Theme.pink }]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: modelData.p === "ia" ? root.iaMode : (!root.iaMode && Search.prefix === modelData.p)
                implicitWidth: Math.max(Theme.cmdChip, chipText.implicitWidth + 10)
                implicitHeight: Theme.cmdChip
                radius: 5
                color: on ? Theme.alpha(modelData.c, 0.22) : Theme.alpha(Theme.text, 0.06)
                border.width: on ? 1 : 0
                border.color: Theme.alpha(modelData.c, 0.6)
                UiText { id: chipText; anchors.centerIn: parent; text: chip.modelData.p === "ia" ? "IA" : chip.modelData.p; mono: true; size: Theme.sizeCaption; weight: Theme.weightSemiBold; color: chip.modelData.c }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.on ? root.clear() : root.setMode(chip.modelData.p) }
            }
        }
    }
}
