// 4-bar equalizer for "now playing" (animated only while playing)
import QtQuick
import ".."

Row {
    id: root
    property bool playing: false
    property color color: Theme.accent
    property real barHeight: Theme.iconMd

    spacing: Theme.eqGap
    height: barHeight

    Repeater {
        model: 4
        delegate: Rectangle {
            id: bar
            required property int index
            width: Theme.eqBar
            radius: width / 2
            color: root.color
            anchors.bottom: parent.bottom
            property real level: 0.35
            height: Math.max(width, root.barHeight * level)

            SequentialAnimation on level {
                running: root.playing
                loops: Animation.Infinite
                NumberAnimation { to: 1.0;  duration: Theme.ms(260 + bar.index * 70); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.25; duration: Theme.ms(300 + bar.index * 50); easing.type: Easing.InOutSine }
            }
            states: State {
                when: !root.playing
                PropertyChanges { bar.level: 0.35 }
            }
        }
    }
}
