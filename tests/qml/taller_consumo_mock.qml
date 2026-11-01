// Agentes with the «Consumo de hoy» card (Codex unreadable → «—») and without dragon-tokens (card hidden).
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
    QtObject {
        id: tokens
        property bool available: true
        property var today: ({ claude: { in: 182000, out: 41000, cache: 1200000 }, codex: null })
        function format(n) { return n === null || n === undefined ? "—" : n >= 1e6 ? (n / 1e6).toFixed(1).replace(".", ",") + " M" : n >= 1e3 ? Math.round(n / 1e3) + " k" : String(n); }
    }
    QtObject { id: agents; property var agents: Fx.agents(Date.now()); property bool running: true; property string version: "0.9.5"; property var counts: ({ blocked: 1, done: 1, working: 1 }); property string readText: "Quiere ejecutar: npm test -- filtros\n¿Permitir? (s/n)"; property string readId: "p-claude"; property var _seen: ({}); function clearRead() {} function readAgent(a) {} function focusAgent(a) {} function markSeen(a) {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "agentes"; agentService: agents; memService: memory; promptService: prompts; tokenService: tokens }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        onTriggered: {
            if (step === 0) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-agentes-consumo.png"));
            else if (step === 1) tokens.available = false;
            else if (step === 2) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-agentes-sin-consumo.png"));
            else if (step === 3) Qt.quit();
            step++;
        }
    }
}
