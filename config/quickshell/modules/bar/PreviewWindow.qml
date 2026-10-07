// =============================================================================
// dragon-island — PreviewWindow.qml (window "dragon-preview", PreviewWindow)
// Glass card under the left island with live-less thumbnails of the windows of the hovered workspace
// (ScreencopyView of each Toplevel, hyprland-toplevel-export). Click a thumbnail = focus that window.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property bool mine: WorkspacePreview.screenName === screenName
    readonly property bool open: WorkspacePreview.open && mine && !ShellState.anyOpen

    anchors { top: true; left: true }
    margins {
        top: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap
        left: Math.max(Theme.barMarginSide, Math.min(modelData.width - frame.width - Theme.barMarginSide, WorkspacePreview.anchorX - frame.width / 2))
    }
    implicitWidth: frame.width
    implicitHeight: frame.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    visible: open || lingering.running
    onOpenChanged: if (!open) lingering.restart()
    Timer { id: lingering; interval: Theme.durPopover + 200 }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HoverHandler {
        id: cardHover
        onHoveredChanged: if (hovered) WorkspacePreview.keep(); else WorkspacePreview.hide()
    }

    PopoverFrame {
        id: frame
        shown: win.open
        title: `Escritorio ${WorkspacePreview.wsId}`
        popWidth: Math.max(Theme.popoverWidthSm, thumbs.implicitWidth + Theme.popoverPad * 2)
        originX: width / 2

        RowLayout {
            id: thumbs
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Repeater {
                model: WorkspacePreview.windows.slice(0, 4)
                delegate: Item {
                    id: tile
                    required property var modelData
                    Layout.preferredWidth: Theme.previewThumbWidth
                    implicitHeight: Theme.previewThumbWidth * 9 / 16 + label.implicitHeight + Theme.spacingXs

                    Rectangle {
                        id: shot
                        width: parent.width
                        height: Theme.previewThumbWidth * 9 / 16
                        radius: Theme.rowRadius
                        color: Theme.surface2
                        border.width: tileMouse.containsMouse ? 2 : 0
                        border.color: Theme.accent

                        ScreencopyView {
                            anchors.fill: parent
                            anchors.margins: shot.border.width
                            captureSource: win.open ? tile.modelData.toplevel.wayland : null
                            live: false
                            constraintSize: Qt.size(width, height)
                        }
                        // while the frame is not there yet, the app icon
                        IconImageFallback { anchors.centerIn: parent; source: tile.modelData.icon }
                    }

                    UiText {
                        id: label
                        anchors.top: shot.bottom
                        anchors.topMargin: Theme.spacingXs
                        width: parent.width
                        text: tile.modelData.title || tile.modelData.appClass
                        size: Theme.sizeCaption + 1
                        color: Theme.textSoft
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Hypr.focusWindow(tile.modelData.address); WorkspacePreview.close(); }
                    }
                }
            }
        }
    }
}
