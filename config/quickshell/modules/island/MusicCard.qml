// Music of the isla de mando (31-isla-mando.png, proposal A): art · title · artist · app · wave · progress · time ·
// previous / play-pause (white disc) / next. The wave is real when cava is installed (services/Cava.qml, only while
// this card exists and something plays); otherwise soft decorative bars that move only while playing and stay still
// with reduced motion. No player: «Nada sonando» and the last player used.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root
    radius: Theme.hudCardRadius
    color: Theme.cmdFill
    border.width: 1
    border.color: Theme.cmdEdge

    readonly property bool playing: Media.isPlaying
    readonly property bool realWave: Cava.available && Cava.bars.length > 0
    Component.onCompleted: Cava.want(true)
    Component.onDestruction: Cava.want(false)

    // decorative wave: a slow phase, ~12 fps, only while playing and motion is allowed
    property real phase: 0
    Timer {
        interval: 83
        repeat: true
        running: root.playing && !root.realWave && !Settings.calmMotion && Theme.animationsEnabled && root.visible
        onTriggered: root.phase += 0.35
    }
    function decoBar(i: int): real {
        const base = 0.25 + 0.2 * Math.sin(i * 1.7) + 0.15 * Math.sin(i * 0.6 + 1);
        return Math.max(0.12, Math.min(1, base + (root.playing ? 0.3 * Math.sin(root.phase + i * 0.9) * Math.sin(root.phase * 0.37 + i) : 0)));
    }

    ColumnLayout {
        visible: Media.hasPlayer
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingXs + 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            ClippingRectangle {
                Layout.preferredWidth: Theme.cmdArt
                Layout.preferredHeight: Theme.cmdArt
                radius: 10
                color: Theme.surface3
                Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: Media.artUrl.length > 0 }
                Glyph { anchors.centerIn: parent; visible: Media.artUrl.length === 0; icon: Icons.music; size: Theme.iconLg; color: Theme.textDim }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                UiText { Layout.fillWidth: true; text: Media.title || "Sin título"; weight: Theme.weightSemiBold; size: Theme.sizeBodyLg }
                UiText { Layout.fillWidth: true; text: [Media.artist, Media.identity].filter(x => x).join(" · "); size: Theme.sizeCaption + 1.5; color: Theme.textDim }
                // the wave
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    spacing: 2
                    Repeater {
                        model: Theme.waveBars
                        delegate: Item {
                            required property int index
                            width: 3
                            height: 18
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: 1
                                height: Math.max(2, parent.height * (root.realWave ? (Cava.bars[index] ?? 0) : root.decoBar(index)))
                                color: index < Theme.waveBars * Media.progress ? Theme.lavender : Theme.alpha(Theme.lavender, 0.35)
                            }
                        }
                    }
                }
            }
        }
        // progress
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.hudSegOff }
            Rectangle { width: parent.width * Media.progress; height: parent.height; radius: 1.5; color: Theme.text }
            MouseArea { anchors.fill: parent; anchors.margins: -4; enabled: Media.canSeek; cursorShape: Qt.PointingHandCursor; onClicked: m => Media.setPosition(Media.length * m.x / width) }
        }
        RowLayout {
            Layout.fillWidth: true
            UiText { Layout.fillWidth: true; text: `${Media.positionText} / ${Media.lengthText}`; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
            IconButton { icon: Icons.previous; size: 26; iconSize: Theme.iconSm; bgColor: Theme.transparent; enabled: Media.canGoPrevious; onClicked: Media.previous() }
            Rectangle {
                width: 30; height: 30; radius: 15
                color: Theme.text
                Glyph { anchors.centerIn: parent; icon: Media.isPlaying ? Icons.pause : Icons.play; size: Theme.iconMd; color: Theme.islandInk }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.playPause() }
            }
            IconButton { icon: Icons.next; size: 26; iconSize: Theme.iconSm; bgColor: Theme.transparent; enabled: Media.canGoNext; onClicked: Media.next() }
        }
    }

    Column {
        visible: !Media.hasPlayer
        anchors.centerIn: parent
        spacing: Theme.spacingXs
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; icon: Icons.music; size: Theme.iconLg; color: Theme.muted }
        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Nada sonando"; color: Theme.textSoft; weight: Theme.weightMedium }
        HudCaption { anchors.horizontalCenter: parent.horizontalCenter; visible: Media.lastIdentity.length > 0; text: `último: ${Media.lastIdentity}` }
    }
}
