// Segmented level bar of the HUD panels (docs/design/28-emergentes.png: RAM / GPU / TEMP, 29-paneles: signal,
// battery, volume): `segments` small rounded cells, lit up to `value`. `fill` (0 → 1, the frame's `filled`) lights
// them one after another after the rows have entered. `max` > 1 allows boost (volume up to 150 %: the cells past
// 100 % take `boostColor`). Interactive (`interactive: true`): click or drag sets the value → moved(v).
import QtQuick
import ".."

Item {
    id: root

    property real value: 0               // 0 .. max
    property real max: 1
    property int segments: Theme.hudSegments
    property color color: Theme.cyan
    property color boostColor: Theme.warn
    property real fill: 1                // 0 → 1: how much of the lit part is shown (opening)
    property real segHeight: Theme.hudSegHeight
    property bool interactive: false
    signal moved(real v)

    implicitHeight: segHeight
    implicitWidth: 200

    readonly property real _cell: (width - Theme.hudSegGap * (segments - 1)) / segments
    readonly property int _lit: Math.round(Math.max(0, Math.min(root.max, root.value)) / root.max * segments * Math.max(0, Math.min(1, root.fill)))
    readonly property int _full: Math.round(segments / root.max)   // index where 100 % ends (boost)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.hudSegGap
        Repeater {
            model: root.segments
            delegate: Rectangle {
                required property int index
                width: root._cell
                height: root.segHeight
                radius: Theme.hudSegRadius
                color: index < root._lit ? (root.max > 1 && index >= root._full ? root.boostColor : root.color) : Theme.hudSegOff
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        function _v(mx: real): real {
            const seg = Math.ceil(Math.max(0, Math.min(root.width, mx)) / (root._cell + Theme.hudSegGap));
            return Math.max(0, Math.min(root.segments, seg)) / root.segments * root.max;
        }
        onPressed: m => root.moved(_v(m.x))
        onPositionChanged: m => { if (pressed) root.moved(_v(m.x)); }
        onWheel: w => root.moved(Math.max(0, Math.min(root.max, root.value + (w.angleDelta.y > 0 ? 1 : -1) * root.max / root.segments)))
    }
}
