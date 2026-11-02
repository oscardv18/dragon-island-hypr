// Kanban with WIP, gates and metrics (32-taller-kanban), the composer over it (32-taller-compositor) and the WIP prompt.
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/taller"
import "fixtures/taller5c.js" as Fx
Window {
    id: win
    visible: true
    width: Theme.taller.width
    height: Theme.taller.height
    color: Theme.bg
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    MockPrompts { id: prompts }
    MockMem { id: memory }
    MockGate { id: gate }
    QtObject { id: agents; property var agents: Fx.agents(Date.now()); property bool running: true; property string version: "0.9.5"; property var counts: ({ blocked: 1, done: 1, working: 1 }); property string readText: ""; property var _seen: ({}); function clearRead() {} function readAgent(a) {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "kanban"; agentService: agents; memService: memory; promptService: prompts; gateService: gate }
    function kanban() { for (const c of panel.children) { const k = find(c); if (k) return k; } return null; }
    function find(item) { if (item.hasOwnProperty("wip") && item.hasOwnProperty("pending")) return item; for (const c of item.children) { const k = find(c); if (k) return k; } return null; }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        onTriggered: {
            const k = win.kanban();
            if (step === 0) { k.select("AX-142"); }
            else if (step === 1) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-kanban.png"));
            else if (step === 2) { k.requestMove(memory.cards.find(c => c.key === "AX-148"), "doing", false); k.requestMove(memory.cards.find(c => c.key === "AX-150"), "doing", false); }
            else if (step === 3) { console.log("PENDING", JSON.stringify(k.pending)); panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-kanban-wip.png")); }
            else if (step === 4) { k.pending = null; k.select("AX-137"); k.requestMove(memory.cards.find(c => c.key === "AX-137"), "done", false); }
            else if (step === 5) { console.log("NOTICE", k.notice); panel.openComposer({ template: "revisar-cambios", card: "AX-142" }); }
            else if (step === 6) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-kanban-compositor.png"));
            else if (step === 7) { console.log("CALLS", JSON.stringify(memory.calls)); Qt.quit(); }
            step++;
        }
    }
}
