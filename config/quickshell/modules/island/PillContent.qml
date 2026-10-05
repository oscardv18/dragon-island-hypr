// Closed-island content, chosen by IslandState.mode (priority handled there):
//   osd · workspace · media · clock   (notifications appear as popups, not here)
import QtQuick
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
