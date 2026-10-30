// Offscreen render of the SDDM theme (sddm/dragon-core/Main.qml) with a simulated greeter API: sddm-calm.png (two
// users, so a satellite shows) and sddm-alert.png (a wrong password: the core in alert, the hint, Bloq Mayús).
// The theme reads sddm / userModel / sessionModel / keyboard / config from its context: here they are the ids below.
// usage: tests/qml/render-mocks.sh <out dir>
//   or by hand, to compare backgrounds and sizes (options before the out dir, which stays the last argument):
//   QT_QPA_PLATFORM=offscreen qml6 tests/qml/sddm_mock.qml -- size=1920x1080 bg=/abs/wall.jpg noise=0 face=/abs/face.png
//     prefix=4k- <out dir>      (noise = theme.conf `noise`; face = the selected user's icon; prefix goes before the names)
//   The offscreen platform has no GPU: MultiEffect draws nothing there, so the blurred wallpaper is missing. To see it,
//   run with QT_QPA_PLATFORM=wayland (a window shows for ~2 s; the grab keeps `size` whatever the compositor does).
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: shotW
    height: shotH
    readonly property int shotW: parseInt(opt("size", "1366x768").split("x")[0])
    readonly property int shotH: parseInt(opt("size", "1366x768").split("x")[1])
    visible: true
    color: "#07060d"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]
    function opt(key, def) {
        const a = Qt.application.arguments.find(x => x.startsWith(key + "="))
        return a ? a.slice(key.length + 1) : def
    }
    readonly property string prefix: opt("prefix", "")

    QtObject {
        id: sddm
        property string hostName: "darkdev"
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginSucceeded()
        signal loginFailed()
        signal informationMessage(string message)
        function login(user, password, session) { }
        function suspend() { }
        function reboot() { }
        function powerOff() { }
    }
    ListModel {
        id: userModel
        property int lastIndex: 0
        ListElement { name: "oddv"; realName: "Oscar Daniel"; icon: ""; homeDir: "/nonexistent/oddv" }
        ListElement { name: "invitado"; realName: "Invitado"; icon: ""; homeDir: "/nonexistent/invitado" }
        Component.onCompleted: setProperty(0, "icon", win.opt("face", ""))
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement { name: "Hyprland" }
        ListElement { name: "Plasma (Wayland)" }
    }
    QtObject {
        id: keyboard
        property var layouts: [{ shortName: "us" }, { shortName: "latam" }]
        property int currentLayout: 0
        property bool capsLock: false
    }
    QtObject {
        id: config
        property string reducedMotion: "true"
        property string background: win.opt("bg", "")
        property string noise: win.opt("noise", "")
    }

    Loader {
        id: theme
        // a fixed size and the grab of this item (not of the window): a tiling compositor may resize the window
        width: win.shotW
        height: win.shotH
        source: "../../sddm/dragon-core/Main.qml"
    }

    Timer {
        interval: 1500
        running: theme.status === Loader.Ready
        onTriggered: theme.grabToImage(r => {
            r.saveToFile(`${win.outDir}/${win.prefix}sddm-calm.png`);
            keyboard.capsLock = true;
            sddm.loginFailed();
            alert.start();
        })
    }
    Timer {
        id: alert
        interval: 700
        onTriggered: theme.grabToImage(r => { r.saveToFile(`${win.outDir}/${win.prefix}sddm-alert.png`); Qt.quit(); })
    }
}
