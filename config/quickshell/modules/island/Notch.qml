// =============================================================================
// dragon-island — Notch.qml
// The notch: a black shape attached to the top edge of the screen (y = 0), never a floating pill.
//   collapsed  height 50 (bottom edge = bottom edge of the bar islands), width by content, at most
//              the free gap between the bar islands − 16 px per side (BarMetrics); centred on the
//              screen, sliding aside only when an island would be overlapped
//   appear     emerges from the edge: height 0 → 50, width 120 → collapsed (SpringAnimation)
//   peek       hover or transient state (OSD / notification / workspace): +8 px down, +16 px wide
//   expanded   ≈ 720 × 230 from the same top-centre anchor, bottom radii 34
// Choreography: content fades in once the shape is ~40 % into the animation (Theme.durContentDelay);
// on close the content fades out first (Theme.durContentOut), then the shape shrinks.
// =============================================================================
import QtQuick
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string screenName: ""
    property bool open: false
    property bool hidden: false
    readonly property alias shapeItem: shape

    // choreography state
    property bool expanded: false       // shape uses the expanded geometry
    property bool contentShown: false   // expanded content visible
    property bool appeared: false       // first appearance started
    property bool appearing: true       // first-appearance spring until it settles

    readonly property real ear: Theme.notchEarRadius
    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool peek: !expanded && appeared && (hovered || IslandState.isTransient)

    // free room towards the bar islands (ears included)
    readonly property real maxCollapsed: BarMetrics.maxNotchWidth(screenName, root.width)
    readonly property real collapsedWidth: Math.min(maxCollapsed, Math.max(Theme.notchRestWidth, content.implicitWidth + Theme.notchPadH * 2 + ear * 2))

    readonly property real targetWidth: expanded ? Math.min(Theme.notchExpandedWidth, root.width - Theme.barMarginSide * 2)
                                                 : (appeared ? Math.min(maxCollapsed, collapsedWidth + (peek ? Theme.notchPeekDx : 0))
                                                             : Theme.notchBaseWidth)
    readonly property real targetHeight: expanded ? Theme.notchExpandedHeight
                                                  : (appeared ? Theme.notchHeight + (peek ? Theme.notchPeekDy : 0) : 0)

    // centred on the screen; collapsed, it slides aside if an island would otherwise be overlapped
    readonly property real targetX: expanded ? (root.width - targetWidth) / 2
                                             : BarMetrics.notchX(screenName, root.width, targetWidth)

    property real animWidth: targetWidth
    property real animHeight: targetHeight
    property real animX: targetX

    Behavior on animWidth {
        enabled: Theme.animationsEnabled
        SpringAnimation { spring: root.appearing ? Theme.notchAppearSpring : Theme.notchSpring; damping: root.appearing ? Theme.notchAppearDamping : Theme.notchDamping; epsilon: 0.2 }
    }
    Behavior on animX {
        enabled: Theme.animationsEnabled
        SpringAnimation { spring: root.appearing ? Theme.notchAppearSpring : Theme.notchSpring; damping: root.appearing ? Theme.notchAppearDamping : Theme.notchDamping; epsilon: 0.2 }
    }
    Behavior on animHeight {
        enabled: Theme.animationsEnabled
        SpringAnimation { spring: root.appearing ? Theme.notchAppearSpring : Theme.notchSpring; damping: root.appearing ? Theme.notchAppearDamping : Theme.notchDamping; epsilon: 0.2 }
    }

    onOpenChanged: open ? openSeq() : closeSeq()

    function openSeq(): void {
        closeTimer.stop();
        root.expanded = true;
        contentTimer.restart();
    }

    function closeSeq(): void {
        contentTimer.stop();
        root.contentShown = false;      // content first ...
        closeTimer.restart();           // ... then the shape
    }

    Timer { id: contentTimer; interval: Theme.durContentDelay; onTriggered: root.contentShown = true }
    Timer { id: closeTimer; interval: Theme.durContentOut; onTriggered: root.expanded = false }

    // first appearance: wait a moment so the shell has laid out, then emerge from the edge
    Timer { id: appearTimer; interval: 250; onTriggered: { root.appeared = true; settleTimer.start(); } }
    Timer { id: settleTimer; interval: 900; onTriggered: root.appearing = false }
    Component.onCompleted: appearTimer.start()

    NotchShape {
        id: shape
        x: root.animX
        y: 0
        width: Math.max(0, root.animWidth)
        height: Math.max(0, root.animHeight)
        bottomRadius: root.expanded ? Theme.notchExpandedRadius : Theme.notchRadius
        opacity: root.hidden ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
        Behavior on bottomRadius { NumberAnimation { duration: Theme.durContentIn; easing.type: Easing.OutCubic } }

        // body between the ears; everything is clipped to it
        Item {
            id: body
            x: root.ear
            width: shape.width - root.ear * 2
            height: shape.height
            clip: true

            // ---- collapsed / peek content, centred on the bar's vertical centre ----
            NotchContent {
                id: content
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.barMarginTop + (parent.height - Theme.barMarginTop - height) / 2
                peek: root.peek
                maxWidth: root.maxCollapsed - root.ear * 2 - Theme.notchPadH * 2
                opacity: root.expanded ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.durContentOut } }
            }

            // ---- expanded content (created while expanded) ----
            Loader {
                id: expandedLoader
                active: root.expanded
                anchors.fill: parent
                opacity: root.contentShown ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: root.contentShown ? Theme.durContentIn : Theme.durContentOut; easing.type: Easing.OutCubic }
                }
                sourceComponent: NotchExpanded {
                    width: Theme.notchExpandedWidth - root.ear * 2
                    screenName: root.screenName
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            enabled: !root.expanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => {
                if (IslandState.mode === "agent" && m.button === Qt.LeftButton) { Herdr.focusAgent(IslandState.agentEvent?.agent); IslandState.agentFlash = false; }
                else if (m.button === Qt.MiddleButton && IslandState.mode === "media") Media.playPause();
                else if (m.button === Qt.LeftButton) ShellState.toggle("dashboard", root.screenName);
            }
        }

        // expanded: swallow clicks on empty areas
        MouseArea {
            z: -1      // BEHIND the content (tabs, buttons): it only catches what the content leaves free
            anchors.fill: parent
            enabled: root.expanded
            acceptedButtons: Qt.AllButtons
            onWheel: w => w.accepted = true
        }
    }
}
