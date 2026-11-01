// Pure Taller view, no backend processes. render-mocks.sh supplies a pure Theme.
import QtQuick
import QtQuick.Window
import "../../config/quickshell"
import "../../config/quickshell/modules/taller"

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
    Timer {
        interval: 500
        running: true
        onTriggered: panel.grabToImage(r => { r.saveToFile(win.outDir + "/taller-vacio.png"); Qt.quit(); })
    }
}
