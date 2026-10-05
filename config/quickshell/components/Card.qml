// Card inside panels: surface1, radius 18, column content
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property real padding: Theme.cardPad
    property alias spacing: body.spacing
    default property alias content: body.data

    color: Theme.surface1
    radius: Theme.cardRadius
    implicitWidth: body.implicitWidth + padding * 2
    implicitHeight: body.implicitHeight + padding * 2

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Theme.spacingSm
    }
}
