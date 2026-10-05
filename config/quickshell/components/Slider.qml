// Horizontal slider: icon (clickable, e.g. mute) · track with brand fill · value
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    property real value: 0           // 0.0 - 1.0, bound to a service
    property string icon: ""
    property bool showValue: true
    property bool dimmed: false      // e.g. muted
    readonly property bool dragging: area.pressed
    property real _drag: 0
    readonly property real shown: dragging ? _drag : Math.max(0, Math.min(1, value))

    signal moved(real value)
    signal iconClicked()

    implicitHeight: Theme.sliderHeight
    implicitWidth: Theme.popoverWidthSm
    opacity: enabled ? 1 : 0.45

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingSm

        Glyph {
            visible: root.icon.length > 0
            icon: root.icon
            size: Theme.iconLg
            color: root.dimmed ? Theme.textDim : Theme.textSoft
            Layout.preferredWidth: Theme.iconLg + Theme.spacingXs
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Theme.trackHeight
                radius: height / 2
                color: Theme.surface3
            }

            BrandFill {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(height, track.width * root.shown)
                height: Theme.trackHeight
                radius: height / 2
                opacity: root.dimmed ? 0.4 : 1
            }

            Rectangle {
                width: Theme.knobSize
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, track.width * root.shown - width / 2))
                color: Theme.onBrand
                scale: area.pressed || area.containsMouse ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.durHover } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled
                preventStealing: true
                function update(x) {
                    root._drag = Math.max(0, Math.min(1, x / track.width));
                    root.moved(root._drag);
                }
                onPressed: m => update(m.x)
                onPositionChanged: m => { if (pressed) update(m.x); }
                onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }

        UiText {
            visible: root.showValue
            Layout.preferredWidth: Theme.sizeBody * 2.4
            horizontalAlignment: Text.AlignRight
            mono: true
            size: Theme.sizeCaption
            color: Theme.textSoft
            text: `${Math.round(root.shown * 100)}`
        }
    }
}
