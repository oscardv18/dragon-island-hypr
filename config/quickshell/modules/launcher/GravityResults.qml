// =============================================================================
// dragon-island — GravityResults.qml: the «RESULTADOS» panel of the Gravity launcher (03-busqueda.png)
// The unified results of services/Search.qml: icon, title with the matched letters in cyan, a second line, the row
// number (↵ on the chosen one). Under them, when the chosen app is a terminal with several windows, «LUNAS DE
// TERMINAL · TAB»: one row per window (title in mono, its workspace); Tab walks them, Enter goes to that window.
// =============================================================================
import QtQuick
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    property real gs: 1
    property var results: []
    property int sel: 0
    property var moons: []            // [{ address, title, workspace }]
    property int moonSel: -1
    property string query: ""
    signal picked(int index)
    signal hoveredRow(int index)
    signal moonPicked(int index)

    readonly property int shown: Math.min(results.length, 6)

    width: Theme.gravityPanelWidth * gs
    height: col.implicitHeight + Theme.gravityPanelPad * gs * 2
    radius: Theme.gravityPanelRadius * gs
    color: Theme.gravityPanel
    border.width: 1
    border.color: Theme.gravityTileEdge

    function esc(s: string): string { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    // matched letters in cyan: the substring if there is one, else the letters of the query in order
    function rich(title: string, q: string): string {
        const t = title || "", lq = (q || "").toLowerCase();
        if (lq.length === 0) return esc(t);
        const marks = new Array(t.length).fill(false);
        const at = t.toLowerCase().indexOf(lq);
        if (at >= 0) for (let i = 0; i < lq.length; i++) marks[at + i] = true;
        else {
            let j = 0;
            for (let i = 0; i < t.length && j < lq.length; i++) if (t[i].toLowerCase() === lq[j]) { marks[i] = true; j++; }
            if (j < lq.length) marks.fill(false);
        }
        let out = "", open = false;
        for (let i = 0; i < t.length; i++) {
            if (marks[i] && !open) { out += `<font color="${Theme.gravityMatch}">`; open = true; }
            if (!marks[i] && open) { out += "</font>"; open = false; }
            out += esc(t[i]);
        }
        return open ? out + "</font>" : out;
    }
    function glyphFor(kind: string): string {
        switch (kind) {
            case "calc": return Icons.calculator;
            case "cmd": return Icons.terminal;
            case "web": return Icons.web;
            case "workspace": return Icons.desktop;
            case "info": return Icons.download;
            default: return Icons.search;
        }
    }

    Column {
        id: col
        x: Theme.gravityPanelPad * root.gs
        y: Theme.gravityPanelPad * root.gs
        width: parent.width - x * 2
        spacing: Theme.spacingXs * root.gs

        Item {
            width: parent.width
            height: head.implicitHeight + Theme.spacingXs * root.gs
            UiText {
                id: head
                text: Search.busy && root.results.length === 0 ? "BUSCANDO…" : (root.results.length === 0 ? "SIN RESULTADOS" : "RESULTADOS")
                mono: true
                size: Theme.sizeCaption * Math.max(1, root.gs)
                color: Theme.textDim
                font.letterSpacing: 2.4 * root.gs
            }
            UiText {
                anchors.right: parent.right
                text: "⇅ elegir"
                mono: true
                size: Theme.sizeCaption * Math.max(1, root.gs)
                color: Theme.textDim
            }
        }

        Repeater {
            model: root.shown
            delegate: Rectangle {
                id: row
                required property int index
                readonly property var r: root.results[index] ?? ({})
                readonly property bool current: index === root.sel
                width: parent.width
                height: Theme.gravityResultRow * root.gs * 1.25
                radius: Theme.gravityRowRadius * root.gs
                color: current ? Theme.gravitySelection : Theme.transparent
                border.width: current ? 1 : 0
                border.color: Theme.gravitySelectionEdge

                Rectangle {
                    id: icon
                    x: Theme.spacingSm * root.gs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.gravityResultRow * 0.8 * root.gs
                    height: width
                    radius: Theme.gravityRowRadius * 0.8 * root.gs
                    color: Theme.gravityTile
                    border.width: 1
                    border.color: Theme.gravityTileEdge
                    Image {
                        visible: row.r.kind === "app"
                        anchors.fill: parent
                        anchors.margins: 2
                        source: row.r.kind === "app" ? (row.r.icon || "") : ""
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }
                    UiText {
                        visible: row.r.kind === "emoji"
                        anchors.centerIn: parent
                        text: row.r.kind === "emoji" ? (row.r.title || "") : ""
                        size: Theme.sizeTitle * Math.max(1, root.gs)
                    }
                    Glyph {
                        visible: row.r.kind !== "app" && row.r.kind !== "emoji"
                        anchors.centerIn: parent
                        icon: root.glyphFor(row.r.kind || "")
                        size: Theme.iconLg * root.gs
                        color: Theme.searchModeColors[Search.prefix] ?? Theme.textSoft
                    }
                }
                Column {
                    anchors { left: icon.right; leftMargin: Theme.spacingMd * root.gs; right: badge.left; rightMargin: Theme.spacingSm * root.gs; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width
                        text: root.rich(row.r.title || "", Search.mode === "apps" ? root.query : "")
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: Theme.text
                        font.family: row.r.kind === "calc" || row.r.kind === "cmd" ? Theme.fontMono : Theme.fontUi
                        font.pixelSize: Math.round(Theme.sizeBodyLg * Math.max(1, root.gs))
                        font.weight: Theme.weightSemiBold
                    }
                    UiText {
                        width: parent.width
                        visible: text.length > 0
                        text: row.r.sub || ""
                        size: Theme.sizeBody * Math.max(1, root.gs)
                        color: Theme.textDim
                    }
                }
                Rectangle {
                    id: badge
                    anchors { right: parent.right; rightMargin: Theme.spacingSm * root.gs; verticalCenter: parent.verticalCenter }
                    width: Theme.gravityChip * 0.85 * root.gs
                    height: width
                    radius: Theme.keyCapRadius * root.gs
                    color: row.current ? Theme.alpha(Theme.cyan, 0.16) : Theme.alpha(Theme.text, 0.06)
                    UiText {
                        anchors.centerIn: parent
                        text: row.current ? "↵" : `${row.index + 1}`
                        mono: true
                        size: Theme.sizeCaption * Math.max(1, root.gs)
                        color: row.current ? Theme.cyan : Theme.textDim
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredRow(row.index)
                    onClicked: root.picked(row.index)
                }
            }
        }

        // terminal moons
        Rectangle {
            visible: root.moons.length > 1
            width: parent.width
            height: 1
            color: Theme.hairline
        }
        UiText {
            visible: root.moons.length > 1
            topPadding: Theme.spacingSm * root.gs
            bottomPadding: Theme.spacingXs * root.gs
            text: "LUNAS DE TERMINAL · TAB"
            mono: true
            size: Theme.sizeCaption * Math.max(1, root.gs)
            color: Theme.textDim
            font.letterSpacing: 2.4 * root.gs
        }
        Repeater {
            model: root.moons.length > 1 ? root.moons : []
            delegate: Rectangle {
                id: moon
                required property var modelData
                required property int index
                readonly property bool current: index === root.moonSel
                width: parent.width
                height: Theme.gravityResultRow * root.gs * 1.2
                radius: Theme.gravityRowRadius * root.gs
                color: current ? Theme.gravitySelection : Theme.alpha(Theme.text, 0.04)
                border.width: current ? 1 : 0
                border.color: Theme.gravitySelectionEdge
                Rectangle {
                    id: dot
                    x: Theme.spacingMd * root.gs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.gravityDot * root.gs
                    height: width
                    radius: width / 2
                    color: Theme.cyan
                }
                Column {
                    anchors { left: dot.right; leftMargin: Theme.spacingMd * root.gs; right: parent.right; rightMargin: Theme.spacingSm * root.gs; verticalCenter: parent.verticalCenter }
                    UiText { width: parent.width; text: moon.modelData.title || ""; mono: true; size: Theme.sizeBody * Math.max(1, root.gs) }
                    UiText { width: parent.width; text: `Escritorio ${moon.modelData.workspace}`; size: Theme.sizeCaption * Math.max(1, root.gs) + 1; color: Theme.textDim }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moonPicked(moon.index)
                }
            }
        }
    }
}
