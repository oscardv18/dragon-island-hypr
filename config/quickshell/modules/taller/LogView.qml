// Pure memory-only log view. Filtering never starts a process; counts come from Docker.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
ColumnLayout {
    id: root
    property var lines: []
    property string level: "all"
    property bool follow: true
    readonly property var filtered: lines.filter(r => (level === "all" || r.level === level) && (!search.text || r.msg.toLowerCase().includes(search.text.toLowerCase())))
    spacing: Theme.taller.rowGap
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.taller.smallGap
        UiText { text: "LOGS EN VIVO"; mono: true; size: Theme.taller.caption; color: Theme.textDim; Layout.fillWidth: true }
        Repeater {
            model: [{label:"Todo",value:"all"},{label:"Errores",value:"error"},{label:"Avisos",value:"warn"}]
            TallerButton { required property var modelData; label: modelData.label; primary: root.level === modelData.value; onClicked: root.level = modelData.value }
        }
        TallerInput { id: search; Layout.preferredWidth: Theme.taller.stateWidth; placeholder: "Filtrar texto…" }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.taller.output
        radius: Theme.taller.buttonRadius
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Theme.taller.inset
            clip: true
            model: root.filtered
            onCountChanged: if (root.follow) Qt.callLater(() => list.positionViewAtEnd())
            onMovementEnded: root.follow = atYEnd
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: Math.max(Theme.taller.logLineHeight, message.implicitHeight + Theme.taller.thinGap)
                radius: Theme.taller.badgeRadius
                color: modelData.level === "error" ? Theme.diffDel : Theme.transparent
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.taller.smallGap
                    anchors.rightMargin: Theme.taller.smallGap
                    spacing: Theme.taller.smallGap
                    UiText { Layout.preferredWidth: Theme.taller.logTimeWidth; text: modelData.ts?.split("T")[1]?.slice(0,8) || "—"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                    UiText { Layout.preferredWidth: Theme.taller.logLevelWidth; text: modelData.level?.toUpperCase() ?? "INFO"; mono: true; size: Theme.taller.caption; color: modelData.level === "error" ? Theme.danger : modelData.level === "warn" ? Theme.warn : Theme.textDim }
                    UiText { id: message; Layout.fillWidth: true; text: modelData.msg ?? ""; mono: true; size: Theme.taller.mono; color: modelData.level === "error" ? Theme.danger : Theme.textSoft; wrapMode: Text.WrapAnywhere; maximumLineCount: 200 }
                    UiText { Layout.preferredWidth: Theme.taller.logCountWidth; text: modelData.count > 1 ? "×" + modelData.count : ""; mono: true; size: Theme.taller.caption; color: Theme.danger }
                }
            }
            UiText { anchors.centerIn: parent; visible: list.count === 0; text: "Sin líneas para este filtro"; size: Theme.taller.body; color: Theme.textDim }
        }
    }
}
