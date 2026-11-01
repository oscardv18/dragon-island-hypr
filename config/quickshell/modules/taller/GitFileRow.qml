// Selection and staging are separate explicit actions. Space toggles the checkbox.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
Rectangle {
    id: root
    property var file: ({})
    property bool prepared: false
    property bool selected: false
    property bool busy: false
    signal chosen()
    signal stageRequested(bool value)
    implicitHeight: Theme.taller.inputHeight
    radius: Theme.taller.buttonRadius
    color: selected ? Theme.taller.selected : Theme.taller.card
    border.width: selected ? Theme.taller.buttonBorder : 0
    border.color: Theme.taller.selectedBorder
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.taller.rowGap
        anchors.rightMargin: Theme.taller.rowGap
        spacing: Theme.taller.rowGap
        Rectangle {
            implicitWidth: Theme.taller.checkSize
            implicitHeight: width
            radius: Theme.taller.thinGap
            color: root.prepared ? Theme.ok : Theme.transparent
            border.width: Theme.taller.buttonBorder
            border.color: root.prepared ? Theme.ok : Theme.textDim
            activeFocusOnTab: true
            Keys.onSpacePressed: if (!root.busy) root.stageRequested(!root.prepared)
            UiText { anchors.centerIn: parent; text: root.prepared ? "✓" : ""; size: Theme.taller.caption; color: Theme.islandInk }
            MouseArea { anchors.fill: parent; enabled: !root.busy; onClicked: root.stageRequested(!root.prepared) }
        }
        UiText { text: root.file.status ?? ""; mono: true; size: Theme.taller.caption; color: root.file.status === "D" ? Theme.danger : root.file.status === "A" || root.file.status === "?" ? Theme.ok : Theme.warn }
        UiText { Layout.fillWidth: true; text: root.file.path ?? ""; mono: true; size: Theme.taller.mono; MouseArea { anchors.fill: parent; onClicked: root.chosen() } }
        UiText { text: `+${root.file.add ?? 0} −${root.file.del ?? 0}`; mono: true; size: Theme.taller.caption; color: Theme.textDim }
    }
    TapHandler { onTapped: root.chosen() }
}
