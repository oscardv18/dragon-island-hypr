// =============================================================================
// dragon-island — Media.qml
// Service: MPRIS Media Player Interface
// =============================================================================
/**
 * Properties:
 *   - hasPlayer: bool [readonly]
 *   - isPlaying: bool [readonly]
 *   - title: string [readonly]
 *   - artist: string [readonly]
 *   - album: string [readonly]
 *   - artUrl: string [readonly]
 *   - identity: string [readonly]
 *   - position: real [readonly] (current track position in seconds)
 *   - length: real [readonly] (track length in seconds)
 *   - canPlay: bool [readonly]
 *   - canPause: bool [readonly]
 *   - canGoNext: bool [readonly]
 *   - canGoPrevious: bool [readonly]
 *
 * Functions:
 *   - playPause(): void
 *   - play(): void
 *   - pause(): void
 *   - next(): void
 *   - previous(): void
 *   - seek(offset: real): void
 *
 * Signals:
 *   - trackChanged(title: string, artist: string)
 *   - playbackStateChanged(playing: bool)
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Select playing player first, fallback to first available player
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player?.isPlaying ?? false

    readonly property string title:    player?.trackTitle || ""
    readonly property string artist:   player?.trackArtist || ""
    readonly property string album:    player?.trackAlbum || ""
    readonly property string artUrl:   player?.trackArtUrl || ""
    readonly property string identity: player?.identity || ""

    property real position: player?.position ?? 0
    readonly property real length: player?.length ?? 0

    readonly property bool canPlay:        player?.canPlay ?? false
    readonly property bool canPause:       player?.canPause ?? false
    readonly property bool canGoNext:      player?.canGoNext ?? false
    readonly property bool canGoPrevious:  player?.canGoPrevious ?? false

    // Update position regularly when playing
    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player) {
                root.position = root.player.position;
            }
        }
    }

    Connections {
        target: root.player
        function onTrackChanged() {
            root.position = root.player?.position ?? 0;
            root.trackChanged(root.title, root.artist);
        }
        function onPlaybackStateChanged() {
            root.playbackStateChanged(root.isPlaying);
        }
    }

    function playPause(): void {
        player?.togglePlaying();
    }

    function play(): void {
        player?.play();
    }

    function pause(): void {
        player?.pause();
    }

    function next(): void {
        player?.next();
    }

    function previous(): void {
        player?.previous();
    }

    function seek(offset: real): void {
        player?.seek(offset);
    }

    signal trackChanged(title: string, artist: string)
    signal playbackStateChanged(playing: bool)
}
