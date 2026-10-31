// Radio indicator of the HUD lists (29-paneles-sonido: the chosen output / microphone): a ring, filled cyan when checked.
import QtQuick
import ".."

Rectangle {
    property bool checked: false
    width: 16
    height: 16
    radius: 8
    color: Theme.transparent
    border.width: 1.5
    border.color: checked ? Theme.cyan : Theme.alpha(Theme.text, 0.35)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: Theme.cyan
        visible: parent.checked
    }
}
