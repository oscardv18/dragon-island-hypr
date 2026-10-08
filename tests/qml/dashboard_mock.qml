// Offscreen render of the dashboard's Apps / IA rows with simulated data (no Quickshell services).
// usage: tests/qml/render-mocks.sh <out dir>  (writes dashboard-apps.png)
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/island"

Window {
    id: win
    width: 700
    height: 300
    visible: true
    color: "#000000"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    function app(label, status, ws, vpn) { return { key: label, label, status, vpn: vpn ?? "", windows: ws ? [{}] : [], trayItem: status !== "none" ? { hasMenu: true } : null } }

    Rectangle { anchors.fill: parent; color: "#000000" }   // the notch is opaque black

    Grid {
        x: 16; y: 16; columns: 2; spacing: 8
        AppRow { width: 330; entry: win.app("Proton VPN", "active", false, "on"); stateText: "VPN conectada (proton0)" }
        AppRow { width: 330; entry: win.app("Telegram", "attention", false); stateText: "Requiere atención" }
        AppRow { width: 330; entry: win.app("OBS Studio", "active", true); stateText: "Ventana en el workspace 3" }
        AppRow { width: 330; entry: win.app("Syncthing", "passive", false); stateText: "Solo en la bandeja (pasiva)" }
        AppRow { width: 330; entry: win.app("KDE Connect", "none", false); stateText: "Proceso en ejecución, sin ventana ni bandeja" }
    }
    Column {
        x: 16; y: 190; width: 400; spacing: 2
        AgentRow { agent: ({ agent: "claude", state: "working", title: "Islas inferiores con herdr" }); elapsed: "12 min" }
        AgentRow { agent: ({ agent: "codex", state: "blocked", title: "Aprobar rm -rf build" }); elapsed: "40 s" }
    }

    Timer {
        interval: 800; running: true
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(`${win.outDir}/dashboard-apps.png`); Qt.quit(); })
    }
}
