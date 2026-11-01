// Overlay with one alpha shape; unmapped and unloaded while closed. ScrimWindow owns the backdrop.
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win
    property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    WlrLayershell.namespace: "dragon-taller"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool open: ShellState.isOpenOn("taller", modelData?.name ?? "")
    visible: open || linger.running
    Timer { id: linger; interval: Theme.durOut }
    onOpenChanged: { if (!open) linger.restart(); else Qt.callLater(() => { if (panel.item) panel.item.forceActiveFocus(); }); }
    MouseArea { anchors.fill: parent; onClicked: ShellState.close() }
    Loader {
        id: panel
        active: win.visible
        anchors.centerIn: parent
        width: Math.min(Theme.taller.width, win.width - Theme.taller.gap * 2)
        height: Math.min(Theme.taller.height, win.height - Theme.taller.gap * 2)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
        sourceComponent: TallerPanel {
            shown: win.open
            agentService: Herdr
            memService: Mem
            dockerService: Docker
            tab: Taller.tab
            onTabRequested: name => Taller.tab = name
            onCloseRequested: ShellState.close()
        }
    }
}
