// Nook media card: art 96 · title / artist / app badge · progress · prev / play / next.
// Empty state without a player.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    spacing: Theme.spacingSm

    // ---- no player ----
    RowLayout {
        visible: !Media.hasPlayer
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.spacingMd

        Rectangle {
            Layout.preferredWidth: Theme.notchArt
            Layout.preferredHeight: Theme.notchArt
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.notchArtRadius
            color: Theme.surface2
            Glyph {
                anchors.centerIn: parent
                icon: Icons.music
                size: Theme.iconLg + Theme.spacingMd
                color: Theme.textDim
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            UiText { Layout.fillWidth: true; text: "Nada en reproducción"; weight: Theme.weightMedium }
            UiText { Layout.fillWidth: true; text: "Abre un reproductor"; size: Theme.sizeCaption + 1; color: Theme.textDim }
        }
    }

    // ---- player ----
    RowLayout {
        visible: Media.hasPlayer
        Layout.fillWidth: true
        spacing: Theme.spacingMd

        ArtImage {
            Layout.preferredWidth: Theme.notchArt
            Layout.preferredHeight: Theme.notchArt
            radius: Theme.notchArtRadius
            source: Media.artUrl
            iconSize: Theme.iconLg + Theme.spacingMd
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingXs / 2

            UiText {
                Layout.fillWidth: true
                text: Media.title || "Sin título"
                size: Theme.sizeBodyLg
                weight: Theme.weightSemiBold
            }
            UiText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Media.artist
                color: Theme.textSoft
            }
            UiText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Media.album
                size: Theme.sizeCaption + 1
                color: Theme.textDim
            }
            // app badge
            Rectangle {
                visible: Media.identity.length > 0
                Layout.topMargin: Theme.spacingXs
                implicitWidth: Math.min(badge.implicitWidth + Theme.spacingSm * 2, Theme.notchMediaWidth - Theme.notchArt - Theme.spacingMd)
                implicitHeight: 20
                radius: height / 2
                color: Theme.surface3
                UiText {
                    id: badge
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingSm * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: Media.identity
                    size: Theme.sizeCaption
                    color: Theme.textSoft
                }
            }
        }
    }

    ProgressBar {
        visible: Media.hasPlayer
        Layout.fillWidth: true
        value: Media.progress
        brand: true
        thickness: Theme.trackHeight - 2
    }

    Item { visible: Media.hasPlayer; Layout.fillHeight: true; Layout.preferredHeight: 0 }

    Row {
        visible: Media.hasPlayer
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.spacingMd

        IconButton {
            icon: Icons.previous
            size: Theme.notchTile - Theme.spacingXs
            iconSize: Theme.iconMd
            enabled: Media.canGoPrevious
            bgColor: Theme.transparent
            onClicked: Media.previous()
        }
        IconButton {
            icon: Media.isPlaying ? Icons.pause : Icons.play
            size: Theme.notchTile - Theme.spacingXs
            iconSize: Theme.iconMd
            brand: true
            radius: height / 2
            onClicked: Media.playPause()
        }
        IconButton {
            icon: Icons.next
            size: Theme.notchTile - Theme.spacingXs
            iconSize: Theme.iconMd
            enabled: Media.canGoNext
            bgColor: Theme.transparent
            onClicked: Media.next()
        }
    }
}
