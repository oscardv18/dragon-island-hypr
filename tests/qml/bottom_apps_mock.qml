// Offscreen render of the right bottom island with simulated data (no Quickshell services).
// usage: QT_QPA_PLATFORM=offscreen qml6 tests/qml/bottom_apps_mock.qml -- <out dir>   (writes apps-0.png, apps-3.png, apps-12.png)
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/bottomislands"

Window {
    id: win
    width: 560
    height: 220
    visible: true
    color: "#0b0c14"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    property var sets: ({})
    property int step: 0

    function mk(i, label, status, ws) {
        return { key: `k${i}`, label, status, workspace: ws, wsShort: ws, windows: ws !== "" ? [{}] : [], attention: status === "attention", kind: "tray", pid: 0 }
    }
    property var data0: []
    property var data3: [mk(0, "Telegram", "attention", ""), mk(1, "Proton VPN", "active", ""), mk(2, "OBS Studio", "active", "3")]
    property var data12: {
        const out = [];
        const st = ["active", "passive", "attention", "active", "none"];
        for (let i = 0; i < 12; i++) out.push(mk(i, `App ${i}`, st[i % st.length], i % 4 === 0 ? `${(i % 5) + 1}` : ""));
        return out;
    }

    Rectangle { anchors.fill: parent; color: "#0b0c14" }   // stand-in for the wallpaper behind the glass

    AppsIsland {
        id: island
        x: 20
        y: 90
        maxWidth: 520
        entries: win.data0
        iconProvider: (e, failed) => ""
    }

    // set data, wait, grab, wait for the file, next
    property var plan: [["0", data0], ["3", data3], ["12", data12]]
    property int phase: 0
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            const i = Math.floor(win.phase / 2);
            if (i >= win.plan.length) { Qt.quit(); return; }
            if (win.phase % 2 === 0) { island.entries = win.plan[i][1]; island.maxWidth = i === 2 ? 330 : 520; }
            else win.contentItem.grabToImage(r => r.saveToFile(`${win.outDir}/apps-${win.plan[i][0]}.png`));
            win.phase++;
        }
    }
}
