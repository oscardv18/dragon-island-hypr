// Quickshell test harness. All services are fixture singletons in a temporary copy.
import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "services"
import "modules/bar"

ShellRoot {
    id: test
    property int stage: 0
    property real stableWidth: 0
    property var fixtures: []
    property bool interactive: Quickshell.env("BELL_INTERACTIVE") === "1"
    function check(condition, message) { if (!condition) throw new Error("BELL_TEST: " + message); }
    function find(node, name) {
        if (node.objectName === name) return node;
        for (const child of (node.children ?? [])) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function state(count, dnd) { Notifs.unreadCount = count; Notifs.dnd = dnd; }
    function capture(name, done) {
        preview.grabToImage(result => {
            check(result.saveToFile(Quickshell.env("BELL_OUTPUT") + "/" + name + ".png"), "capture " + name);
            done();
        });
    }

    // TEST_BAR_INTERFACE: replaced with the real Bar.qml openFrom/isOpen methods by the Python runner.
    QtObject { id: bar; property string screenName: "FIXTURE-1" }

    FloatingWindow {
        id: win
        visible: true
        title: "Dragon notification bell fixture"
        implicitWidth: 760
        implicitHeight: 170
        color: Theme.bg
        Rectangle {
            id: preview
            color: Theme.bg
            anchors.fill: parent
            RightIsland {
                id: island
                bar: bar
                x: Theme.spacingLg
                y: Theme.spacingLg
                maxWidth: win.width - Theme.spacingLg * 2
                windowX: 100
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingLg
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.textSoft
                font.family: Theme.fontUi
                text: "Datos de prueba · campana, contador y No molestar"
            }
        }
    }
    IpcHandler {
        target: "bell-test"
        function state(count: int, dnd: bool): void { test.state(count, dnd); }
        function quit(): void { Qt.quit(); }
    }
    Component.onCompleted: {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("fixtures/right-island.json"), false); xhr.send();
        test.fixtures = JSON.parse(xhr.responseText).states;
        Theme.motionScale = 0;
    }
    Timer {
        interval: 120
        repeat: true
        running: !test.interactive
        onTriggered: {
            const bell = test.find(island, "notificationBell");
            check(bell !== null && bell.visible, "bell in RightIsland");
            if (test.stage === 0) test.stableWidth = island.width;
            if (test.stage < test.fixtures.length) {
                const f = test.fixtures[test.stage];
                state(f.count, f.dnd);
                Qt.callLater(() => {
                    check(island.width === test.stableWidth, "unread/DND must not resize island");
                    check(test.find(bell, "notificationBellBadge").visible === (f.count > 0), "badge visibility");
                    check(test.find(bell, "notificationBellCount").text === (f.count > 99 ? "99+" : String(f.count)), "badge count");
                    check(test.find(bell, "notificationBellGlyph").icon === (f.dnd ? Icons.bellOff : Icons.bell), "DND icon");
                    test.capture(f.name, () => {});
                });
            } else if (test.stage === test.fixtures.length) {
                bell.clicked({button: Qt.LeftButton});
                check(ShellState.openPanel === "notifications", "left click opens notifications");
                check(ShellState.panelScreen === bar.screenName && ShellState.anchorSide === "right", "screen/side");
                check(ShellState.anchorX === bell.mapToItem(null, bell.width, 0).x + island.windowX, "right anchor offset");
                check(ShellState.anchorCenter === bell.mapToItem(null, bell.width / 2, 0).x + island.windowX, "beam center");
                check(bell.active, "active feedback");
                bell.clicked({button: Qt.RightButton});
                check(Toggles.dnd && ShellState.openPanel === "notifications", "right click only toggles DND");
                bell.clicked({button: Qt.LeftButton});
                check(ShellState.openPanel === "none", "left click closes");
                ShellState.toggleAt("calendar", bar.screenName, 0, "right", 0);
                bell.clicked({button: Qt.LeftButton});
                check(ShellState.openPanel === "notifications", "replaces calendar");
                bar.screenName = "FIXTURE-2";
                bell.clicked({button: Qt.LeftButton});
                check(ShellState.openPanel === "notifications" && ShellState.panelScreen === "FIXTURE-2", "moves to other monitor");
                test.capture("active", () => {});
            } else {
                ShellState.close();
                const i = test.stage - test.fixtures.length - 1;
                const styles = ["A", "B", "C", "D"];
                if (i >= 12) { console.log("BELL_TEST_OK"); Qt.quit(); return; }
                Theme.barStyle = styles[Math.floor(i / 3)];
                Theme.barSize = Theme.barSizes[i % 3];
                state(3, true);
                Qt.callLater(() => {
                    check(bell.visible, "bell in all styles");
                    check(bell.height <= island.height, "capsule fits height");
                    check(test.find(bell, "notificationBellBadge").height <= bell.height, "badge fits compact style D");
                    test.capture(Theme.barStyle + "-" + Theme.barSize, () => {});
                });
            }
            test.stage++;
        }
    }
    Timer { interval: 15000; running: !test.interactive; onTriggered: { console.error("BELL_TEST_TIMEOUT"); Qt.quit(); } }
}
