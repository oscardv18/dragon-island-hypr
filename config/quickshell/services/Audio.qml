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
 *   - boostMax: real [readonly] (1.5: the Sonido panel lets the volume go to 150 %)
 *   - noiseFilter: PwNode [readonly] (a noise-suppression source — a filter-chain / rnnoise / EasyEffects node — or null:
 *       «Supresión de ruido» is offered only when there is one)   noiseSuppression: bool [readonly] (it is the default input)
 *
 * Functions:
 *   - setVolume(vol: real): void          setVolumePct(pct: int): void
 *   - toggleMute(): void
 *   - setMicVolume(vol: real): void        toggleMicMute(): void
 *   - setDefaultSink(node: PwNode): void   setDefaultSource(node: PwNode): void
 *   - nodeName(node: PwNode): string      (human readable name of a device or app)
 *   - nodeIcon(node: PwNode): string      (icon name hint, may be "")
 *   - setNodeVolume(node: PwNode, vol: real): void (clamped to 0 – 1; setNodeVolumeBoost allows up to boostMax)
 *   - setVolumeBoost(vol: real): void (0 – boostMax)
 *   - kindOf(node: PwNode): string ("usb" · "bluetooth" · "hdmi" · "analog": what the panel calls an output)
 *   - detailOf(node: PwNode): string («USB · estéreo 48 kHz», «Bluetooth · AAC», «Analógico · estéreo»)
 *   - setNoiseSuppression(on: bool): void (default input = the filter, or back to the last hardware input)
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
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && !root._isFilter(n))
    readonly property real boostMax: 1.5

    // noise suppression: a virtual source made by a filter (pipewire filter-chain with rnnoise / deepfilter, EasyEffects…)
    function _isFilter(n): bool {
        const t = `${n?.name ?? ""} ${n?.description ?? ""}`.toLowerCase();
        return /rnnoise|noise[ _-]?(cancel|suppress)|deepfilter|easyeffects_source|denois/.test(t);
    }
    readonly property PwNode noiseFilter: Pipewire.nodes.values.find(n => n.audio && !n.isSink && !n.isStream && root._isFilter(n)) ?? null
    readonly property bool noiseSuppression: noiseFilter !== null && source === noiseFilter
    property PwNode _lastHardwareSource: null
    onSourceChanged: if (source && !_isFilter(source)) _lastHardwareSource = source
    function setNoiseSuppression(on: bool): void {
        if (on && root.noiseFilter) Pipewire.preferredDefaultAudioSource = root.noiseFilter;
        else if (!on) Pipewire.preferredDefaultAudioSource = root._lastHardwareSource ?? root.sources[0] ?? null;
    }

    function kindOf(node): string {
        const p = node?.properties ?? {};
        const name = `${node?.name ?? ""}`;
        if (p["device.api"] === "bluez5" || name.startsWith("bluez_")) return "bluetooth";
        if (p["device.bus"] === "usb" || /usb/i.test(name)) return "usb";
        if (/hdmi|displayport/i.test(name + (node?.description ?? ""))) return "hdmi";
        return "analog";
    }
    function detailOf(node): string {
        const p = node?.properties ?? {};
        const kind = root.kindOf(node);
        const ch = Number(p["audio.channels"] ?? 0);
        const rate = Number(p["audio.rate"] ?? 0);
        const parts = [{ usb: "USB", bluetooth: "Bluetooth", hdmi: "HDMI", analog: "Analógico" }[kind]];
        if (kind === "bluetooth") { const codec = p["api.bluez5.codec"]; if (codec) parts.push(String(codec).toUpperCase()); }
        else {
            if (ch === 1) parts.push("mono"); else if (ch === 2 || ch === 0) parts.push("estéreo"); else parts.push(`${ch} canales`);
            if (rate > 0) parts.push(`${Math.round(rate / 1000)} kHz`);
        }
        return parts.join(" · ");
    }
    // application playback streams output audio towards a sink → isSink === false
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && !n.isSink)

    // Bind default devices and app streams so volume/mute/properties are valid
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(root.streams).concat(root.sinks).concat(root.sources)
    }

    function clamp01(v: real): real { return Math.max(0.0, Math.min(1.0, v)); }

    // the wheel / keys stay within 100 % unless the panel already boosted it (then up to boostMax)
    function setVolume(vol: real): void { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(root.volume > 1.001 ? root.boostMax : 1, vol)); }
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
    function setVolumeBoost(vol: real): void { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(root.boostMax, vol)); }
    function toggleNodeMute(node: PwNode): void { if (node?.audio) node.audio.muted = !node.audio.muted; }
}
