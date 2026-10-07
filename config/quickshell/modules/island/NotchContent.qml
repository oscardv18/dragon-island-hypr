// Collapsed-notch content, chosen by IslandState.mode (priority handled there):
//   osd · notification · workspace · media · clock
// Every mode is a primary line plus a secondary line that only shows while the notch peeks
// (hover or transient state). `maxWidth` is the room the notch has between the bar islands.
import QtQuick
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
                case "osd":          return osdView;
                case "notification": return notifView;
                case "workspace":    return workspaceView;
                case "media":        return mediaView;
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

    // ---- now playing: art 22×22 · title · "· app" · equalizer ----
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
                            color: current ? Theme.accent : (Hypr.workspaces[index]?.occupied ? Theme.textSoft : Theme.muted)
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
