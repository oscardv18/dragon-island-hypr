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

    LockView {
        id: lv
        anchors.fill: parent
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
