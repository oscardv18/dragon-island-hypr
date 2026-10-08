// One app of the "apps in the background" island: icon + status dot (+ workspace miniature). Pure visual: it gets a
// plain `entry` (see services/BackgroundApps.qml) and two icon sources, and only emits signals.
//   status dot: green = Active, grey = Passive, red = NeedsAttention (pulses). No tray item → no dot (nothing is invented).
//   tray only (no window) → dimmed icon · window elsewhere → workspace number in a small badge.
import QtQuick
import "../.."

Item {
    id: root

    property var entry: null
    property string iconSource: ""
    property string fallbackSource: ""
    property bool open: false                  // its menu / popover is open
    readonly property bool hovered: mouse.containsMouse
    property bool iconFailed: false
    onIconSourceChanged: iconFailed = false

    signal activated()
    signal secondary()
    signal context()
    signal scrolled(int dx, int dy)

    readonly property bool trayOnly: (entry?.windows?.length ?? 0) === 0
    readonly property color dotColor: entry?.status === "attention" ? Theme.error : (entry?.status === "active" ? Theme.ok : Theme.textDim)

    width: Theme.bottomChip
    height: Theme.bottomChip

    Rectangle {
        anchors.fill: parent
        radius: Theme.capsuleRadius
        color: root.open || root.hovered ? Theme.surfaceHi : Theme.surface2
        border.width: root.entry?.vpn === "on" ? 1.5 : 0      // Proton VPN adapter: connected
        border.color: Theme.ok
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    Image {
        id: icon
        anchors.centerIn: parent
        width: Theme.bottomChip - 8
        height: width
        source: root.iconFailed ? root.fallbackSource : root.iconSource
        sourceSize: Qt.size(48, 48)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        mipmap: true
        opacity: root.trayOnly ? 0.55 : 1
        onStatusChanged: if (status === Image.Error && !root.iconFailed) root.iconFailed = true
    }

    // workspace of the window that lives elsewhere
    Rectangle {
        visible: !root.trayOnly && (root.entry?.wsShort ?? "") !== ""
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -3
        anchors.topMargin: -3
        width: Math.max(13, wsText.implicitWidth + 6)
        height: 13
        radius: 6
        color: Theme.surface0
        border.width: 1
        border.color: Theme.glassBorder
        Text {
            id: wsText
            anchors.centerIn: parent
            text: root.entry?.wsShort ?? ""
            color: Theme.textSoft
            font.family: Theme.fontMono
            font.pixelSize: 9
            textFormat: Text.PlainText
        }
    }

    // tray status
    Rectangle {
        id: dot
        visible: (root.entry?.status ?? "none") !== "none"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -1
        anchors.bottomMargin: -1
        width: 8
        height: 8
        radius: 4
        color: root.dotColor
        border.width: 1
        border.color: Theme.surface0
        SequentialAnimation on opacity {
            running: root.entry?.status === "attention" && root.visible && Theme.animationsEnabled
            loops: Animation.Infinite
            onStopped: dot.opacity = 1
            NumberAnimation { to: 0.35; duration: Theme.ms(700); easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: Theme.ms(700); easing.type: Easing.InOutSine }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.RightButton) root.context();
            else if (m.button === Qt.MiddleButton) root.secondary();
            else root.activated();
        }
        onWheel: w => root.scrolled(w.angleDelta.x, w.angleDelta.y)
    }
}
