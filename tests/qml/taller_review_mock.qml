// Revisión with seen files, a file changed after being seen, comment bubbles and the review prompt (32-taller-revision).
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
        id: review
        property string status: "ok"
        property string message: ""
        property string actionError: ""
        property bool live: true
        property bool base: true
        property string cardKey: "AX-142"
        property var card: memory.cards.find(c => c.key === "AX-142")
        property var candidates: memory.cards.filter(c => c.worktree)
        property string repo: "/synthetic/arxnet-ax142"
        property var files: Fx.reviewFiles()
        readonly property int seenCount: files.filter(f => f.seen).length
        readonly property int unseenCount: files.length - seenCount
        property string selectedPath: "migrations/0042_idx_estado.sql"
        property var diffData: Fx.reviewDiff()
        property var comments: Fx.comments()
        property int reviewTokens: 296
        property string reviewLevel: "ligero"
        property var marked: []
        function setCard(key) { cardKey = key; }
        function setLive(v) { live = v; }
        function select(p) { selectedPath = p; }
        function markSeen(p) { marked = marked.concat([p]); files = files.map(f => f.path === p ? Object.assign({}, f, { seen: true, changed: false }) : f); }
        function addComment(p, l, t) { comments = comments.concat([{ id: 9, path: p, line: l, text: t, sent: 0 }]); }
    }
    QtObject { id: agents; property var agents: Fx.agents(Date.now()); property bool running: true; property string version: "0.9.5"; property var counts: ({ blocked: 1, done: 1, working: 1 }); property string readText: ""; property var _seen: ({}); function clearRead() {} function readAgent(a) {} }
    TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "revision"; agentService: agents; memService: memory; promptService: prompts; reviewService: review }
    Timer {
        interval: 300; running: true; repeat: true
        property int step: 0
        onTriggered: {
            if (step === 0) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-revision.png"));
            else if (step === 1) { review.markSeen("migrations/0042_idx_estado.sql"); review.addComment("migrations/0042_idx_estado.sql", 6, "¿ANALYZE en la migración?"); }
            else if (step === 2) { console.log("SEEN", review.seenCount, "COMMENTS", review.comments.length, "BADGE", review.unseenCount); panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-revision-marcado.png")); }
            else if (step === 3) { review.card = null; review.files = []; review.comments = []; review.diffData = { hunks: [] }; review.selectedPath = ""; review.status = "unavailable"; review.message = "Elige una tarjeta con worktree o agente"; }
            else if (step === 4) panel.grabToImage(r => r.saveToFile(win.outDir + "/taller-revision-vacio.png"));
            else if (step === 5) Qt.quit();
            step++;
        }
    }
}
