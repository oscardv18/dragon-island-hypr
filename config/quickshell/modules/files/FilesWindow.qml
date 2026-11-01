// One explorer window: a normal Hyprland window (FloatingWindow, several at once, no title bar), not an overlay.
// shell.qml creates one per Files.windows entry; closing it (Ctrl+W on the last tab, or the compositor) removes it.
// When the global window frame is on, the explorer does not draw its own (no double outline); with «nada» it does.
import Quickshell
import QtQuick
import "../.."
import "../../services"
import "files.js" as F

FloatingWindow {
    id: win
    required property var modelData
    title: "Archivos · " + F.displayPath(panel.tab?.path ?? "", Files.home)
    implicitWidth: Theme.files.width
    implicitHeight: Theme.files.height
    minimumSize: Qt.size(Theme.files.minWidth, Theme.files.minHeight)
    color: Theme.transparent
    property bool counted: false
    function _count(on): void { if (on !== counted) { counted = on; Files.windowShown(on); } }
    onVisibleChanged: _count(visible)
    Component.onCompleted: _count(visible)
    Component.onDestruction: _count(false)
    onClosed: Files.closeWindow(modelData.uid)
    Timer { id: clock; interval: 60000; running: win.visible; repeat: true; onTriggered: panel.now = Date.now() }
    FilesPanel {
        id: panel
        anchors.fill: parent
        files: Files
        ops: FileOps
        devices: Devices
        initialPath: win.modelData.path
        active: win.visible
        drawFrame: WindowFrame.mode === "nada"
        onCloseRequested: Files.closeWindow(win.modelData.uid)
    }
}
