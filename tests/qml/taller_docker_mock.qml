// Synthetic Compose states. No services and no socket or network required.
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/taller"
Window {
    id: win
    visible: true
    width: Theme.taller.width
    height: Theme.taller.height
    color: Theme.bg
    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length-1]
    QtObject {
        id: docker
        property string status: "ok"
        property string message: ""
        property string actionError: ""
        property bool busy: false
        property string selectedId: "worker"
        property var containers: [
            {id:"api",name:"api",service:"api",project:"arxnet-erp",image:"arxnet/api:dev",ports:["3000->3000"],state:"running"},
            {id:"web",name:"web",service:"web",project:"arxnet-erp",image:"arxnet/web:dev",ports:["5173->5173"],state:"running"},
            {id:"db",name:"db",service:"db",project:"arxnet-erp",image:"postgres:16",ports:["5432->5432"],state:"running"},
            {id:"worker",name:"worker",service:"worker",project:"arxnet-erp",image:"arxnet/worker:dev",ports:[],state:"restarting"},
            {id:"redis",name:"redis",service:"redis",project:"arxnet-erp",image:"redis:7",ports:[],state:"running"},
            {id:"next",name:"web",service:"web",project:"nextDash-3d",image:"nextdash/web:dev",ports:[],state:"exited"}]
        readonly property var selected: containers.find(c => c.id === selectedId) ?? null
        property var issues: [{container:"worker",kind:"restart_loop",detail:"Reiniciado 5 veces en 10 min"},{container:"worker",kind:"oom",detail:"OOMKilled"},{container:"worker",kind:"exit_nonzero",detail:"salida 137"}]
        readonly property int errorCount: issues.length ? 1 : 0
        property var metrics: ({api:{cpu_pct:3.2,mem_bytes:222298112},web:{cpu_pct:5.9,mem_bytes:125829120},db:{cpu_pct:1.1,mem_bytes:364904448},worker:{cpu_pct:0,mem_bytes:2147483648,net_rx_bps:1258291,net_tx_bps:314572},redis:{cpu_pct:.4,mem_bytes:18874368}})
        property var history: ({})
        property var logs: [
            {ts:"2026-11-01T10:41:02Z",level:"info",msg:"worker iniciado pid=1",count:1},
            {ts:"2026-11-01T10:41:03Z",level:"info",msg:"conectado a redis://redis:6379",count:1},
            {ts:"2026-11-01T10:41:05Z",level:"warn",msg:"uso de heap 87% (1,7 GB de 2 GB)",count:1},
            {ts:"2026-11-01T10:41:09Z",level:"error",msg:"FATAL: JavaScript heap out of memory",count:5},
            {ts:"2026-11-01T10:41:09Z",level:"error",msg:"at processInvoices (src/jobs/invoices.ts:88)",count:5},
            {ts:"2026-11-01T10:41:10Z",level:"info",msg:"worker iniciado pid=1",count:1},
            {ts:"2026-11-01T10:41:12Z",level:"warn",msg:"uso de heap 91% (1,8 GB de 2 GB)",count:1},
            {ts:"2026-11-01T10:41:15Z",level:"error",msg:"FATAL: JavaScript heap out of memory",count:1}]
        property string inspectText: ""
        function select(id) { selectedId = id; }
        function action(verb) {}
        function inspect() { inspectText = '{"Env":["API_KEY=[oculto:entorno]"]}'; }
        function shell() {}
        Component.onCompleted: {
            const h = {};
            for (const c of containers) h[c.id] = [3,5,4,7,2,5,8,5,6,3].map(n => ({cpu_pct:n,mem_bytes:n*10485760,net_rx_bps:n*2048}));
            history = h;
        }
    }
    QtObject { id: memory; property var project: ({name:"arxnet-erp",branch:"feat/facturas-filtros"}); property var projects: [{}]; property string selectedSlug: "arxnet-erp"; property string status: "ok" }
    QtObject { id: agents; property var agents: []; property bool running: true; property string version: "0.9.5"; property var counts: ({blocked:1}); function clearRead() {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "contenedores"; dockerService: docker; memService: memory; agentService: agents }
    Timer {
        interval: 350; running: true; repeat: true
        property int step: 0
        onTriggered: {
            if (step === 0) panel.grabToImage(r => r.saveToFile(win.outDir+"/taller-contenedores.png"));
            else if (step === 1) { docker.status = "unavailable"; docker.containers = []; docker.issues = []; docker.message = "Docker no disponible: añade tu usuario al grupo docker y vuelve a iniciar sesión"; }
            else if (step === 2) panel.grabToImage(r => r.saveToFile(win.outDir+"/taller-docker-sin-permiso.png"));
            else if (step === 3) Qt.quit();
            step++;
        }
    }
}
