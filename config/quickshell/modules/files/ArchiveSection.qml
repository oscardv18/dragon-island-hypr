// Archive part of the preview panel (33-archivos-lista.png): «CONTENIDO · SIN EXTRAER» with a partial tree, then
// MÉTODO · CIFRADO · INTEGRIDAD · AL EXTRAER. Reads the cached `archive list`; never extracts anything.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

ColumnLayout {
    id: root
    property var archives: null
    property string path: ""
    readonly property var info: archives?.cache?.[path] ?? null
    readonly property var test: archives?.tests?.[path] ?? null
    readonly property var tree: F.archiveTree(info?.entries ?? [], Theme.files.treeLines)
    spacing: Theme.files.gap
    onPathChanged: if (path && archives) archives.info(path)
    Component.onCompleted: if (path && archives) archives.info(path)

    UiText { Layout.fillWidth: true; text: "Contenido · sin extraer"; mono: true; size: Theme.files.caption; color: Theme.textDim
             font.letterSpacing: Theme.files.captionTracking; font.capitalization: Font.AllUppercase }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: treeColumn.implicitHeight + Theme.files.inset * 2
        radius: Theme.files.rowRadius
        color: Theme.files.input
        Column {
            id: treeColumn
            x: Theme.files.inset
            y: Theme.files.inset
            width: parent.width - Theme.files.inset * 2
            spacing: Theme.files.thinGap
            UiText { visible: !root.info; width: parent.width; text: root.archives?.loading(root.path) ? "Leyendo el contenido…" : ""; mono: true; size: Theme.files.mono; color: Theme.textDim }
            UiText { visible: !!root.info?.error; width: parent.width; text: root.info?.error?.message ?? ""; mono: true; size: Theme.files.mono; color: Theme.danger; wrapMode: Text.Wrap; maximumLineCount: 3 }
            Repeater {
                model: root.tree.lines
                delegate: Item {
                    required property var modelData
                    width: treeColumn.width
                    height: Theme.files.treeRow
                    UiText { anchors.left: parent.left; anchors.right: value.left; anchors.verticalCenter: parent.verticalCenter
                             text: (modelData.dir ? "▸ " : "") + modelData.label; mono: true; size: Theme.files.mono; color: Theme.text; elide: Text.ElideMiddle }
                    UiText { id: value; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.value; mono: true; size: Theme.files.mono; color: Theme.textSoft }
                }
            }
            UiText { visible: root.tree.more > 0; text: "+ " + root.tree.more + " más…"; mono: true; size: Theme.files.mono; color: Theme.textDim }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        visible: !!root.info && !root.info.error
        columns: 2
        columnSpacing: Theme.files.gap
        rowSpacing: Theme.files.smallGap
        Meta { label: "Método"; value: root.info?.method || "—" }
        Meta { label: "Cifrado"; value: root.info?.encrypted ? "sí · pide contraseña" : "no"; tone: root.info?.encrypted ? Theme.warn : Theme.text }
        Meta {
            label: "Integridad"
            value: root.test === "ok" ? "CRC ✓" : root.test === "running" ? "probando…" : root.test?.error ? "✗ " + root.test.error.message : "sin probar"
            tone: root.test === "ok" ? Theme.ok : root.test?.error ? Theme.danger : Theme.textSoft
        }
        Meta { label: "Al extraer"; value: F.formatSize(root.info?.total_size) }
    }
    Repeater {
        model: root.info?.warnings ?? []
        delegate: UiText { required property var modelData; Layout.fillWidth: true; text: "! " + modelData; size: Theme.files.small; color: Theme.warn; wrapMode: Text.Wrap; maximumLineCount: 3 }
    }
    component Meta: ColumnLayout {
        property string label
        property string value
        property color tone: Theme.text
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 0
        UiText { Layout.fillWidth: true; text: parent.label; mono: true; size: Theme.files.caption; color: Theme.textDim; font.letterSpacing: Theme.files.captionTracking / 2; font.capitalization: Font.AllUppercase }
        UiText { Layout.fillWidth: true; text: parent.value; mono: true; size: Theme.files.mono; color: parent.tone }
    }
}
