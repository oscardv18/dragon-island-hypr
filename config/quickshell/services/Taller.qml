// Taller navigation only. tab: agentes|kanban|contenedores|git|revision; open/tab/close keep ShellState as authority.
// openComposer(opts) opens the Taller (keeping its tab) with the prompt composer; nothing is sent by navigation.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root
    readonly property var tabs: ["agentes", "kanban", "contenedores", "git", "revision"]
    property string tab: "agentes"
    readonly property bool dockerActive: ShellState.openPanel === "taller" && tab === "contenedores"
    onDockerActiveChanged: Docker.activate(dockerActive)
    readonly property bool gitActive: ShellState.openPanel === "taller" && tab === "git"
    readonly property string gitRepo: Mem.project?.path ?? ""
    onGitActiveChanged: Git.activate(gitActive,gitRepo)
    onGitRepoChanged: Git.activate(gitActive,gitRepo)
    readonly property bool kanbanActive: ShellState.openPanel === "taller" && tab === "kanban"
    onKanbanActiveChanged: if (kanbanActive) Mem.refreshBoard()
    readonly property bool reviewActive: ShellState.openPanel === "taller" && tab === "revision"
    onReviewActiveChanged: Review.activate(reviewActive)
    function openReview(key): void { if (key) Review.setCard(key); tab = "revision"; }
    function init(): void {}
    function open(name): void {
        tab = tabs.indexOf(name) >= 0 ? name : "agentes";
        ShellState.open("taller", "");
        Mem.refresh();
    }
    function openComposer(opts): void {
        if (ShellState.openPanel !== "taller") open(tab);
        Prompts.open(opts ?? {});
    }
    function toggle(): void {
        if (ShellState.openPanel === "taller") ShellState.close(); else open(tab);
    }
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "taller") Mem.refresh();
            else { Herdr.clearRead(); Prompts.close(); }
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
