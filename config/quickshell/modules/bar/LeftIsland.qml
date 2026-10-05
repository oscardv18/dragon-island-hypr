// Left island: launcher button · workspace pills 1–5 · divider · active window (icon, class, title)
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var bar
    property real maxWidth: 0

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: Math.min(row.implicitWidth + Theme.barIslandPadH * 2, maxWidth)
    radius: Theme.barIslandRadius
    color: Theme.barIsland
    border.width: 1
    border.color: Theme.hairline
    clip: true

    readonly property real fixedWidth: launcher.width + workspaces.width + divider.width + row.spacing * 3

    Row {
        id: row
        x: Theme.barIslandPadH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barIslandGap

        // Launcher button: 30×30, radius 9, brand gradient
        Item {
            id: launcher
            width: Theme.launcherButton
            height: Theme.launcherButton
            anchors.verticalCenter: parent.verticalCenter

            BrandFill {
                anchors.fill: parent
                radius: Theme.capsuleRadius
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.capsuleRadius
                color: Theme.hoverOverlay
                opacity: launcherMouse.containsMouse || root.bar.isOpen("launcher") ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
            }
            Glyph {
                anchors.centerIn: parent
                icon: Icons.apps
                size: Theme.iconMd
                color: Theme.onBrand
            }
            MouseArea {
                id: launcherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => ShellState.toggle(m.button === Qt.RightButton ? "dashboard" : "launcher", root.bar.screenName)
            }
        }

        // Workspace pills (scroll to move between existing workspaces)
        Row {
            id: workspaces
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXs

            Repeater {
                model: Hypr.workspaceCount
                delegate: WorkspacePill {}
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => Hypr.focusRelative(e.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Rectangle {
            id: divider
            width: 1
            height: Theme.dividerHeight
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
            visible: Hypr.hasActiveWindow
        }

        // Active window: app icon + class + title (dim)
        Row {
            id: activeWindow
            visible: Hypr.hasActiveWindow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.capsuleGap
            readonly property real available: Math.max(0, root.maxWidth - Theme.barIslandPadH * 2 - root.fixedWidth - Theme.capsulePadH)

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                source: Hypr.activeIcon
                implicitSize: Theme.iconMd
                asynchronous: true
                visible: Hypr.activeIcon.length > 0
            }

            UiText {
                id: appClass
                anchors.verticalCenter: parent.verticalCenter
                text: Hypr.activeClass
                size: Theme.sizeBar
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, activeWindow.available * 0.4)
            }

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: Hypr.activeTitle
                size: Theme.sizeBar
                color: Theme.textDim
                width: Math.max(0, Math.min(implicitWidth, activeWindow.available - appClass.width - Theme.iconMd - Theme.capsuleGap * 2))
            }
        }
    }
}
