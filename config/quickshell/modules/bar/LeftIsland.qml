// Left island (docs/design/19-islas.png, componente-lados.png), left to right:
//   core button  a 22 px circle (white 5 %) with a compact NeuralCore ("calm", "listening" while hovered):
//                click = launcher, right click = dashboard (as the old launcher button)
//   constellation of workspaces (Constellation.qml: planet travels, hover preview, wheel)
//   submap       only while there is one
//   live context app icon · friendly name or repository · chip (git branch / "N sin leer") from WindowContext;
//                hovering it turns the name + chip into the window actions (close, float, pin, move to a workspace)
// Style D (minimal): only the constellation. Style C (bare): no box, it sits inside the joined strip.
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var bar
    property real windowX: 0     // screen x of this island's window
    property bool live: true     // its window is mapped (false: the core does not animate)

    // popovers of the left island: left edge on the capsule's left edge
    function openPopover(name: string, item): void { bar.openFrom(name, item, "left", windowX); }
    property real maxWidth: 0

    property bool bare: false            // C: drawn inside the joined strip, no box of its own
    readonly property bool minimal: Theme.barLook === "D"   // D: only the constellation

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: Math.min(row.implicitWidth + padH * 2, maxWidth)
    radius: Theme.barIslandRadius
    color: bare ? Theme.transparent : Theme.glassBg
    border.width: bare ? 0 : 1
    border.color: Theme.glassBorder
    clip: true
    Behavior on height { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
    Behavior on opacity { NumberAnimation { duration: Theme.durStd } }

    readonly property real padH: minimal ? Theme.spacingSm : Theme.barIslandPadH
    readonly property real fixedWidth: core.width + constellation.width + submapChip.width + divider.width + row.spacing * 4

    // inner top highlight, white 6 % (clasico / liquido); the «ahumado» glass has its light edge instead
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        visible: !root.bare && !Theme.glassLight
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassHighlight }
            GradientStop { position: 0.5; color: Theme.transparent }
        }
    }
    GlassLight { cornerRadius: root.radius; visible: Theme.glassLight && !root.bare }

    Row {
        id: row
        x: root.padH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSm

        // ---- core button: replaces the gradient launcher button ----
        Rectangle {
            id: core
            visible: !root.minimal
            width: Theme.barCoreButton
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: coreMouse.containsMouse || root.bar.isOpen("launcher") ? Theme.hoverOverlay : Theme.coreButtonFill
            Behavior on color { ColorAnimation { duration: Theme.durHover } }

            NeuralCore {
                identity: Theme.coreIdentity
                anchors.fill: parent
                anchors.margins: 1
                mood: coreMouse.containsMouse ? "listening" : "calm"
                reducedMotion: !Theme.animationsEnabled
                running: core.visible && root.live && Theme.animationsEnabled
            }
            MouseArea {
                id: coreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => ShellState.toggle(m.button === Qt.RightButton ? "dashboard" : "launcher", root.bar.screenName)
            }
        }

        Constellation {
            id: constellation
            anchors.verticalCenter: parent.verticalCenter
            compact: root.minimal
            islandX: root.windowX
            screenName: root.bar.screenName
        }

        // active submap (Hyprland `submap` event), only while there is one
        Rectangle {
            id: submapChip
            readonly property bool shown: Hypr.submap.length > 0 && !root.minimal
            property string last: ""
            onShownChanged: if (shown) last = Hypr.submap
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.barCapsuleHeight - 2
            radius: height / 2
            color: Theme.accentTint
            border.width: 1
            border.color: Theme.accentEdge
            width: shown ? submapRow.implicitWidth + Theme.spacingMd : 0
            opacity: shown ? 1 : 0
            visible: width > 0.5
            clip: true
            Behavior on width { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
            Behavior on opacity { NumberAnimation { duration: Theme.durStd } }
            Connections { target: Hypr; function onSubmapChanged() { if (Hypr.submap.length > 0) submapChip.last = Hypr.submap; } }
            Row {
                id: submapRow
                anchors.centerIn: parent
                spacing: Theme.spacingXs
                Glyph { anchors.verticalCenter: parent.verticalCenter; icon: Icons.keyboard; size: Theme.iconSm - 2; color: Theme.lavender }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: submapChip.last; mono: true; size: Theme.sizeCaption; weight: Theme.weightSemiBold; color: Theme.lavenderInk }
            }
        }

        Rectangle {
            id: divider
            width: 1
            height: Theme.barHeight - 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.divider
            visible: Hypr.hasActiveWindow && !root.minimal
        }

        // ---- live context: icon · name · chip  ↔  window actions on hover ----
        Row {
            id: context
            visible: Hypr.hasActiveWindow && !root.minimal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSm
            readonly property real available: Math.max(0, root.maxWidth - root.padH * 2 - root.fixedWidth - Theme.spacingSm)
            readonly property bool actions: windowHover.hovered

            // recording mode with hidden titles: an eye crossed out instead of the app icon
            Glyph {
                visible: WindowContext.masked
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.eyeOff
                size: Theme.iconSm
                color: Theme.textDim
            }
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                source: WindowContext.icon
                implicitSize: Theme.iconMd - 2
                asynchronous: true
                visible: WindowContext.icon.length > 0
            }

            Item {
                id: swapBox
                // natural width from implicitWidth (never from the clipped widths: that loop shrank the name to its minimum)
                readonly property real chipSpace: chip.visible ? chip.width + Theme.spacingSm : 0
                readonly property real infoWidth: Math.min(nameText.implicitWidth + chipSpace, Math.max(0, context.available - Theme.iconMd - Theme.spacingSm))
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.barCapsuleHeight
                width: context.actions ? actionsRow.implicitWidth : infoWidth
                clip: true
                Behavior on width { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

                Row {
                    id: info
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingSm
                    opacity: context.actions ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }

                    UiText {
                        id: nameText
                        anchors.verticalCenter: parent.verticalCenter
                        text: WindowContext.title
                        size: Theme.sizeBar
                        weight: Theme.weightSemiBold
                        color: Theme.text
                        width: Math.min(implicitWidth, Math.max(40, swapBox.infoWidth - swapBox.chipSpace))
                    }

                    // chip: git branch · N unread
                    Rectangle {
                        id: chip
                        visible: WindowContext.chip.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: Theme.barCapsuleHeight - 4
                        radius: height / 2
                        color: Theme.neutralFill
                        width: chipRow.implicitWidth + Theme.spacingMd
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXs
                            Glyph {
                                visible: WindowContext.chipKind === "branch"
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons.branch
                                size: Theme.iconSm - 3
                                color: Theme.textDim
                            }
                            Rectangle {
                                visible: WindowContext.chipKind === "unread"
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5; height: 5; radius: 2.5
                                color: Theme.cyan
                            }
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: WindowContext.chip
                                mono: true
                                size: Theme.sizeCaption
                                color: Theme.textDim
                                width: Math.min(implicitWidth, 140)
                            }
                        }
                    }
                }

                Row {
                    id: actionsRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXs
                    opacity: context.actions ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }

                    component ActionButton: Rectangle {
                        id: ab
                        property string icon: ""
                        property color tint: Theme.textSoft
                        property bool on: false
                        signal clicked()
                        width: Theme.barCapsuleHeight
                        height: Theme.barCapsuleHeight
                        radius: height / 2
                        color: on ? Theme.accentTint : (abMouse.containsMouse ? Theme.hoverOverlay : Theme.transparent)
                        border.width: on ? 1 : 0
                        border.color: Theme.accentEdge
                        Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        Glyph { anchors.centerIn: parent; icon: ab.icon; size: Theme.iconSm - 1; color: ab.on ? Theme.lavenderInk : (abMouse.containsMouse ? Theme.text : ab.tint) }
                        MouseArea { id: abMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ab.clicked() }
                    }

                    ActionButton { icon: Icons.close; tint: Theme.error; onClicked: Hypr.closeActiveWindow() }
                    ActionButton { icon: Icons.windowFloat; on: Hypr.activeFloating; onClicked: Hypr.toggleFloat() }
                    ActionButton { visible: Hypr.activeFloating; icon: Hypr.activePinned ? Icons.pinOff : Icons.pin; on: Hypr.activePinned; onClicked: Hypr.togglePin() }

                    Rectangle { width: 1; height: Theme.barCapsuleHeight - 6; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }

                    // move to a workspace
                    Repeater {
                        model: Hypr.workspaceCount
                        delegate: Rectangle {
                            required property int index
                            readonly property int wsId: index + 1
                            visible: wsId !== Hypr.focusedWorkspaceId
                            width: visible ? Theme.barCapsuleHeight : 0
                            height: Theme.barCapsuleHeight
                            radius: height / 2
                            color: moveMouse.containsMouse ? Theme.accentTint : Theme.transparent
                            border.width: moveMouse.containsMouse ? 1 : 0
                            border.color: Theme.accentEdge
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                            UiText { anchors.centerIn: parent; text: `${wsId}`; mono: true; size: Theme.sizeCaption; weight: Theme.weightSemiBold; color: moveMouse.containsMouse ? Theme.lavenderInk : Theme.textSoft }
                            MouseArea { id: moveMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Hypr.moveWindowToWorkspace(wsId) }
                        }
                    }
                }
            }

            HoverHandler { id: windowHover }
        }
    }
}
