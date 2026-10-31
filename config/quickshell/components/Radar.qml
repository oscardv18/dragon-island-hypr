// Scanning indicator (29-paneles-bluetooth «● BUSCANDO»): a cyan dot with a ring that expands and fades, once every
// 1.4 s, only while `running` (and never with reduced motion: then just the dot).
import QtQuick
import ".."
import "../services"

Item {
    id: root
    property bool running: false
    width: 18
    height: 18
    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: 6
        height: width
        radius: width / 2
        color: Theme.transparent
        border.width: 1
        border.color: Theme.cyan
        opacity: 0
        SequentialAnimation {
            running: root.running && root.visible && Theme.animationsEnabled && !Settings.calmMotion
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: ring; property: "width"; from: 6; to: 18; duration: Theme.ms(1100); easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: Theme.ms(1100) }
            }
            PauseAnimation { duration: Theme.ms(300) }
        }
    }
    Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.cyan }
}
