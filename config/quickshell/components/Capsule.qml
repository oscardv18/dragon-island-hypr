// Bar capsule: height 28, radius 9, padding 0 10, gap 6. Hover/open → surfaceHi (120 ms).
import QtQuick
import ".."

Item {
    id: root

    property bool active: false     // its popover is open
    property bool brand: false      // brand gradient background (clock)
    property bool flat: false       // no background until hovered (inside a grouped capsule)
    property real padH: Theme.capsulePadH
    property real radius: Theme.capsuleRadius
    default property alias content: row.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal wheel(real delta)

    implicitHeight: Theme.capsuleHeight
    implicitWidth: row.implicitWidth + padH * 2

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !root.brand
        color: root.active || root.hovered ? Theme.surfaceHi : (root.flat ? Theme.transparent : Theme.surface2)
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    BrandFill {
        anchors.fill: parent
        radius: root.radius
        visible: root.brand
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.brand
        color: Theme.hoverOverlay
        opacity: root.hovered || root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.capsuleGap
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
