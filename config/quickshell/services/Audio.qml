// =============================================================================
// dragon-island — Audio.qml
// Service: PipeWire Audio & Volume Control
// =============================================================================
/**
 * Properties:
 *   - volume: real [readonly] (0.0 - 1.0 normalized)
 *   - volumePct: int [readonly] (0 - 100)
 *   - muted: bool [readonly]
 *   - sinkName: string [readonly]
 *   - micVolume: real [readonly] (0.0 - 1.0 normalized)
 *   - micVolumePct: int [readonly] (0 - 100)
 *   - micMuted: bool [readonly]
 *   - sourceName: string [readonly]
 *   - sinks: list<PwNode> [readonly] (available audio output sinks)
 *
 * Functions:
 *   - setVolume(vol: real): void
 *   - setVolumePct(pct: int): void
 *   - toggleMute(): void
 *   - setMicVolume(vol: real): void
 *   - toggleMicMute(): void
 *   - setDefaultSink(node: PwNode): void
 *
 * Signals:
 *   - volumeChanged(volPct: int, isMuted: bool)
 *   - micVolumeChanged(volPct: int, isMuted: bool)
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Volume normalized 0.0 - 1.0
    readonly property real volume: sink?.audio?.volume ?? 0.0
    readonly property int volumePct: Math.round(volume * 100)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string sinkName: sink?.description || sink?.name || "Audio"

    // Microphone volume
    readonly property real micVolume: source?.audio?.volume ?? 0.0
    readonly property int micVolumePct: Math.round(micVolume * 100)
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string sourceName: source?.description || source?.name || "Micrófono"

    // Available sinks list
    readonly property var sinks: {
        return Pipewire.nodes.values.filter(n => n.isSink && n.audio !== null && !n.isStream);
    }

    // Tracker: binds PipeWire nodes so their audio properties become available
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
    }

    function setVolume(vol: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, vol));
        if (sink?.audio) {
            sink.audio.volume = clamped;
        }
    }

    function setVolumePct(pct: int): void {
        setVolume(pct / 100.0);
    }

    function toggleMute(): void {
        if (sink?.audio) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    function setMicVolume(vol: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, vol));
        if (source?.audio) {
            source.audio.volume = clamped;
        }
    }

    function toggleMicMute(): void {
        if (source?.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }

    function setDefaultSink(node: PwNode): void {
        if (node) {
            Pipewire.preferredDefaultAudioSink = node;
        }
    }

    signal volumeChanged(volPct: int, isMuted: bool)
    signal micVolumeChanged(volPct: int, isMuted: bool)

    onVolumePctChanged: root.volumeChanged(root.volumePct, root.muted)
    onMutedChanged: root.volumeChanged(root.volumePct, root.muted)
    onMicVolumePctChanged: root.micVolumeChanged(root.micVolumePct, root.micMuted)
    onMicMutedChanged: root.micVolumeChanged(root.micVolumePct, root.micMuted)
}
