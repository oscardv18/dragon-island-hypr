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
    property real maxWidth: 300

    readonly property string mode: IslandState.mode
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    // secondary line: dim, 12 px, grows in only while peeking
    component PeekLine: UiText {
        property real limit: 240
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

    Loader {
        id: loader
        anchors.centerIn: parent
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
                        running: Toggles.isRecording && Theme.animationsEnabled
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
                    playing: Media.isPlaying
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

    // ---- OSD: icon · bar · value ----
    Component {
        id: osdView
        Column {
            spacing: 1
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingSm + Theme.spacingXs
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.named(Osd.icon)
                    size: Theme.iconLg
                    color: Osd.isMuted ? Theme.textDim : Theme.text
                }
                ProgressBar {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.notchOsdBar
                    value: Osd.isMuted ? 0 : Osd.value
                    brand: true
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Osd.isMuted ? "—" : `${Math.round(Osd.value * 100)}`
                    mono: true
                    width: Theme.sizeBody * 2.2
                    horizontalAlignment: Text.AlignRight
                    color: Theme.textSoft
                }
            }
            PeekLine {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Osd.label
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
            NeuralCore {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.notchHeight - 8
                height: width
                mood: "thinking"
                reducedMotion: !Theme.animationsEnabled
                running: Theme.animationsEnabled
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
                    running: Theme.animationsEnabled
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
    Component {
        id: dropdownView
        UiText { text: "Terminal"; weight: Theme.weightMedium }
    }
    Component {
        id: recordingView
        UiText { text: "REC"; mono: true; weight: Theme.weightSemiBold; color: Theme.error }
    }
    Component {
        id: idleWarnView
        UiText { text: "Inactividad"; weight: Theme.weightMedium; color: Theme.warn }
    }
    Component {
        id: focusView
        UiText { text: "Enfoque"; weight: Theme.weightMedium }
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
                    text: parent.parent.n?.summary ?? ""
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
