// Prompt composer over the Taller with the review template (32-taller-compositor). Synthetic data, no services.
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
    QtObject { id: memory; property var project: Fx.project(); property var projects: [{}, {}, {}, {}]; property string selectedSlug: "arxnet-erp"; property string status: "ok" }
    QtObject { id: agents; property var agents: Fx.agents(Date.now()); property bool running: true; property string version: "0.9.5"; property var counts: ({ blocked: 1, done: 1, working: 1 }); property string readText: "Esperando aprobación para ejecutar npm test"; property string readId: "p-claude"; property var _seen: ({}); function clearRead() {} function readAgent(a) {} function focusAgent(a) {} function markSeen(a) {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "agentes"; agentService: agents; memService: memory; promptService: prompts }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        onTriggered: {
            if (step === 0) panel.openComposer({ template: "revisar-cambios", card: "AX-142" });
            else if (step === 1) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-compositor.png"));
            else if (step === 2) { prompts.result = Object.assign({}, prompts.result, { tokens: 2480, blocks: prompts.result.blocks.map((b, i) => Object.assign({}, b, { enabled: i !== 3 })) }); }
            else if (step === 3) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-compositor-pesado.png"));
            else if (step === 4) { console.log("OPEN", JSON.stringify(prompts.lastOpen)); Qt.quit(); }
            step++;
        }
    }
}
