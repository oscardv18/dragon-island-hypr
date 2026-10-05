// Closed-island content, chosen by IslandState.mode (priority handled there):
//   osd · notif · workspace · media · clock
import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    readonly property string mode: IslandState.mode
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: Theme.islandHeight
    width: implicitWidth
    height: implicitHeight

    Loader {
        id: loader
        anchors.centerIn: parent
        sourceComponent: {
            switch (root.mode) {
                case "osd":       return osdView;
                case "notif":     return notifView;
                case "workspace": return workspaceView;
                case "media":     return mediaView;
                default:          return clockView;
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
        Row {
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
                    running: Toggles.isRecording
                    loops: Animation.Infinite
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
    }

    // ---- now playing: art 24×24 r7 · title · "· app" · equalizer ----
    Component {
        id: mediaView
        Row {
            spacing: Theme.spacingSm
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
                width: Math.min(implicitWidth, Theme.islandMediaTitleMax)
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                visible: Media.identity.length > 0
                text: `· ${Media.identity}`
                color: Theme.textDim
                width: Math.min(implicitWidth, Theme.islandMediaTitleMax / 2)
            }
            Equalizer {
                anchors.verticalCenter: parent.verticalCenter
                playing: Media.isPlaying
                barHeight: Theme.iconSm
            }
        }
    }

    // ---- workspace change ----
    Component {
        id: workspaceView
        Row {
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
    }

    // ---- incoming notification ----
    Component {
        id: notifView
        Row {
            id: nrow
            readonly property var n: IslandState.notification
            readonly property string iconSrc: Notifs.iconFor(n)
            spacing: Theme.spacingSm

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.islandIcon
                height: Theme.islandIcon
                IconImage {
                    anchors.fill: parent
                    source: nrow.iconSrc
                    visible: nrow.iconSrc.length > 0
                    asynchronous: true
                }
                Glyph {
                    anchors.centerIn: parent
                    visible: nrow.iconSrc.length === 0
                    icon: Icons.bellRing
                    size: Theme.iconMd
                    color: Notifs.isCritical(nrow.n) ? Theme.error : Theme.accent
                }
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: nrow.n?.summary || nrow.n?.appName || "Notificación"
                weight: Theme.weightMedium
                width: Math.min(implicitWidth, Theme.islandNotifMax)
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                visible: (nrow.n?.appName ?? "").length > 0
                text: `· ${nrow.n?.appName ?? ""}`
                color: Theme.textDim
                width: Math.min(implicitWidth, Theme.islandNotifMax / 2)
            }
        }
    }

    // ---- OSD: icon · bar · value ----
    Component {
        id: osdView
        Row {
            spacing: Theme.spacingSm + Theme.spacingXs
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.named(Osd.icon)
                size: Theme.iconLg
                color: Osd.isMuted ? Theme.textDim : Theme.text
            }
            ProgressBar {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.islandOsdBar
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
    }
}
