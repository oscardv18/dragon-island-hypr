// One row of the Ajustes panel: title + subtitle on the left, the control (default property) on the right,
// a hairline under it unless `last`.
import QtQuick
import "../.."
import "../../components"

Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property bool last: false
    default property alias control: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + Theme.spacingLg * 2

    Column {
        id: texts
        x: Theme.spacingLg + 4
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - slot.width - Theme.spacingLg * 2
        spacing: 2
        UiText { width: parent.width; text: root.title; size: Theme.sizeBodyLg; weight: Theme.weightMedium }
        UiText { width: parent.width; text: root.subtitle; color: Theme.textDim; visible: text.length > 0 }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingLg + 4
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle {
        visible: !root.last
        anchors.bottom: parent.bottom
        x: 1
        width: parent.width - 2
        height: 1
        color: Theme.hairline
    }
}
