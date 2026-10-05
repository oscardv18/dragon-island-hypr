// On/off switch: brand gradient when on
import QtQuick
import ".."

Item {
    id: root
    property bool checked: false
    signal toggled()

    implicitWidth: Theme.switchWidth
    implicitHeight: Theme.switchHeight
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface3
        visible: !root.checked
    }

    BrandFill {
        anchors.fill: parent
        radius: height / 2
        visible: root.checked
    }

    Rectangle {
        width: root.height - Theme.knobInset * 2
        height: width
        radius: width / 2
        y: Theme.knobInset
        x: root.checked ? root.width - width - Theme.knobInset : Theme.knobInset
        color: root.checked ? Theme.onBrand : Theme.textDim
        Behavior on x { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.toggled()
    }
}
