// Small button of the HUD panels (29-paneles: «Compartir con QR», «Olvidar», «Desconectar», «+ Evento»):
// a pill with a faint fill and edge; `tone` colours the label (warn for destructive actions), `active` tints it cyan.
import QtQuick
import ".."

Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property color tone: Theme.text
    property bool active: false
    signal clicked()

    implicitHeight: Theme.hudChip
    implicitWidth: row.implicitWidth + Theme.spacingMd * 2
    radius: height / 2
    color: active ? Theme.alpha(Theme.cyan, 0.12) : (mouse.containsMouse ? Theme.hudRowHover : Theme.hudRowFill)
    border.width: 1
    border.color: active ? Theme.alpha(Theme.cyan, 0.45) : Theme.hudCardEdge
    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingXs
        Glyph { visible: root.icon.length > 0; icon: root.icon; size: Theme.iconSm; color: root.tone; anchors.verticalCenter: parent.verticalCenter }
        UiText { text: root.label; size: Theme.sizeCaption + 1.5; weight: Theme.weightMedium; color: root.tone; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
