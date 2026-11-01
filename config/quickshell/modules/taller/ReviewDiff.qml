// Unified diff with a comment margin (32-taller-revision): click the gutter of a line to write a comment; lines with
// comments show ● and their lavender bubbles underneath. Pure view; comments are handed to `commentRequested`.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

ColumnLayout {
    id: root
    property var diff: ({ hunks: [] })
    property var comments: []          // [{path, line, text}] of this file
    property int editing: -1           // line number whose input is open
    signal commentRequested(int line, string text)
    function lineOf(l): int { return l.n ?? l.o ?? -1; }
    readonly property var rows: {
        const result = [], byLine = {};
        for (const c of root.comments) (byLine[c.line] = byLine[c.line] ?? []).push(c);
        for (const h of root.diff?.hunks ?? []) {
            result.push({ kind: "line", t: "head", text: h.header, o: null, n: null });
            for (const l of h.lines) {
                result.push(Object.assign({ kind: "line", marked: !!byLine[lineOf(l)] }, l));
                for (const c of byLine[lineOf(l)] ?? []) result.push({ kind: "comment", text: c.text });
                if (root.editing >= 0 && lineOf(l) === root.editing) result.push({ kind: "input", line: root.editing });
            }
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
        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: Theme.taller.smallGap
            anchors.bottomMargin: Theme.taller.smallGap
            clip: true
            model: root.rows
            delegate: Loader {
                required property var modelData
                width: list.width
                height: modelData.kind === "line" ? Theme.taller.diffLineHeight : Theme.taller.bubbleHeight + Theme.taller.smallGap
                sourceComponent: modelData.kind === "line" ? lineRow : modelData.kind === "comment" ? bubbleRow : inputRow
                Component {
                    id: lineRow
                    Rectangle {
                        color: modelData.t === "add" ? Theme.diffAdd : modelData.t === "del" ? Theme.diffDel : Theme.transparent
                        Row {
                            anchors.fill: parent
                            Item {
                                width: Theme.taller.gutterWidth; height: parent.height
                                UiText { anchors.centerIn: parent; text: modelData.marked ? "●" : (modelData.t === "head" ? "" : "+"); size: Theme.taller.caption; color: modelData.marked ? Theme.lavender : Theme.taller.border; visible: modelData.marked || gutter.containsMouse || modelData.t !== "head" }
                                MouseArea {
                                    id: gutter
                                    anchors.fill: parent
                                    enabled: modelData.t !== "head"
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editing = root.lineOf(modelData)
                                }
                            }
                            UiText { width: Theme.taller.diffNumberWidth; height: parent.height; text: modelData.n ?? modelData.o ?? ""; mono: true; size: Theme.taller.mono; color: Theme.textDim; horizontalAlignment: Text.AlignRight }
                            UiText { width: Theme.taller.inset * 2; height: parent.height; text: modelData.t === "add" ? "+" : modelData.t === "del" ? "−" : ""; mono: true; size: Theme.taller.mono; color: modelData.t === "add" ? Theme.ok : Theme.danger; horizontalAlignment: Text.AlignHCenter }
                            UiText { width: parent.width - Theme.taller.gutterWidth - Theme.taller.diffNumberWidth - Theme.taller.inset * 2; height: parent.height; text: modelData.text; mono: true; size: Theme.taller.mono; color: modelData.t === "head" ? Theme.cyan : Theme.text }
                        }
                    }
                }
                Component {
                    id: bubbleRow
                    Item {
                        Rectangle {
                            x: Theme.taller.gutterWidth + Theme.taller.diffNumberWidth + Theme.taller.inset * 2
                            y: Theme.taller.thinGap
                            width: Math.min(parent.width - x - Theme.taller.inset, bubbleText.implicitWidth + Theme.taller.inset * 2)
                            height: Theme.taller.bubbleHeight - Theme.taller.thinGap
                            radius: Theme.taller.buttonRadius
                            color: Theme.taller.bubble
                            border.width: Theme.taller.buttonBorder
                            border.color: Theme.taller.bubbleBorder
                            UiText { id: bubbleText; anchors.fill: parent; anchors.leftMargin: Theme.taller.inset; anchors.rightMargin: Theme.taller.inset; text: modelData.text; size: Theme.taller.body }
                        }
                    }
                }
                Component {
                    id: inputRow
                    Item {
                        TallerInput {
                            id: input
                            x: Theme.taller.gutterWidth + Theme.taller.diffNumberWidth + Theme.taller.inset * 2
                            y: Theme.taller.thinGap
                            width: parent.width - x - Theme.taller.inset
                            height: Theme.taller.bubbleHeight - Theme.taller.thinGap
                            placeholder: `Comentario en la línea ${modelData.line} · Enter guarda · Esc cancela`
                            Component.onCompleted: Qt.callLater(focusInput)
                            onAccepted: { if (text.trim()) root.commentRequested(modelData.line, text); root.editing = -1; }
                            Keys.onEscapePressed: e => { root.editing = -1; e.accepted = true; }
                        }
                    }
                }
            }
            UiText { anchors.centerIn: parent; visible: list.count === 0; text: "Selecciona un archivo para revisar sus cambios"; color: Theme.textDim; size: Theme.taller.body }
        }
    }
}
