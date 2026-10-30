// Offscreen render of the SDDM theme (sddm/dragon-core/Main.qml) with a simulated greeter API: sddm-calm.png (two
// users, so a satellite shows) and sddm-alert.png (a wrong password: the core in alert, the hint, Bloq Mayús).
// The theme reads sddm / userModel / sessionModel / keyboard / config from its context: here they are the ids below.
// usage: tests/qml/render-mocks.sh <out dir>
import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 1366
    height: 768
    visible: true
    color: "#07060d"

    readonly property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]

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
        ListElement { name: "oddv"; realName: "Oscar Daniel"; icon: "" }
        ListElement { name: "invitado"; realName: "Invitado"; icon: "" }
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
    }

    Loader {
        id: theme
        anchors.fill: parent
        source: "../../sddm/dragon-core/Main.qml"
    }

    Timer {
        interval: 1500
        running: theme.status === Loader.Ready
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(`${win.outDir}/sddm-calm.png`);
            keyboard.capsLock = true;
            sddm.loginFailed();
            alert.start();
        })
    }
    Timer {
        id: alert
        interval: 700
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(`${win.outDir}/sddm-alert.png`); Qt.quit(); })
    }
}
