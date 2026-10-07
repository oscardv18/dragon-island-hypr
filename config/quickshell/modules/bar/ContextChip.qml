// One contextual capsule of the right island. A fixed slot per kind: it grows in (width + opacity) when its
// entry appears and shrinks away when it goes, instead of popping in and out.
import QtQuick
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property var entry: null          // BarContext entry, null when not relevant
    property bool wanted: true        // false when the bar has no room: the entry is grouped into "+N"
    property var last: null           // last non-null entry, kept while the chip fades out
    readonly property bool shown: entry !== null && wanted
    readonly property real fullWidth: row.implicitWidth + Theme.capsulePadH * 2 - 2
    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    onEntryChanged: if (entry) last = entry

    implicitHeight: Theme.capsuleHeight
    width: shown ? fullWidth : 0
    opacity: shown ? 1 : 0
    visible: width > 0.5
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.durPill } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.capsuleRadius
        color: root.hovered ? Theme.surfaceHi : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.capsuleGap - 2

        Glyph {
            id: glyph
            shadow: true
            anchors.verticalCenter: parent.verticalCenter
            visible: !(root.last?.parts)
            icon: root.last?.icon ?? ""
            size: Theme.iconSm + 1
            color: root.last?.color ?? Theme.text
            // recording: a steady pulse
            SequentialAnimation on opacity {
                running: root.shown && (root.last?.pulse ?? false) && Theme.animationsEnabled
                loops: Animation.Infinite
                onStopped: glyph.opacity = 1
                NumberAnimation { to: 0.35; duration: Theme.ms(700); easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: Theme.ms(700); easing.type: Easing.InOutSine }
            }
        }
        // entries with `parts` (agents): a coloured icon + count per state
        Repeater {
            model: root.last?.parts ?? []
            delegate: Row {
                id: part
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Glyph {
                    id: partGlyph
                    shadow: true
                    anchors.verticalCenter: parent.verticalCenter
                    icon: part.modelData.icon
                    size: Theme.iconSm
                    color: part.modelData.color
                    SequentialAnimation on opacity {
                        running: root.shown && (part.modelData.pulse === true || part.modelData.breathe === true) && Theme.animationsEnabled
                        loops: Animation.Infinite
                        onStopped: partGlyph.opacity = 1
                        NumberAnimation { to: part.modelData.pulse ? 0.3 : 0.65; duration: Theme.ms(part.modelData.pulse ? 600 : 1400); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Theme.ms(part.modelData.pulse ? 600 : 1400); easing.type: Easing.InOutSine }
                    }
                }
                UiText {
                    shadow: true
                    anchors.verticalCenter: parent.verticalCenter
                    text: part.modelData.text
                    mono: true
                    size: Theme.sizeBar
                    color: part.modelData.color
                }
            }
        }
        UiText {
            shadow: true
            visible: text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.last?.text ?? ""
            mono: true
            size: Theme.sizeBar
            color: root.last?.color ?? Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
