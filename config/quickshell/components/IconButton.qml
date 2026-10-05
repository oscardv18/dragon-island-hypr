// Square icon button, 44×44 touch target by default
import QtQuick
import ".."

Item {
    id: root

    property string icon: ""
    property real size: Theme.touchTarget
    property real iconSize: Theme.iconLg
    property real radius: Theme.rowRadius
    property color iconColor: Theme.text
    property color bgColor: Theme.surface2
    property color hoverColor: Theme.surfaceHi
    property bool brand: false
    property bool checked: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !root.brand && !root.checked
        color: root.hovered ? root.hoverColor : root.bgColor
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    BrandFill {
        anchors.fill: parent
        radius: root.radius
        visible: root.brand || root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.brand || root.checked
        color: Theme.hoverOverlay
        opacity: root.hovered ? 1 : 0
    }

    Glyph {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.brand || root.checked ? Theme.onBrand : root.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
