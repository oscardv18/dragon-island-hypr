// Thin progress / usage bar on a surface3 track
import QtQuick
import ".."

Item {
    id: root
    property real value: 0          // 0.0 - 1.0
    property color color: Theme.accent
    property bool brand: false
    property real thickness: Theme.trackHeight

    implicitHeight: thickness
    implicitWidth: Theme.popoverWidthSm / 3

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface3
    }

    Item {
        height: parent.height
        width: root.value > 0 ? Math.max(height, parent.width * Math.min(1, root.value)) : 0
        Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.color
            visible: !root.brand
        }
        BrandFill {
            anchors.fill: parent
            radius: height / 2
            visible: root.brand
        }
    }
}
