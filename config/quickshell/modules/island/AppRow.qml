// One app of the dashboard's Apps tab: icon with tray-status dot · name + state line · buttons (tray menu, close window).
// Pure visual: plain `entry` (see services/BackgroundApps.qml) in, signals out.
//   status dot: green = Active, grey = Passive, red = NeedsAttention (pulses). No tray item → no dot (nothing is invented).
//   Proton VPN adapter: green ring while connected.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root

    property var entry: null
    property string iconSource: ""
    property string fallbackSource: ""
    property string stateText: ""
    property bool menuOpen: false
    property bool iconFailed: false
    onIconSourceChanged: iconFailed = false
    readonly property bool canClose: (entry?.windows?.length ?? 0) > 0
    readonly property bool canMenu: entry?.trayItem?.hasMenu ?? false

    signal activated()
    signal secondary()
    signal closeRequested()
    signal menuRequested()
    signal scrolled(int dx, int dy)

    height: 48
    radius: Theme.tileRadius - 4
    color: mouse.containsMouse || root.menuOpen ? Theme.surfaceHi : Theme.surface2
    border.width: root.entry?.vpn === "on" ? 1.5 : 0
    border.color: Theme.ok
    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) root.menuRequested();
            else if (m.button === Qt.MiddleButton) root.secondary();
            else root.activated();
        }
        onWheel: w => root.scrolled(w.angleDelta.x, w.angleDelta.y)
    }

    Item {
        id: iconBox
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        Image {
            anchors.fill: parent
            source: root.iconFailed ? root.fallbackSource : root.iconSource
            sourceSize: Qt.size(60, 60)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
            opacity: (root.entry?.windows?.length ?? 0) === 0 ? 0.6 : 1
            onStatusChanged: if (status === Image.Error && !root.iconFailed) root.iconFailed = true
        }
        Rectangle {
            id: dot
            visible: (root.entry?.status ?? "none") !== "none"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2
            anchors.bottomMargin: -2
            width: 9
            height: 9
            radius: 4.5
            color: root.entry?.status === "attention" ? Theme.error : (root.entry?.status === "active" ? Theme.ok : Theme.textDim)
            border.width: 1
            border.color: Theme.surface2
            SequentialAnimation on opacity {
                running: root.entry?.status === "attention" && root.visible && Theme.animationsEnabled
                loops: Animation.Infinite
                onStopped: dot.opacity = 1
                NumberAnimation { to: 0.35; duration: Theme.ms(700); easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: Theme.ms(700); easing.type: Easing.InOutSine }
            }
        }
    }

    Column {
        x: iconBox.x + iconBox.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - buttons.width - 14
        UiText { width: parent.width; text: root.entry?.label ?? ""; size: Theme.sizeBody; weight: Theme.weightSemiBold }
        UiText { width: parent.width; text: root.stateText; size: Theme.sizeCaption + 1; color: Theme.textDim }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        IconButton {
            visible: root.canMenu
            icon: Icons.dots
            size: 28
            iconSize: Theme.iconMd
            radius: 14
            bgColor: Theme.transparent
            iconColor: Theme.textSoft
            onClicked: root.menuRequested()
        }
        IconButton {
            visible: root.canClose
            icon: Icons.close
            size: 28
            iconSize: Theme.iconMd
            radius: 14
            bgColor: Theme.transparent
            iconColor: Theme.textSoft
            onClicked: root.closeRequested()
        }
    }
}
