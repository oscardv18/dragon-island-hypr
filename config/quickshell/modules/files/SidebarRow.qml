// One row of the explorer sidebar: icon, label and an optional right part (count, ⏏, «abrir», status dot);
// `active` = the current tab shows this place. Also a drop target for files dragged from a list.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string badge: ""
    property color badgeColor: Theme.textDim
    property bool active: false
    property bool dropEnabled: false
    property real usage: -1             // 0…1 draws the device space bar under the label
    property color usageColor: Theme.cyan
    property alias trailing: trailingSlot.data
    signal clicked()
    signal rightClicked()
    signal dropped(var paths, int modifiers)
    implicitHeight: Theme.files.sidebarRow + (usage >= 0 ? Theme.files.thinGap * 2 : 0)
    radius: Theme.files.rowRadius
    color: drop.containsDrag ? Theme.files.dropTarget : active ? Theme.files.selected : hit.containsMouse ? Theme.files.hover : Theme.transparent
    border.width: active ? Theme.files.border : 0
    border.color: Theme.files.selectedBorder
    Glyph {
        id: glyph
        icon: root.icon
        size: Theme.files.sidebarIcon
        color: root.active ? Theme.cyan : Theme.textSoft
        anchors.left: parent.left
        anchors.leftMargin: Theme.files.inset
        anchors.verticalCenter: label.verticalCenter
    }
    UiText {
        id: label
        text: root.label
        size: Theme.files.body
        color: root.active ? Theme.text : Theme.textSoft
        anchors.left: glyph.right
        anchors.leftMargin: Theme.files.inset
        anchors.right: trailingSlot.left
        anchors.rightMargin: Theme.files.smallGap
        y: root.usage >= 0 ? Theme.files.smallGap : (root.height - height) / 2
    }
    Rectangle {
        visible: root.usage >= 0
        anchors.left: label.left
        anchors.right: parent.right
        anchors.rightMargin: Theme.files.inset
        anchors.top: label.bottom
        anchors.topMargin: Theme.files.thinGap
        height: Theme.files.thinGap
        radius: height / 2
        color: Theme.files.divider
        Rectangle { width: parent.width * Math.max(0, root.usage); height: parent.height; radius: parent.radius; color: root.usageColor }
    }
    Row {
        id: trailingSlot
        anchors.right: parent.right
        anchors.rightMargin: Theme.files.inset
        anchors.verticalCenter: label.verticalCenter
        spacing: Theme.files.smallGap
        UiText { visible: root.badge.length > 0; text: root.badge; mono: true; size: Theme.files.mono; color: root.badgeColor }
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => { if (e.button === Qt.RightButton) root.rightClicked(); else root.clicked(); }
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.dropEnabled
        keys: ["dragon-files"]
        onDropped: d => { root.dropped(d.source?.dragPaths ?? [], d.source?.dragModifiers ?? 0); d.accept(); }
    }
}
