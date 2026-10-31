// Bar capsule: height 28, radius 9, padding 0 10, gap 6. Hover → white 8 %, open → a cyan halo while its popover is
// open (the HUD popovers start with a beam from here, docs/design/28-emergentes.png).
import QtQuick
import QtQuick.Effects
import ".."

Item {
    id: root

    property bool active: false     // its popover is open
    property bool brand: false      // neutral white 6 % background (clock); the brand gradient is no longer a fill
    property bool flat: false       // no background until hovered (inside a grouped capsule)
    property real padH: Theme.capsulePadH
    property real radius: Theme.capsuleRadius
    default property alias content: row.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal wheel(real delta)

    implicitHeight: Theme.barCapsuleHeight
    implicitWidth: row.implicitWidth + padH * 2

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.brand ? Theme.neutralFill : (root.flat ? Theme.transparent : Theme.surface2)
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.hoverOverlay
        opacity: root.hovered && !root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
    }

    // open: cyan halo + tint + 1 px cyan edge
    RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        blur: Theme.hudBeamGlow
        color: Theme.haloCyan
        opacity: root.active ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.alpha(Theme.cyan, 0.14)
        border.width: 1
        border.color: Theme.alpha(Theme.cyan, 0.6)
        opacity: root.active ? 1 : 0
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
