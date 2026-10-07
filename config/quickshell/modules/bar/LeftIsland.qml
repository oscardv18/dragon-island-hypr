// Left island: launcher button · workspace pills 1–5 (app icons, hover preview) · submap · divider · active window
// (icon, class, title; on hover the title turns into actions: close, float, pin, move to a workspace)
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var bar
    property real windowX: 0     // screen x of this island's window

    // popovers of the left island: left edge on the capsule's left edge
    function openPopover(name: string, item): void { bar.openFrom(name, item, "left", windowX); }
    property real maxWidth: 0

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: Math.min(row.implicitWidth + Theme.barIslandPadH * 2, maxWidth)
    radius: Theme.barIslandRadius
    color: Theme.glassBg
    border.width: 1
    border.color: Theme.glassBorder
    clip: true

    readonly property real fixedWidth: launcher.width + workspaces.width + submapChip.width + divider.width + row.spacing * 4

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
                shadow: true
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
                delegate: WorkspacePill { islandX: root.windowX; screenName: root.bar.screenName }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => Hypr.focusRelative(e.angleDelta.y > 0 ? -1 : 1)
            }
        }

        // active submap (Hyprland `submap` event), only while there is one
        Rectangle {
            id: submapChip
            readonly property bool shown: Hypr.submap.length > 0
            property string last: ""
            onShownChanged: if (shown) last = Hypr.submap
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.capsuleHeight - 4
            radius: Theme.capsuleRadius - 2
            color: Theme.alpha(Theme.accent, 0.25)
            border.width: 1
            border.color: Theme.alpha(Theme.accent, 0.6)
            width: shown ? submapRow.implicitWidth + Theme.spacingMd : 0
            opacity: shown ? 1 : 0
            visible: width > 0.5
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durPill } }
            Connections { target: Hypr; function onSubmapChanged() { if (Hypr.submap.length > 0) submapChip.last = Hypr.submap; } }
            Row {
                id: submapRow
                anchors.centerIn: parent
                spacing: Theme.spacingXs
                Glyph { shadow: true; anchors.verticalCenter: parent.verticalCenter; icon: Icons.keyboard; size: Theme.iconSm; color: Theme.accent }
                UiText { shadow: true; anchors.verticalCenter: parent.verticalCenter; text: submapChip.last; mono: true; size: Theme.sizeCaption + 1; weight: Theme.weightSemiBold }
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

                shadow: true
                id: appClass
                anchors.verticalCenter: parent.verticalCenter
                text: Hypr.activeClass
                size: Theme.sizeBar
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, activeWindow.available * 0.4)
            }

            // title ↔ actions: the title turns into window actions while the pointer is over the active window
            Item {
                id: titleBox
                readonly property bool actions: windowHover.hovered
                readonly property real titleWidth: Math.max(0, Math.min(titleText.implicitWidth, activeWindow.available - appClass.width - Theme.iconMd - Theme.capsuleGap * 2))
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.capsuleHeight
                width: actions ? actionsRow.implicitWidth : titleWidth
                clip: true
                Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }

                UiText {
                    id: titleText
                    shadow: true
                    anchors.verticalCenter: parent.verticalCenter
                    text: Hypr.activeTitle
                    size: Theme.sizeBar
                    color: Theme.textDim
                    width: titleBox.titleWidth
                    opacity: titleBox.actions ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
                }

                Row {
                    id: actionsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXs
                    opacity: titleBox.actions ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }

                    component ActionButton: Rectangle {
                        id: ab
                        property string icon: ""
                        property color tint: Theme.textSoft
                        property bool on: false
                        signal clicked()
                        width: 22
                        height: 22
                        radius: Theme.capsuleRadius - 3
                        color: abMouse.containsMouse ? Theme.surfaceHi : (on ? Theme.alpha(Theme.accent, 0.3) : Theme.surface2)
                        Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        Glyph { anchors.centerIn: parent; icon: ab.icon; size: Theme.iconSm; color: abMouse.containsMouse ? Theme.text : ab.tint }
                        MouseArea { id: abMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ab.clicked() }
                    }

                    ActionButton { icon: Icons.close; tint: Theme.error; onClicked: Hypr.closeActiveWindow() }
                    ActionButton { icon: Icons.windowFloat; on: Hypr.activeFloating; onClicked: Hypr.toggleFloat() }
                    ActionButton { visible: Hypr.activeFloating; icon: Hypr.activePinned ? Icons.pinOff : Icons.pin; on: Hypr.activePinned; onClicked: Hypr.togglePin() }

                    Rectangle { width: 1; height: Theme.dividerHeight - 4; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

                    // move to a workspace
                    Repeater {
                        model: Hypr.workspaceCount
                        delegate: Rectangle {
                            required property int index
                            readonly property int wsId: index + 1
                            visible: wsId !== Hypr.focusedWorkspaceId
                            width: visible ? 22 : 0
                            height: 22
                            radius: Theme.capsuleRadius - 3
                            color: moveMouse.containsMouse ? Theme.accent : Theme.surface2
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                            UiText { anchors.centerIn: parent; text: `${wsId}`; mono: true; size: Theme.sizeCaption; weight: Theme.weightSemiBold; color: moveMouse.containsMouse ? Theme.onBrand : Theme.textSoft }
                            MouseArea { id: moveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Hypr.moveWindowToWorkspace(wsId) }
                        }
                    }
                }
            }

            HoverHandler { id: windowHover }
        }
    }
}
