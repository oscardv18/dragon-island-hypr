// Dashboard media card: art · title / artist / app · progress · controls (empty state without a player)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Card {
    id: root
    spacing: Theme.spacingMd

    // ---- no player ----
    RowLayout {
        visible: !Media.hasPlayer
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.artLarge
        spacing: Theme.spacingMd

        Rectangle {
            Layout.preferredWidth: Theme.artLarge
            Layout.preferredHeight: Theme.artLarge
            radius: Theme.artLargeRadius
            color: Theme.surface3
            Glyph {
                anchors.centerIn: parent
                icon: Icons.music
                size: Theme.iconLg + Theme.spacingSm
                color: Theme.textDim
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            UiText { text: "Nada en reproducción"; weight: Theme.weightMedium }
            UiText { text: "Abre Spotify, un vídeo o un podcast"; size: Theme.sizeCaption + 1; color: Theme.textDim; Layout.fillWidth: true }
        }
    }

    // ---- player ----
    RowLayout {
        visible: Media.hasPlayer
        Layout.fillWidth: true
        spacing: Theme.spacingMd

        ArtImage {
            Layout.preferredWidth: Theme.artLarge
            Layout.preferredHeight: Theme.artLarge
            radius: Theme.artLargeRadius
            source: Media.artUrl
            iconSize: Theme.iconLg + Theme.spacingSm
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs / 2
            UiText {
                Layout.fillWidth: true
                text: Media.title || "Sin título"
                size: Theme.sizeBodyLg
                weight: Theme.weightSemiBold
            }
            UiText {
                Layout.fillWidth: true
                text: Media.artist
                visible: text.length > 0
                color: Theme.textSoft
            }
            UiText {
                Layout.fillWidth: true
                caption: true
                text: Media.identity
            }
        }
    }

    ColumnLayout {
        visible: Media.hasPlayer && Media.length > 0
        Layout.fillWidth: true
        spacing: Theme.spacingXs

        ProgressBar {
            Layout.fillWidth: true
            value: Media.progress
            brand: true
            thickness: Theme.trackHeight - 2
        }
        RowLayout {
            Layout.fillWidth: true
            UiText { text: Media.positionText; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
            Item { Layout.fillWidth: true }
            UiText { text: Media.lengthText; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
        }
    }

    Row {
        visible: Media.hasPlayer
        Layout.alignment: Qt.AlignHCenter
        spacing: Theme.spacingMd

        IconButton {
            icon: Icons.previous
            enabled: Media.canGoPrevious
            bgColor: Theme.transparent
            onClicked: Media.previous()
        }
        IconButton {
            icon: Media.isPlaying ? Icons.pause : Icons.play
            brand: true
            radius: Theme.touchTarget / 2
            onClicked: Media.playPause()
        }
        IconButton {
            icon: Icons.next
            enabled: Media.canGoNext
            bgColor: Theme.transparent
            onClicked: Media.next()
        }
    }
}
