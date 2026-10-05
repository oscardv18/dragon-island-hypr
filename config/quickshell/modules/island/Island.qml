// =============================================================================
// dragon-island — Island.qml
// The Dynamic Island shape. Closed: 36 px pill at y = 10, fully rounded, content by IslandState.mode.
// Open ("pour"): attached to the top edge (y = 0), 860 wide, radii 0/0/34/34, dashboard inside.
// Motion (Theme / spec):
//   first appearance  y −60 → 10, 700 ms OutBack (overshoot 1.6) + slight horizontal squash
//   open              width OutBack 420 · height/y/radii OutCubic 480 · content in at ~35 % for 260 ms
//   close             content out 120 ms first, then shape back in 300 ms OutCubic
//   transient states  pill width changes use the same width Behavior (OutBack 420)
// =============================================================================
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string screenName: ""
    property bool open: false
    property bool hidden: false
    readonly property alias shapeItem: shape

    // internal choreography state
    property bool expanded: false      // shape uses the open geometry
    property bool contentShown: false  // dashboard content visible
    property bool opening: true        // direction for the Behaviors (set before `expanded` changes)
    // first-appearance offset: starts above the edge (initial values don't trigger Behaviors)
    property real dropOffset: Theme.islandHiddenY - Theme.islandY

    onOpenChanged: open ? openSeq() : closeSeq()

    function openSeq(): void {
        closeTimer.stop();
        resetDir.stop();
        root.opening = true;
        root.expanded = true;
        contentTimer.restart();
    }

    function closeSeq(): void {
        contentTimer.stop();
        root.opening = false;
        root.contentShown = false;     // content fades out first
        closeTimer.restart();
    }

    Timer { id: contentTimer; interval: Theme.durContentDelay; onTriggered: root.contentShown = true }
    Timer {
        id: closeTimer
        interval: Theme.durContentOut
        onTriggered: { root.expanded = false; resetDir.restart(); }
    }
    Timer { id: resetDir; interval: Theme.durClose; onTriggered: root.opening = true }

    readonly property real shapeWidth: expanded ? Theme.dashboardWidth
                                                : Math.min(Theme.islandMaxPillWidth, pill.implicitWidth + Theme.islandPadH * 2)
    readonly property real shapeHeight: expanded
                                        ? (dashLoader.item ? dashLoader.item.implicitHeight : 0) + Theme.dashboardPadTop + Theme.dashboardPadBottom
                                        : Theme.islandHeight
    readonly property real cornerTop: expanded ? 0 : Theme.islandRadius
    readonly property real cornerBottom: expanded ? Theme.dashboardRadius : Theme.islandRadius

    // glow: accent ~18 %, 22–40 px blur
    RectangularShadow {
        anchors.fill: shape
        radius: shape.bottomLeftRadius
        blur: Theme.glowBlur
        color: Theme.glow
        opacity: shape.opacity
    }

    Rectangle {
        id: shape

        x: (root.width - width) / 2
        y: (root.expanded ? 0 : Theme.islandY) + root.dropOffset
        width: root.shapeWidth
        height: root.shapeHeight
        topLeftRadius: root.cornerTop
        topRightRadius: root.cornerTop
        bottomLeftRadius: root.cornerBottom
        bottomRightRadius: root.cornerBottom
        color: Theme.island
        border.width: 1
        border.color: Theme.islandBorder
        clip: true
        opacity: root.hidden ? 0 : 1

        transform: Scale {
            id: squash
            origin.x: shape.width / 2
            origin.y: 0
        }

        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
        Behavior on width {
            NumberAnimation {
                duration: root.opening ? Theme.durOpenWidth : Theme.durClose
                easing.type: root.opening ? Easing.OutBack : Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !dropIn.running
            NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic }
        }
        Behavior on topLeftRadius { NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: root.opening ? Theme.durOpenHeight : Theme.durClose; easing.type: Easing.OutCubic } }

        // ---- closed content ----
        PillContent {
            id: pill
            anchors.centerIn: parent
            opacity: root.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durContentOut } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: m => {
                const mode = IslandState.mode;
                if (mode === "media" && m.button === Qt.MiddleButton) {
                    Media.playPause();
                } else if (m.button === Qt.LeftButton) {
                    ShellState.toggle("dashboard", root.screenName);
                }
            }
        }

        // open: swallow clicks on empty dashboard areas (they must not reach the scrim)
        MouseArea {
            anchors.fill: parent
            enabled: root.expanded
            acceptedButtons: Qt.AllButtons
            onWheel: w => w.accepted = true
        }

        // ---- open content (dashboard), created while the shape is expanded ----
        Loader {
            id: dashLoader
            active: root.expanded
            x: Theme.dashboardPadH
            y: Theme.dashboardPadTop
            width: Theme.dashboardWidth - Theme.dashboardPadH * 2
            opacity: root.contentShown ? 1 : 0
            visible: opacity > 0
            transform: Translate { y: root.contentShown ? 0 : -Theme.popoverShift }

            Behavior on opacity {
                NumberAnimation { duration: root.contentShown ? Theme.durContentIn : Theme.durContentOut; easing.type: Easing.OutCubic }
            }

            sourceComponent: Dashboard {
                screenName: root.screenName
            }
        }
    }

    // ---- first appearance: fall from above the edge with a bounce ----
    ParallelAnimation {
        id: dropIn
        NumberAnimation {
            target: root
            property: "dropOffset"
            from: Theme.islandHiddenY - Theme.islandY
            to: 0
            duration: Theme.durDropIn
            easing.type: Easing.OutBack
            easing.overshoot: Theme.dropInOvershoot
        }
        NumberAnimation {
            target: squash
            property: "xScale"
            from: Theme.dropSquashX
            to: 1
            duration: Theme.durDropSquash
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: squash
            property: "yScale"
            from: Theme.dropSquashY
            to: 1
            duration: Theme.durDropSquash
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: dropIn.start()
}
