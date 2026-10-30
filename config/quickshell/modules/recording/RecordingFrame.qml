// =============================================================================
// dragon-island — RecordingFrame.qml (namespace "dragon-recframe", Overlay)
// The recording mode's frame: a 2 px alpha(error, .75) border around the screen while RecordingMode.showFrame.
// No input at all (empty mask), no blur, unmapped otherwise.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    visible: RecordingMode.showFrame
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-recframe"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.transparent
        border.width: 2
        border.color: Theme.alpha(Theme.error, 0.75)
    }
}
