// Taller navigation only. tab: agentes|kanban|contenedores|git|revision; open/tab/close keep ShellState as authority.
// The future prompt composer is deliberately not sent anything by navigation.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root
    readonly property var tabs: ["agentes", "kanban", "contenedores", "git", "revision"]
    property string tab: "agentes"
    function init(): void {}
    function open(name): void {
        tab = tabs.indexOf(name) >= 0 ? name : "agentes";
        ShellState.open("taller", "");
        Mem.refresh();
    }
    function toggle(): void {
        if (ShellState.openPanel === "taller") ShellState.close(); else open(tab);
    }
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "taller") Mem.refresh();
            else Herdr.clearRead();
        }
    }
    IpcHandler {
        target: "taller"
        function toggle(): void { root.toggle(); }
        function open(tab: string): void { root.open(tab); }
        function close(): void { ShellState.close(); }
        function current(): string { return ShellState.openPanel === "taller" ? root.tab : "none"; }
    }
}
