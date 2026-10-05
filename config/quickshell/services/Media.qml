// =============================================================================
// dragon-island — Media.qml
// Service: MPRIS media players
// =============================================================================
/**
 * Properties:
 *   - player: MprisPlayer [readonly] (playing player first, else the first one, else null)
 *   - players: list<MprisPlayer> [readonly]
 *   - hasPlayer: bool [readonly]
 *   - isPlaying: bool [readonly]
 *   - title / artist / album / artUrl / identity: string [readonly]
 *   - position: real [readonly] (seconds, refreshed every second while playing)
 *   - length: real [readonly] (seconds)
 *   - progress: real [readonly] (0.0 - 1.0)
 *   - positionText / lengthText: string [readonly] ("2:07")
 *   - canPlay / canPause / canGoNext / canGoPrevious / canSeek: bool [readonly]
 *
 * Functions:
 *   - playPause(): void
 *   - play(): void
 *   - pause(): void
 *   - next(): void
 *   - previous(): void
 *   - seek(offset: real): void
 *   - setPosition(seconds: real): void
 *   - formatTime(seconds: real): string
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

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player?.isPlaying ?? false

    readonly property string title:    player?.trackTitle || ""
    readonly property string artist:   player?.trackArtist || ""
    readonly property string album:    player?.trackAlbum || ""
    readonly property string artUrl:   player?.trackArtUrl || ""
    readonly property string identity: player?.identity || ""

    // `position` is not reactive by itself; the timer below re-emits positionChanged (see MprisPlayer docs)
    readonly property real position: player?.position ?? 0
    readonly property real length: player?.length ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property string positionText: formatTime(position)
    readonly property string lengthText: formatTime(length)

    readonly property bool canPlay:       player?.canPlay ?? false
    readonly property bool canPause:      player?.canPause ?? false
    readonly property bool canGoNext:     player?.canGoNext ?? false
    readonly property bool canGoPrevious: player?.canGoPrevious ?? false
    readonly property bool canSeek:       player?.canSeek ?? false

    Timer {
        interval: 1000
        repeat: true
        running: root.isPlaying
        onTriggered: root.player?.positionChanged()
    }

    Connections {
        target: root.player
        function onTrackChanged() { root.trackChanged(root.title, root.artist); }
        function onIsPlayingChanged() { root.playbackStateChanged(root.isPlaying); }
    }

    function formatTime(seconds: real): string {
        if (!(seconds > 0)) return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const h = Math.floor(m / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m % 60).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    function playPause(): void { if (player?.canTogglePlaying) player.togglePlaying(); }
    function play(): void { if (player?.canPlay) player.play(); }
    function pause(): void { if (player?.canPause) player.pause(); }
    function next(): void { if (player?.canGoNext) player.next(); }
    function previous(): void { if (player?.canGoPrevious) player.previous(); }
    function seek(offset: real): void { if (player?.canSeek) player.seek(offset); }
    function setPosition(seconds: real): void {
        if (player?.canSeek && player.positionSupported) player.position = Math.max(0, Math.min(root.length, seconds));
    }

    signal trackChanged(title: string, artist: string)
    signal playbackStateChanged(playing: bool)
}
