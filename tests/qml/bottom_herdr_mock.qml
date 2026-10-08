// Offscreen render of the left bottom island with simulated herdr data: offline · 0 agents · several states.
// usage: tests/qml/render-mocks.sh <out dir>  (writes herdr-offline.png, herdr-0.png, herdr-many.png)
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/bottomislands"

Window {
    id: win
    width: 640
    height: 330
    visible: true
    color: "#0b0c14"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    function ag(pane, kind, state, ws, title) { return { pane, agent: kind, name: kind, state, workspaceId: ws, title, since: Date.now() - 754000 } }
    property var many: [ag("p1", "claude", "working", "w1", "Islas inferiores con herdr"), ag("p2", "claude", "blocked", "w1", "Aprobar rm -rf build"),
                        ag("p3", "codex", "working", "w2", "Refactor del servicio"), ag("p4", "gemini", "done", "w2", "Tests"),
                        ag("p5", "codex", "idle", "w3", ""), ag("p6", "pi", "unknown", "w3", "")]

    Rectangle { anchors.fill: parent; color: "#0b0c14" }
    HerdrIsland { id: island; x: 20; y: 20; editorCount: 0 }
    Column {
        x: 20; y: 80; spacing: 2; width: 320
        Repeater { model: win.many; delegate: AgentRow { required property var modelData; agent: modelData; elapsed: "12 min" } }
    }

    property var plan: [
        ["offline", () => { island.online = false; island.agents = []; island.counts = ({}); island.editorCount = 1; island.editorText = "Visual Studio Code"; }],
        ["0", () => { island.online = true; island.workspaces = [{}]; island.editorCount = 0; }],
        ["many", () => { island.agents = win.many; island.workspaces = [{}, {}, {}]; island.counts = ({ working: 2, blocked: 1, done: 1, idle: 1, unknown: 1 }); island.longestText = "12 min"; island.editorCount = 3; }]
    ]
    property int phase: 0
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            const i = Math.floor(win.phase / 2);
            if (i >= win.plan.length) { Qt.quit(); return; }
            if (win.phase % 2 === 0) win.plan[i][1]();
            else win.contentItem.grabToImage(r => r.saveToFile(`${win.outDir}/herdr-${win.plan[i][0]}.png`));
            win.phase++;
        }
    }
}
