// =============================================================================
// dragon-island — Notch.qml
// The notch, in the bar style's shape (Theme.barLook):
//   A, C       attached to the top edge (y = 0) with concave ears; 26 / 24 high
//   B          a floating islandInk pill at top 6, 26 high, with a soft shadow
//   D          an 80 × 18 micro-island that only shows with activity (music playing, recording, an agent);
//              touching the top edge reveals style B (Theme.barRevealed)
//   collapsed  width by content, at most the free gap between the bar islands − 16 px per side (BarMetrics);
//              centred on the screen, sliding aside only when an island would be overlapped
//   appear     emerges from the edge: height 0 → collapsed, width 120 → collapsed (SpringAnimation)
//   peek       hover or transient state (OSD / notification / workspace): grows down and wider
//   expanded   ≈ 720 × 230 from the same top-centre anchor (B: from the floating pill, no ears), bottom radii 34
// Choreography: content fades in once the shape is ~40 % into the animation (Theme.durContentDelay);
// on close the content fades out first (Theme.durContentOut), then the shape shrinks.
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

    // choreography state
    property bool expanded: false       // shape uses the expanded geometry
    property bool contentShown: false   // expanded content visible
    property bool appeared: false       // first appearance started
    property bool appearing: true       // first-appearance spring until it settles

    readonly property bool attached: Theme.notchAttached
    readonly property real ear: attached ? Theme.notchEarRadius : 0
    readonly property bool hovered: hoverArea.containsMouse
    onHoveredChanged: BarState.hover("notch", hovered)
    // style D: the micro-island, only while something is going on
    // the micro-island only stands in for the quiet content: important states show the full island also in D
    readonly property bool micro: Theme.barLook === "D" && !expanded && !IslandState.isTransient
                                  && ["focus", "recording", "capture", "dropdown", "agentBlocked", "idleWarn"].indexOf(IslandState.mode) < 0
    readonly property bool microActive: Media.isPlaying || Toggles.isRecording || (Herdr.counts?.working ?? 0) > 0 || IslandState.mode === "agentBlocked"
    readonly property bool lid: IslandState.mode === "dropdown" && Dropdown.screenName === screenName && !expanded   // drop-down terminal under it
    readonly property bool peek: !expanded && !micro && !lid && appeared && (hovered || IslandState.isTransient)

    // free room towards the bar islands (ears included)
    readonly property real maxCollapsed: BarMetrics.maxNotchWidth(screenName, root.width)
    readonly property real collapsedWidth: micro ? Theme.notchMicroWidth
                                                 : Math.min(maxCollapsed, Math.max(snug ? 0 : Theme.notchRestWidth, content.implicitWidth + Theme.notchPadH * 2 + ear * 2))
    // short notices sized to their text (Bloq Mayús, keyboard layout)
    readonly property bool snug: IslandState.mode === "osd" && (Osd.kind === "capslock" || Osd.kind === "layout")

    readonly property real targetWidth: lid ? Dropdown.width + ear * 2 : expanded ? Math.min(Theme.notchExpandedWidth, root.width - Theme.barMarginSide * 2)
                                                 : (appeared ? Math.min(maxCollapsed, collapsedWidth + (peek ? Theme.notchPeekDx : 0))
                                                             : Theme.notchBaseWidth)
    readonly property real targetHeight: expanded ? Theme.notchExpandedHeight
                                                  : (!appeared || (micro && !microActive) ? 0
                                                     : Math.max(Theme.notchHeight, micro ? 0 : content.implicitHeight + 8) + (peek ? Theme.notchPeekDy : 0))

    // centred on the screen; collapsed, it slides aside if an island would otherwise be overlapped
    readonly property real targetX: expanded || lid ? (root.width - targetWidth) / 2
                                             : BarMetrics.notchX(screenName, root.width, targetWidth)

    property real animWidth: targetWidth
    // where the collapsed notch settles (BarMetrics.dump checks the gaps to the islands)
    onTargetXChanged: if (!expanded && !lid) BarMetrics.reportNotch(screenName, targetX, targetWidth)
    onTargetWidthChanged: if (!expanded && !lid) BarMetrics.reportNotch(screenName, targetX, targetWidth)
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

    // floating pill (B, D): soft shadow under it
    RectangularShadow {
        x: shape.x
        y: shape.y + 2
        width: shape.width
        height: shape.height
        radius: Math.min(shape.bottomRadius, height / 2)
        blur: 14
        color: Theme.alpha(Theme.islandInk, 0.55)
        opacity: shape.opacity
        visible: !root.attached && shape.height > 1
    }

    NotchShape {
        id: shape
        x: root.animX
        y: root.attached ? 0 : Theme.notchTop
        width: Math.max(0, root.animWidth)
        height: Math.max(0, root.animHeight)
        attached: root.attached
        edgeColor: IslandState.mode === "agentBlocked" && !root.expanded ? Theme.alpha(Theme.warn, 0.5) : Theme.transparent
        // floating and collapsed (B, D): always a pill, also while it peeks taller (radius = height / 2)
        bottomRadius: root.lid ? Theme.dropdownJoinRadius : root.expanded ? Theme.notchExpandedRadius : (root.attached ? Theme.notchRadius : Math.max(Theme.notchRadius, root.targetHeight / 2))
        topRadius: root.expanded ? Theme.notchFloatTopRadius : Math.max(Theme.notchRadius, root.targetHeight / 2)
        opacity: root.hidden || (root.micro && !root.microActive) ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
        Behavior on y { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Behavior on bottomRadius { NumberAnimation { duration: Theme.durContentIn; easing.type: Easing.OutCubic } }
        Behavior on topRadius { NumberAnimation { duration: Theme.durContentIn; easing.type: Easing.OutCubic } }

        // body between the ears; everything is clipped to it
        Item {
            id: body
            x: root.ear
            width: shape.width - root.ear * 2
            height: shape.height
            clip: true

            // ---- collapsed / peek content, centred in the body ----
            NotchContent {
                id: content
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2
                peek: root.peek
                maxWidth: root.maxCollapsed - root.ear * 2 - Theme.notchPadH * 2
                opacity: root.expanded || root.micro ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.durContentOut } }
            }

            // ---- style D micro-island: equalizer · recording dot · thinking core ----
            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                opacity: root.micro && root.microActive ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
                Rectangle {
                    visible: Toggles.isRecording
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Theme.error
                }
                NeuralCore {
                    identity: Theme.coreIdentity
                    visible: (Herdr.counts?.working ?? 0) > 0 || IslandState.mode === "agentBlocked"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    mood: "thinking"
                    fps: 6
                    reducedMotion: !Theme.animationsEnabled
                    running: visible && Theme.animationsEnabled
                }
                Equalizer {
                    visible: Media.isPlaying
                    anchors.verticalCenter: parent.verticalCenter
                    playing: Media.isPlaying
                    barHeight: 10
                }
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
            // the wheel over the volume OSD keeps adjusting it without opening the panel
            onWheel: w => {
                if (IslandState.mode === "osd" && (Osd.kind === "volume" || Osd.kind === "mic")) {
                    const d = w.angleDelta.y > 0 ? 0.05 : -0.05;
                    if (Osd.kind === "mic") Audio.setMicVolume(Audio.micVolume + d); else Audio.setVolume(Audio.volume + d);
                } else w.accepted = false;
            }
            onClicked: m => {
                if (IslandState.mode === "agentBlocked" && m.button === Qt.LeftButton) Herdr.focusAgent(IslandState.blockedAgent);
                // recording: stop the shell's own recording; another app capturing → which one (privacy popover)
                else if (IslandState.mode === "recording" && m.button === Qt.LeftButton) {
                    if (RecordingMode.shellRecording) RecordingMode.stop(); else ShellState.open("privacy", root.screenName);
                }
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
