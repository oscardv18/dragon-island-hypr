// Pure unified diff with line numbers. Reusable by ReviewTab; no Git process here.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
ColumnLayout {
    id: root
    property var diff: ({hunks:[]})
    readonly property var rows: {
        const result = [];
        for (const h of root.diff?.hunks ?? []) {
            result.push({t:"head",text:h.header,o:null,n:null});
            for (const line of h.lines) result.push(line);
        }
        return result;
    }
    spacing: Theme.taller.smallGap
    UiText { visible: !!root.diff?.binary || !!root.diff?.truncated; Layout.fillWidth: true; text: root.diff?.binary ? "Archivo binario · sin diff de texto" : "Diff recortado a 2.000 líneas"; color: Theme.warn; size: Theme.taller.body }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.taller.buttonRadius
        color: Theme.taller.output
        FontMetrics { id: fontMetrics; font.family: Theme.fontMono; font.pixelSize: Theme.taller.mono }
        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: Theme.taller.smallGap
            anchors.bottomMargin: Theme.taller.smallGap
            clip: true
            model: root.rows
            contentWidth: Math.max(width, ...root.rows.map(r => (r.text?.length ?? 0) * fontMetrics.averageCharacterWidth + Theme.taller.diffNumberWidth * 2 + Theme.taller.inset * 2))
            flickableDirection: Flickable.AutoFlickDirection
            delegate: Rectangle {
                required property var modelData
                width: list.contentWidth
                height: Theme.taller.diffLineHeight
                color: modelData.t === "add" ? Theme.diffAdd : modelData.t === "del" ? Theme.diffDel : modelData.t === "head" ? Theme.taller.card : Theme.transparent
                Row {
                    anchors.fill: parent
                    UiText { width: Theme.taller.diffNumberWidth; height: parent.height; text: modelData.o ?? ""; mono: true; size: Theme.taller.mono; color: Theme.textDim; horizontalAlignment: Text.AlignHCenter }
                    UiText { width: Theme.taller.diffNumberWidth; height: parent.height; text: modelData.n ?? ""; mono: true; size: Theme.taller.mono; color: Theme.textDim; horizontalAlignment: Text.AlignHCenter }
                    UiText { height: parent.height; text: (modelData.t === "add" ? "+ " : modelData.t === "del" ? "− " : "  ") + modelData.text; mono: true; size: Theme.taller.mono; elide: Text.ElideNone; color: modelData.t === "add" ? Theme.ok : modelData.t === "del" ? Theme.danger : modelData.t === "head" ? Theme.cyan : Theme.textSoft }
                }
            }
            UiText { anchors.centerIn: parent; visible: list.count === 0; text: root.diff?.binary ? "Sin vista de texto" : "Selecciona un archivo para revisar sus cambios"; color: Theme.textDim; size: Theme.taller.body; width: parent.width-Theme.taller.inset*2; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 3 }
        }
    }
}
