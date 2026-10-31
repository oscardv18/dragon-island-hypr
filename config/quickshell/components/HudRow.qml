// A list row of the HUD panels: fixed height (Theme.hudRow), faint fill, hover; `title` + optional mono caption
// `detail` under it; trailing content via the default property. Click → clicked().
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property string title: ""
    property string detail: ""
    property color titleColor: Theme.text
    property bool selected: false
    property bool clickable: true
    default property alias trailing: trail.data
    property alias leading: lead.data
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: detail.length > 0 ? Theme.hudRow + 8 : Theme.hudRow
    radius: Theme.hudCardRadius - 2
    color: selected ? Theme.alpha(Theme.cyan, 0.06) : (mouse.containsMouse && clickable ? Theme.hudRowHover : Theme.hudRowFill)
    border.width: selected ? 1 : 0
    border.color: Theme.alpha(Theme.cyan, 0.35)
    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: root.clickable; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        spacing: Theme.spacingMd
        Row { id: lead; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter; visible: children.length > 0 }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            UiText { Layout.fillWidth: true; text: root.title; color: root.titleColor; weight: Theme.weightMedium }
            HudCaption { Layout.fillWidth: true; visible: root.detail.length > 0; text: root.detail }
        }
        Row { id: trail; spacing: Theme.spacingSm; Layout.alignment: Qt.AlignVCenter }
    }
}
