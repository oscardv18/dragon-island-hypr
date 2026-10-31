// Results of the isla de mando's command line (31-isla-mando-busqueda.png): «RESULTADOS · MISMO MOTOR QUE EL LAUNCHER»,
// up to 4 rows with a kind badge, the title and a hint on the right; ↑ ↓ / hover select, Enter / click run.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    required property var cmd
    spacing: Theme.spacingXs + 2

    function badge(kind: string): string {
        return { app: "APP", calc: "=", cmd: ">", web: "?", emoji: ":", workspace: "@", ia: "IA", info: "i" }[kind] ?? kind.slice(0, 3).toUpperCase();
    }
    function hint(r): string {
        if (r.kind === "ia") return "claude";
        if (r.kind === "app") return "Enter abre";
        if (r.kind === "cmd") return "terminal";
        if (r.kind === "web") return "web";
        return r.sub ?? "";
    }

    HudCaption { text: "Resultados · mismo motor que el launcher" }
    UiText { visible: root.cmd.results.length === 0; text: Search.busy ? "Buscando…" : "Sin resultados"; color: Theme.textDim }
    Repeater {
        model: root.cmd.results
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: index === root.cmd.selection
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.cmdResult
            radius: Theme.hudCardRadius - 2
            color: selected ? Theme.alpha(Theme.cyan, 0.07) : (mouse.containsMouse ? Theme.hudRowHover : Theme.hudRowFill)
            border.width: selected ? 1 : 0
            border.color: Theme.alpha(Theme.cyan, 0.4)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingSm
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingMd
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 20
                    radius: 5
                    color: Theme.alpha(row.modelData.kind === "ia" ? Theme.pink : Theme.cyan, 0.12)
                    HudCaption { anchors.centerIn: parent; text: root.badge(row.modelData.kind); color: row.modelData.kind === "ia" ? Theme.pink : Theme.cyan }
                }
                UiText { Layout.fillWidth: true; text: row.modelData.title; weight: Theme.weightMedium }
                HudCaption { text: root.hint(row.modelData); Layout.maximumWidth: 140 }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.cmd.selection = row.index
                onClicked: root.cmd.run(row.modelData)
            }
        }
    }
    Item { Layout.fillHeight: true }
}
