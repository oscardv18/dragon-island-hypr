// Pure Taller view, no backend processes. render-mocks.sh supplies a pure Theme.
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/taller"
import "../../config/quickshell/modules/island"

Window {
    id: win
    width: 1366
    height: 768
    visible: true
    color: Theme.bg
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    QtObject {
        id: agents
        property bool running: false
        property string version: "0.9.5"
        property string message: "herdr no está en marcha"
        property var agents: []
        property var counts: ({ blocked: 0, done: 0, working: 0 })
        property string readId: ""
        property string readText: ""
        property string actionError: ""
        property var _seen: ({})
        function readAgent(a) { readId = a.pane; readText = "● Bash(pnpm test --filter facturas)\n  └ Esperando aprobación…\n¿Permitir ejecutar este comando? (s/n)"; }
        function clearRead() { readId = ""; readText = ""; }
        function focusAgent(a) {}
        function markSeen(a) { const s=Object.assign({},_seen);s[a.pane]=a.since;_seen=s; }
        function snooze(a,m) {}
    }
    QtObject {
        id: memory
        property var projects: []
        property var project: null
        property string selectedSlug: ""
        property string status: "ok"
        property string message: ""
    }
    TallerPanel {
        id: panel
        anchors.centerIn: parent
        width: Theme.taller.width
        height: Theme.taller.height
        shown: true
        agentService: agents
        memService: memory
        onTabRequested: name => panel.tab = name
    }
    Rectangle {
        id: attentionPreview
        width: Theme.taller.attentionWidth
        height: Theme.taller.attentionHeight
        radius: height / 2
        color: Theme.island
        visible: false
        AttentionCard {
            anchors.centerIn: parent
            maxWidth: parent.width - Theme.taller.inset * 2
            agent: agents.agents[0] ?? null
            now: Date.now()
        }
    }
    Timer {
        interval: 500
        running: true
        property int step: 0
        repeat: true
        onTriggered: {
            if (step === 0) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-vacio.png"));
            if (step === 1) {
                agents.running = true; agents.message = ""; agents.counts = {blocked:1,done:1,working:2};
                agents.agents = [
                    {pane:"a",id:"a",kind:"claude",name:"claude",state:"blocked",space:"arxnet-erp",branch:"feat/facturas-filtros",card:"AX-142",note:"Pide permiso para ejecutar un comando",since:Date.now()-120000,project:"arxnet-erp"},
                    {pane:"h",id:"h",kind:"codex",name:"revisor",state:"working",space:"arxnet-erp",branch:"revisor → informa a claude",helper_of:"a",since:Date.now()-360000},
                    {pane:"b",id:"b",kind:"codex",state:"working",space:"arxnet-erp",branch:"fix/export-csv",card:"AX-139",note:"Editando 3 archivos",since:Date.now()-840000},
                    {pane:"c",id:"c",kind:"claude",state:"done",space:"nextDash-3d",branch:"feat/world-kit",card:"ND-31",note:"Terminó · cambios sin revisar",since:Date.now()-540000},
                    {pane:"d",id:"d",kind:"codex",state:"idle",space:"SoftArch",branch:"main",note:"Sin tarea",since:Date.now()-3600000}
                ];
                memory.projects = [{slug:"arxnet-erp",name:"arxnet-erp"},{slug:"nextDash-3d",name:"nextDash-3d"},{slug:"softarch",name:"SoftArch"}];
                memory.project = memory.projects[0];memory.selectedSlug = "arxnet-erp";
            }
            if (step === 2) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-agentes.png"));
            if (step === 3) attentionPreview.visible = true;
            if (step === 4) attentionPreview.grabToImage(r => r.saveToFile(win.outDir + "/taller-atencion.png"));
            if (step === 5) Qt.quit();
            step++;
        }
    }
}
