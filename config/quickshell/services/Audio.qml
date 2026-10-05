// =============================================================================
// dragon-island — Audio.qml
// Service: PipeWire volume, devices and per-app mixer
// =============================================================================
/**
 * Properties:
 *   - ready: bool [readonly] (initial PipeWire sync done)
 *   - sink / source: PwNode [readonly] (current default output / input, may be null)
 *   - volume: real [readonly] (0.0 - 1.0)        volumePct: int [readonly]
 *   - muted: bool [readonly]
 *   - sinkName: string [readonly]
 *   - micVolume: real [readonly]                  micVolumePct: int [readonly]
 *   - micMuted: bool [readonly]
 *   - sourceName: string [readonly]
 *   - sinks: list<PwNode> [readonly] (hardware outputs)
 *   - sources: list<PwNode> [readonly] (hardware inputs)
 *   - streams: list<PwNode> [readonly] (applications playing audio, for the mixer)
 *
 * Functions:
 *   - setVolume(vol: real): void          setVolumePct(pct: int): void
 *   - toggleMute(): void
 *   - setMicVolume(vol: real): void        toggleMicMute(): void
 *   - setDefaultSink(node: PwNode): void   setDefaultSource(node: PwNode): void
 *   - nodeName(node: PwNode): string      (human readable name of a device or app)
 *   - nodeIcon(node: PwNode): string      (icon name hint, may be "")
 *   - setNodeVolume(node: PwNode, vol: real): void
 *   - toggleNodeMute(node: PwNode): void
 *
 * Change notifications: use the property signals (volumeChanged, mutedChanged, …).
 * Osd.qml listens to them; there are no custom signals (they would clash with them).
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property bool ready: Pipewire.ready

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0.0
    readonly property int volumePct: Math.round(volume * 100)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string sinkName: nodeName(sink) || "Salida de audio"

    readonly property real micVolume: source?.audio?.volume ?? 0.0
    readonly property int micVolumePct: Math.round(micVolume * 100)
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string sourceName: nodeName(source) || "Micrófono"

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    // application playback streams output audio towards a sink → isSink === false
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink)

    // Bind default devices and app streams so volume/mute/properties are valid
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(root.streams)
    }

    function clamp01(v: real): real { return Math.max(0.0, Math.min(1.0, v)); }

    function setVolume(vol: real): void { if (sink?.audio) sink.audio.volume = clamp01(vol); }
    function setVolumePct(pct: int): void { setVolume(pct / 100.0); }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }

    function setMicVolume(vol: real): void { if (source?.audio) source.audio.volume = clamp01(vol); }
    function toggleMicMute(): void { if (source?.audio) source.audio.muted = !source.audio.muted; }

    function setDefaultSink(node: PwNode): void { if (node) Pipewire.preferredDefaultAudioSink = node; }
    function setDefaultSource(node: PwNode): void { if (node) Pipewire.preferredDefaultAudioSource = node; }

    function nodeName(node: PwNode): string {
        if (!node) return "";
        if (node.isStream) {
            const p = node.properties ?? {};
            return p["application.name"] || node.nickname || node.description || node.name || "";
        }
        return node.description || node.nickname || node.name || "";
    }

    function nodeIcon(node: PwNode): string {
        if (!node || !node.properties) return "";
        return node.properties["application.icon-name"] || node.properties["application.process.binary"] || "";
    }

    function setNodeVolume(node: PwNode, vol: real): void { if (node?.audio) node.audio.volume = clamp01(vol); }
    function toggleNodeMute(node: PwNode): void { if (node?.audio) node.audio.muted = !node.audio.muted; }
}
