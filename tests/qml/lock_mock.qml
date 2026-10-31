// Offscreen render of the lock screen view (LockView, pure QtQuick) with simulated data: lock-calm.png (resting,
// satellites, mini player) and lock-alert.png (wrong password, Bloq Mayús on).
// usage: tests/qml/render-mocks.sh <out dir>
import QtQuick
import QtQuick.Window
import "../../config/quickshell/modules/lock"

Window {
    id: win
    width: 1366
    height: 768
    visible: true
    color: "#07060d"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    readonly property string icons: "/usr/share/icons/MacTahoe-purple-dark/apps/scalable"

    // the same keys as Theme.lockTokens (Theme is a Quickshell singleton: it does not load here)
    QtObject {
        id: mockTokens
        readonly property color ink: "#07060d"
        readonly property color backdrop: "#05060c"
        readonly property color text: "#edebf5"
        readonly property color soft: "#c8c4d8"
        readonly property color dim: "#a29eb6"
        readonly property color lavender: "#c8b6e6"
        readonly property color cyan: "#67e8f9"
        readonly property color warn: "#f5b04a"
        readonly property color alert: "#ed254e"
        readonly property color ok: "#86efac"
        readonly property color badge: "#8b6bb8"
        readonly property color line: Qt.rgba(1, 1, 1, 0.10)
        readonly property color glass: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.62)
        readonly property color glassDeep: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.7)
        readonly property color vignetteIn: Qt.rgba(0.20, 0.15, 0.30, 0.55)
        readonly property color vignetteMid: Qt.rgba(0.05, 0.04, 0.09, 0.4)
        readonly property color vignetteOut: Qt.rgba(0, 0, 0, 0.8)
        readonly property color edge: Qt.rgba(1, 1, 1, 0.16)
        readonly property color edgeStrong: Qt.rgba(1, 1, 1, 0.25)
        readonly property color shine: Qt.rgba(1, 1, 1, 0.14)
        readonly property color fill: Qt.rgba(1, 1, 1, 0.09)
        readonly property color fillSoft: Qt.rgba(1, 1, 1, 0.08)
        readonly property color track: Qt.rgba(1, 1, 1, 0.15)
        readonly property color cyanEdge: Qt.rgba(0.40, 0.91, 0.98, 0.35)
        readonly property color avatarFill: Qt.rgba(0.17, 0.13, 0.27, 1)
        readonly property color alertEdge: Qt.rgba(0.93, 0.15, 0.31, 0.75)
        readonly property color focusEdge: Qt.rgba(0.78, 0.71, 0.90, 0.45)
        readonly property int tick: 1000
        readonly property int durMood: 300
        readonly property int durEdge: 250
        readonly property int durShake: 65
        readonly property int durCalm: 1400
        readonly property int durHold: 650
        readonly property int durPoll: 600
    }

    LockView {
        id: lv
        anchors.fill: parent
        tokens: mockTokens
        reducedMotion: true
        userName: "oddv"
        realName: "Oscar Daniel"
        hostName: "darkdev"
        layoutLabel: "US"
        lockedAt: Date.now() - 3 * 60000
        notifCount: 4
        captures: 64
        notifApps: [{ name: "Telegram", icon: `file://${win.icons}/org.telegram.desktop.svg`, count: 4 },
                    { name: "Brave", icon: `file://${win.icons}/brave-browser.svg`, count: 2 }]
        hasMedia: true
        mediaTitle: "Aitana afirma que…"
        mediaPlaying: true
        mediaProgress: 0.38
        batteryPct: -1
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(`${win.outDir}/lock-calm.png`);
            lv.mood = "alert"; lv.stateText = "contraseña incorrecta"; lv.hint = "Contraseña incorrecta"; lv.hintError = true; lv.capsLock = true;
            alertShot.start();
        })
    }
    Timer {
        id: alertShot
        interval: 900
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(`${win.outDir}/lock-alert.png`); Qt.quit(); })
    }
}
