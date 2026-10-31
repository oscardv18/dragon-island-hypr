// Collapsed-notch content, chosen by IslandState.mode (priority table in services/IslandState.qml):
//   capture · dropdown · recording · osd · agentBlocked · notification · notice · idleWarn · workspace · tiling ·
//   agentWorking · focus · commandDone · media · window · date · clock
// Every mode is a primary line plus a secondary line that only shows while the notch peeks
// (hover or transient state). `maxWidth` is the room the notch has between the bar islands.
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool peek: false
    property bool paused: false          // the island is hidden (fullscreen) or expanded: nothing here may animate
    readonly property bool animate: Theme.animationsEnabled && !paused
    property real maxWidth: 300

    readonly property string mode: IslandState.mode
    // No molestar: no drop and no card (Notifs.popups stays empty), only this counter of what arrived meanwhile
    readonly property real _badgeW: dndBadge.visible ? dndBadge.implicitWidth + Theme.spacingSm : 0
    implicitWidth: (loader.item ? loader.item.implicitWidth : 0) + _badgeW
    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    // secondary line: dim, 12 px, grows in only while peeking
    component PeekLine: UiText {
        property real limit: Theme.notchPeekLine
        size: Theme.sizeCaption + 1
        color: Theme.textDim
        horizontalAlignment: Text.AlignHCenter
        width: Math.min(implicitWidth, limit, root.maxWidth)
        opacity: root.peek ? 1 : 0
        height: root.peek ? implicitHeight : 0
        visible: height > 0.5
        Behavior on opacity { NumberAnimation { duration: Theme.durFade; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.durFade; easing.type: Easing.OutCubic } }
    }

    Row {
        id: dndBadge
        visible: Notifs.dnd && Notifs.unreadCount > 0 && ["osd", "capture", "dropdown", "recording"].indexOf(root.mode) < 0
        anchors.right: parent.right
        anchors.verticalCenter: loader.verticalCenter
        spacing: Theme.spacingXs
        Glyph { icon: Icons.bellOff; size: Theme.iconSm; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
        UiText { text: Notifs.unreadCount; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
    }

    Loader {
        id: loader
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root._badgeW / 2
        sourceComponent: {
            switch (root.mode) {
                case "capture":      return captureView;
                case "dropdown":     return dropdownView;
                case "recording":    return recordingView;
                case "osd":          return osdView;
                case "agentBlocked": return agentBlockedView;
                case "notice":       return noticeView;
                case "idleWarn":     return idleWarnView;
                case "agentWorking": return agentWorkingView;
                case "focus":        return focusView;
                case "commandDone":  return commandDoneView;
                case "tiling":       return tilingView;
                case "notification": return notifView;
                case "workspace":    return workspaceView;
                case "media":        return mediaView;
                case "window":       return windowView;
                case "date":         return dateView;
                default:             return clockView;
            }
        }
        onLoaded: {
            item.opacity = 0;
            fadeIn.restart();
        }
    }

    NumberAnimation {
        id: fadeIn
        target: loader.item
        property: "opacity"
        to: 1
        duration: Theme.durFade
        easing.type: Easing.OutCubic
    }

    // ---- clock with status dot ----
    Component {
        id: clockView
        Column {
            spacing: 1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm
                Rectangle {
                    id: dot
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.statusDot
                    height: width
                    radius: width / 2
                    color: Toggles.isRecording ? Theme.error
                         : (Notifs.dnd ? Theme.muted : (Notifs.hasUnread ? Theme.accent : Theme.ok))
                    SequentialAnimation on opacity {
                        running: Toggles.isRecording && root.animate
                        loops: Animation.Infinite
                        onStopped: dot.opacity = 1
                        NumberAnimation { to: 0.3; duration: Theme.ms(600) }
                        NumberAnimation { to: 1; duration: Theme.ms(600) }
                    }
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.time
                    mono: true
                    size: Theme.sizeBodyLg
                    weight: Theme.weightSemiBold
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Clock.shortDate
            }
        }
    }

    // ---- focused window (islandContent "window"): icon · context title · chip in the peek line ----
    Component {
        id: windowView
        Column {
            spacing: 1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    source: WindowContext.icon
                    implicitSize: Theme.iconSm
                    asynchronous: true
                    visible: WindowContext.icon.length > 0
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Hypr.activeTitle || WindowContext.title
                    weight: Theme.weightMedium
                    width: Math.min(implicitWidth, Theme.notchMediaTitleMax, Math.max(60, root.maxWidth - Theme.iconSm - Theme.spacingSm))
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                text: [WindowContext.appName, WindowContext.chip].filter(s => s.length > 0).join(" · ")
            }
        }
    }

    // ---- date (islandContent "date"): lavender dot · weekday day month · time ----
    Component {
        id: dateView
        Row {
            spacing: Theme.spacingSm
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: Theme.lavender }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: Clock.dateFormatted; weight: Theme.weightMedium; color: Theme.textSoft }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: Clock.time; mono: true; weight: Theme.weightSemiBold }
        }
    }

    // ---- now playing: art 18×18 · title · "· app" · equalizer ----
    Component {
        id: mediaView
        Column {
            spacing: 1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm
                readonly property real budget: Math.max(60, root.maxWidth - Theme.artSmall - Theme.iconSm - Theme.spacingSm * 3)
                ArtImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.artSmall
                    height: Theme.artSmall
                    radius: Theme.artSmallRadius
                    source: Media.artUrl
                    iconSize: Theme.iconSm
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.title
                    weight: Theme.weightMedium
                    width: Math.min(implicitWidth, Theme.notchMediaTitleMax, parent.budget * 0.7)
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Media.identity.length > 0 && parent.budget > 150
                    text: `· ${Media.identity}`
                    color: Theme.textDim
                    width: Math.min(implicitWidth, Theme.notchMediaTitleMax / 2, parent.budget * 0.3)
                }
                Equalizer {
                    anchors.verticalCenter: parent.verticalCenter
                    playing: Media.isPlaying && !root.paused
                    barHeight: Theme.iconSm
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                text: [Media.artist, Media.album].filter(s => s.length > 0).join(" · ") || Media.identity
            }
        }
    }

    // ---- workspace change ----
    Component {
        id: workspaceView
        Column {
            spacing: 1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.desktop
                    size: Theme.iconMd
                    color: Theme.textSoft
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Escritorio ${IslandState.workspaceId}`
                    weight: Theme.weightMedium
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXs
                    Repeater {
                        model: Hypr.workspaceCount
                        delegate: Rectangle {
                            required property int index
                            readonly property bool current: index + 1 === IslandState.workspaceId
                            width: current ? Theme.pillDot * 3 : Theme.pillDot + 1
                            height: Theme.pillDot + 1
                            radius: height / 2
                            color: current ? Theme.lavender : (Hypr.workspaces[index]?.occupied ? Theme.textSoft : Theme.muted)
                            Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property int windows: Hypr.workspaces[IslandState.workspaceId - 1]?.windows ?? 0
                text: windows === 0 ? "Vacío" : (windows === 1 ? "1 ventana" : `${windows} ventanas`)
            }
        }
    }

    // ---- OSD (docs/design/09-isla.png) ----
    //   volume / mic  level icon · device name above a 5 px bar · value (mono 14 semibold), ~300 wide
    //   brightness    sun (sunWarm, warn with the night light) · bar · value, ~260 wide
    //   capslock      arrow in warn · "BLOQ MAYÚS" (mono 11, tracked); turning it off shows the pill with a dim arrow
    //   layout        "US → LA" in mono
    Component {
        id: osdView
        Item {
            readonly property string k: Osd.kind
            implicitWidth: k === "capslock" ? capsRow.implicitWidth : (k === "layout" ? layoutRow.implicitWidth : (k === "brightness" ? Theme.osdWidthBrightness : Theme.osdWidthVolume))
            implicitHeight: Math.max(levelRow.implicitHeight, Theme.iconLg)

            Row {
                id: levelRow
                visible: parent.k === "volume" || parent.k === "mic" || parent.k === "brightness"
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: Theme.spacingMd
                readonly property bool sun: parent.k === "brightness"
                readonly property color fill: sun ? (Toggles.nightLight ? Theme.warn : Theme.sunWarm) : Theme.text
                Glyph {
                    id: osdIcon
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.named(Osd.icon)
                    size: Theme.iconLg
                    color: parent.sun ? parent.fill : (Osd.isMuted ? Theme.textDim : Theme.text)
                    Behavior on color { ColorAnimation { duration: Theme.durStd } }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - osdIcon.width - osdValue.width - parent.spacing * 2
                    spacing: 3
                    UiText {
                        visible: !parent.parent.sun && Osd.device.length > 0
                        width: parent.width
                        text: Osd.device
                        size: Theme.sizeCaption
                        color: Theme.textDim
                    }
                    Item {
                        width: parent.width
                        height: Theme.osdBar
                        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.trackFaint }
                        Rectangle {
                            width: parent.width * (Osd.isMuted ? 0 : Osd.value)
                            height: parent.height
                            radius: height / 2
                            color: levelRow.fill
                            Behavior on width { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
                        }
                    }
                }
                UiText {
                    id: osdValue
                    anchors.verticalCenter: parent.verticalCenter
                    text: Osd.isMuted ? "—" : `${Math.round(Osd.value * 100)}`
                    mono: true
                    size: 14
                    weight: Theme.weightSemiBold
                    width: 30
                    horizontalAlignment: Text.AlignRight
                }
            }

            Row {
                id: capsRow
                visible: parent.k === "capslock"
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                Glyph { anchors.verticalCenter: parent.verticalCenter; icon: Icons.arrowUp; size: Theme.iconMd; color: Osd.capsOn ? Theme.warn : Theme.muted }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: "BLOQ MAYÚS"; mono: true; size: Theme.sizeCaption; weight: Theme.weightSemiBold; font.letterSpacing: Theme.sizeCaption * 0.08; color: Osd.capsOn ? Theme.text : Theme.textDim }
            }

            Row {
                id: layoutRow
                visible: parent.k === "layout"
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                UiText { anchors.verticalCenter: parent.verticalCenter; text: Osd.layoutFrom; mono: true; color: Theme.textDim }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: "→"; mono: true; color: Theme.textDim }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: Osd.layoutTo; mono: true; weight: Theme.weightSemiBold }
            }
        }
    }

    // ---- tiling mode switched: icon · text (no sound) ----
    Component {
        id: tilingView
        Row {
            spacing: Theme.spacingSm
            CoreIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: Tiling.scrolling ? "columns" : "grid"
                size: Theme.iconLg
                color: Theme.text
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: IslandState.tilingText
                weight: Theme.weightSemiBold
            }
        }
    }

    // ---- agents working: mini core thinking · "Pensando…" · workspace of the longest one (or "N agentes trabajando")
    Component {
        id: agentWorkingView
        Row {
            spacing: Theme.spacingSm
            readonly property var list: IslandState.workingAgents
            Core {
                identity: Theme.coreIdentity
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.notchHeight - 8
                height: width
                mood: "thinking"
                // 6 fps while thinking (NeuralCore doubles `fps` off calm): it can stay on for hours while agents work and
                // every frame repaints the whole 1366 × 270 island window (pulido: 12 → 6 fps, 8,0 → 6,3 % of CPU)
                fps: 3
                reducedMotion: !Theme.animationsEnabled
                running: root.animate && !Settings.calmMotion
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.list.length > 1 ? `${parent.list.length} agentes trabajando` : "Pensando…"
                weight: Theme.weightSemiBold
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.list.length === 1
                text: (Herdr.longestWorking ?? parent.list[0])?.workspace ?? ""
                color: Theme.textDim
                width: Math.min(implicitWidth, Math.max(60, root.maxWidth - 140))
            }
        }
    }

    // ---- an agent waits for an answer: warn dot pulsing (1.6 s) · "<workspace> espera tu respuesta" ----
    Component {
        id: agentBlockedView
        Row {
            spacing: Theme.spacingSm
            readonly property var a: IslandState.blockedAgent
            Rectangle {
                id: waitDot
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.statusDot
                height: width
                radius: width / 2
                color: Theme.warn
                SequentialAnimation on opacity {
                    running: root.animate
                    loops: Animation.Infinite
                    onStopped: waitDot.opacity = 1
                    NumberAnimation { to: 0.35; duration: Theme.ms(800); easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Theme.ms(800); easing.type: Easing.InOutSine }
                }
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${parent.a?.workspace || parent.a?.name || "Un agente"} espera tu respuesta`
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, Math.max(80, root.maxWidth - Theme.statusDot - Theme.spacingSm))
            }
        }
    }

    // ---- a long command / an agent finished: ✓ ok or ✗ error · command (mono, elided) · duration ----
    Component {
        id: commandDoneView
        Row {
            spacing: Theme.spacingSm
            readonly property var d: IslandState.done
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                icon: parent.d?.ok ? Icons.check : Icons.close
                size: Theme.iconMd
                color: parent.d?.ok ? Theme.ok : Theme.error
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.d?.text ?? ""
                mono: parent.d?.kind === "command"
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, Math.max(80, root.maxWidth * 0.6))
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.d?.kind === "command"
                text: parent.d?.detail ?? ""
                mono: true
                color: Theme.textDim
            }
        }
    }

    // ---- a short shell notice: icon · text ----
    Component {
        id: noticeView
        Row {
            spacing: Theme.spacingSm
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: IslandState.noticeIcon.length > 0
                icon: Icons[IslandState.noticeIcon] ?? ""
                size: Theme.iconMd
                color: Theme.cyan
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: IslandState.noticeText
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, root.maxWidth)
            }
        }
    }

    // ---- states filled in by their own phase-2 points (capture, drop-down, recording, idle warning, focus) ----
    Component {
        id: captureView
        UiText { text: "Captura"; weight: Theme.weightMedium }
    }
    // ---- the drop-down terminal's lid: mini core listening · Terminal ……… SUPER + ` ocultar ----
    Component {
        id: dropdownView
        Item {
            implicitWidth: Dropdown.width - Theme.notchPadH * 2
            implicitHeight: Theme.notchHeight - 6
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSm
                Core {
                    identity: Theme.coreIdentity
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.notchHeight - 8
                    height: width
                    mood: "listening"
                    fps: 6
                    reducedMotion: !Theme.animationsEnabled
                    running: root.animate
                }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: "Terminal"; weight: Theme.weightSemiBold }
            }
            UiText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "SUPER + ` ocultar"
                mono: true
                size: Theme.sizeCaption
                color: Theme.textDim
            }
        }
    }
    // ---- recording mode (docs/design/25-grabacion.png): red dot pulsing · REC · time · eq if audio · N retenidas ----
    Component {
        id: recordingView
        Row {
            spacing: Theme.spacingSm
            Rectangle {
                id: recDot
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.statusDot
                height: width
                radius: width / 2
                color: Theme.error
                SequentialAnimation on opacity {
                    running: root.animate
                    loops: Animation.Infinite
                    onStopped: recDot.opacity = 1
                    NumberAnimation { to: 0.3; duration: Theme.ms(700) }
                    NumberAnimation { to: 1; duration: Theme.ms(700) }
                }
            }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "REC"; weight: Theme.weightBold }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                readonly property int t: RecordingMode.shellRecording ? Toggles.recordingSeconds : RecordingMode.seconds
                text: `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`
                mono: true
                color: Theme.textSoft
            }
            Equalizer {
                visible: Media.isPlaying
                anchors.verticalCenter: parent.verticalCenter
                playing: Media.isPlaying && !root.paused
                barHeight: Theme.iconSm - 2
                color: Theme.ok
            }
            UiText {
                visible: !RecordingMode.shellRecording && RecordingMode.apps.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: RecordingMode.apps[0] ?? ""
                color: Theme.textDim
                width: Math.min(implicitWidth, 120)
            }
            Rectangle {
                visible: Notifs.held > 0
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: heldText.implicitWidth + 14
                radius: 6
                color: Theme.alpha(Theme.warn, 0.14)
                UiText { id: heldText; anchors.centerIn: parent; text: `${Notifs.held} retenidas`; mono: true; size: Theme.sizeCaption; color: Theme.warn }
            }
        }
    }
    // ---- the idle warning: warn dot · "Bloqueo en 60 s · mueve el ratón" (counts down) ----
    Component {
        id: idleWarnView
        Row {
            spacing: Theme.spacingSm
            property int secsLeft: Idle.lockIn
            Timer { interval: 1000; repeat: true; running: true; onTriggered: parent.secsLeft = Math.max(0, parent.secsLeft - 1) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Theme.statusDot; height: width; radius: width / 2; color: Theme.warn }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: `Bloqueo en ${parent.secsLeft} s`; weight: Theme.weightSemiBold }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "· mueve el ratón"; color: Theme.textDim }
        }
    }
    // ---- focus mode: 28 px countdown ring (track white 14 %, teal progress from the top, clockwise) ·
    //      "Enfoque · 24:12" · below, dim 10 px: what is silenced ----
    Component {
        id: focusView
        Row {
            spacing: Theme.spacingSm
            RingMeter {
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                thickness: 2.5
                value: 1 - Focus.progress
                color: Theme.focusTeal
                warnAt: 2
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Row {
                    spacing: Theme.spacingXs
                    UiText { text: "Enfoque ·"; weight: Theme.weightSemiBold }
                    UiText { text: `${String(Math.floor(Focus.remaining / 60)).padStart(2, "0")}:${String(Focus.remaining % 60).padStart(2, "0")}`; mono: true; weight: Theme.weightSemiBold }
                }
                UiText { text: Focus.summary; size: 10; color: Theme.textDim }
            }
        }
    }

    // ---- incoming notification: icon · title, app + body in the peek line ----
    Component {
        id: notifView
        Column {
            spacing: 1
            readonly property var n: IslandState.notification
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm
                ArtImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.artSmall
                    height: Theme.artSmall
                    radius: Theme.artSmallRadius
                    source: Notifs.iconFor(parent.parent.n)
                    iconSize: Theme.iconSm
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    // the sender: «Aitana · Telegram» (summary · app), as the card it is about to drop
                    text: [parent.parent.n?.summary ?? "", parent.parent.n?.appName ?? ""].filter(x => x.length > 0).join(" · ")
                    weight: Theme.weightMedium
                    width: Math.min(implicitWidth, Math.max(60, root.maxWidth - Theme.artSmall - Theme.spacingSm))
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.n?.body || parent.n?.appName || ""
            }
        }
    }
}
