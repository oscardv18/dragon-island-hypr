// Synthetic repository and staged-secret failure. No Git commands or services.
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
        id: git
        property string repo: "/synthetic/arxnet"
        property string status: "ok"
        property string message: ""
        property string actionError: ""
        property bool busy: false
        property bool secretsChecked: true
        property var secrets: []
        property var snapshot: ({branch:"feat/facturas-filtros",upstream:"origin/feat/facturas-filtros",ahead:2,behind:0,staged:[{path:"src/facturas/filtros.ts",status:"M",add:48,del:6},{path:"src/facturas/filtros.test.ts",status:"A",add:72,del:0}],changes:[{path:"src/facturas/lista.tsx",status:"M",add:12,del:3},{path:"package.json",status:"M",add:1,del:0},{path:"src/legacy/old-filters.ts",status:"D",add:0,del:31}],untracked:[],conflicts:[]})
        property int changeCount: 5
        property string selectedPath: "src/facturas/filtros.ts"
        property bool staged: true
        property var diffData: ({path:"src/facturas/filtros.ts",add:48,del:6,hunks:[{header:"@@ -10,6 +10,18 @@ export function aplicarFiltros(lista, f)",lines:[
            {o:10,n:10,t:"ctx",text:"    let r = lista.filter(esVisible);"},{o:11,n:11,t:"ctx",text:""},
            {o:12,n:null,t:"del",text:"    if (f.estado) r = r.filter(x => x.estado === f.estado)"},
            {o:null,n:12,t:"add",text:"    if (f.estado) {"},{o:null,n:13,t:"add",text:"      r = r.filter(x => x.estado === f.estado)"},{o:null,n:14,t:"add",text:"    }"},
            {o:null,n:15,t:"add",text:"    if (f.desde || f.hasta) {"},{o:null,n:16,t:"add",text:"      r = r.filter(x => enRango(x.fecha, f.desde, f.hasta))"},{o:null,n:17,t:"add",text:"    }"},
            {o:13,n:18,t:"ctx",text:"    return ordenar(r, f.orden)"},{o:14,n:19,t:"ctx",text:"}"}]}]})
        property var history: [{hash:"a41c9e2",subject:"feat(facturas): modelo de filtros",author:"Ana"},{hash:"7b013ec",subject:"chore: dependencias de pruebas",author:"Luis"},{hash:"19d8a60",subject:"fix(export): encabezados duplicados",author:"Ana"},{hash:"c0f2b77",subject:"feat(login): enlace mágico",author:"Luis"},{hash:"5a9e114",subject:"docs: variables de entorno",author:"Ana"}]
        property var branches: [{name:"feat/facturas-filtros",current:true},{name:"main",current:false},{name:"fix/export-csv",current:false}]
        signal committed()
        function select(path,prepared) { selectedPath = path; staged = prepared; }
        function stage(path,value) {}
        function commit(text,push) {}
        function pull() {}
        function push() {}
        function checkout(branch) {}
        function lazygit() {}
    }
    QtObject { id: memory; property var project: ({name:"arxnet-erp",branch:"feat/facturas-filtros"}); property var projects: [{}]; property string selectedSlug: "arxnet-erp"; property string status: "ok" }
    QtObject { id: agents; property var agents: []; property bool running: true; property string version: "0.9.5"; property var counts: ({blocked:1}); function clearRead() {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "git"; gitService: git; memService: memory; agentService: agents }
    Timer {
        interval: 350; running: true; repeat: true
        property int step: 0
        onTriggered: {
            if (step === 0) panel.grabToImage(r => r.saveToFile(win.outDir+"/taller-git.png"));
            else if (step === 1) { git.secrets = [{path:".env",line:1,type:"env_file"}]; git.actionError = "Hay secretos en lo preparado. Retíralos antes de commitear. · .env:1 (env_file)"; }
            else if (step === 2) panel.grabToImage(r => r.saveToFile(win.outDir+"/taller-git-secretos.png"));
            else if (step === 3) { git.repo = ""; git.status = "unavailable"; git.message = "Selecciona un proyecto"; git.snapshot = {staged:[],changes:[],untracked:[],conflicts:[]}; git.history = []; git.branches = []; git.diffData = {hunks:[]}; git.actionError = ""; }
            else if (step === 4) panel.grabToImage(r => r.saveToFile(win.outDir+"/taller-git-vacio.png"));
            else if (step === 5) Qt.quit();
            step++;
        }
    }
}
