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
    readonly property var picker: modelData.picker ?? null
    title: picker ? "Archivos · " + picker.title : "Archivos · " + F.displayPath(panel.tab?.path ?? "", Files.home)
    implicitWidth: Theme.files.width
    implicitHeight: Theme.files.height
    minimumSize: Qt.size(Theme.files.minWidth, Theme.files.minHeight)
    color: Theme.transparent
    property bool counted: false
    function _count(on): void { if (on !== counted) { counted = on; Files.windowShown(on); } }
    onVisibleChanged: _count(visible)
    Component.onCompleted: _count(visible)
    // a dialog of another app that goes away unanswered (compositor close, SUPER+Q) is a «cancel» for that app
    Component.onDestruction: { _count(false); if (picker) FilePicker.windowClosed(modelData.uid); }
    onClosed: { if (picker) FilePicker.windowClosed(modelData.uid); Files.closeWindow(modelData.uid); }
    Timer { id: clock; interval: 60000; running: win.visible; repeat: true; onTriggered: panel.now = Date.now() }
    FilesPanel {
        id: panel
        anchors.fill: parent
        files: Files
        ops: FileOps
        devices: Devices
        archives: Archives
        initialPath: win.modelData.path
        picker: win.picker
        active: win.visible
        drawFrame: WindowFrame.mode === "nada"
        onCloseRequested: { if (win.picker) panel.cancelPick(); else Files.closeWindow(win.modelData.uid); }
        onPickerResult: r => FilePicker.answer(win.modelData.uid, r)
    }
}
