// =============================================================================
// dragon-island — Privacy.qml
// Service: which apps are using the microphone, the camera or a screen share (PipeWire)
// =============================================================================
/**
 * Detected from the PipeWire graph (all nodes are bound so their properties are readable):
 *   - microphone: an app capture stream (media.class "Stream/Input/Audio") that records a real source,
 *     not a sink monitor (stream.capture.sink), and not Quickshell itself
 *   - camera:     a video input stream (Stream/Input/Video) linked to a Video/Source device node
 *   - screen:     a video input stream linked to a screen-cast producer (Stream/Output/Video, the portal)
 *
 * Properties:
 *   - micApps / cameraApps / screenApps: list<string> [readonly] (application names)
 *   - mic / camera / screen: bool [readonly]
 *   - active: bool [readonly]
 *   - color: color [readonly] (green = camera only, orange otherwise)
 *   - kinds: list<var> [readonly] ([{ key: "mic" | "camera" | "screen", apps: list<string> }], only the active ones)
 */
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import ".."

Singleton {
    id: root

    PwObjectTracker { objects: Pipewire.nodes.values }

    function _p(node, key: string): string {
        const v = node?.properties?.[key];
        return v === undefined || v === null ? "" : `${v}`;
    }
    function _app(node): string {
        return _p(node, "application.name") || _p(node, "application.process.binary") || node?.description || node?.name || "?";
    }
    function _cls(node): string { return _p(node, "media.class"); }

    function _uniq(list) { return Array.from(new Set(list)).sort(); }

    // video streams grouped by what feeds them
    readonly property var _videoSources: {
        const cam = [], scr = [];
        for (const l of Pipewire.links.values) {
            const target = l.target, source = l.source;
            if (!target || !source || root._cls(target) !== "Stream/Input/Video") continue;
            const sc = root._cls(source);
            if (sc === "Video/Source") cam.push(root._app(target));
            else if (sc === "Stream/Output/Video") scr.push(root._app(target));
        }
        return { cam: cam, scr: scr };
    }

    readonly property var micApps: root._uniq(Pipewire.nodes.values
        .filter(n => root._cls(n) === "Stream/Input/Audio" && root._p(n, "stream.capture.sink") !== "true"
                     && !root._app(n).toLowerCase().includes("quickshell"))
        .map(n => root._app(n)))
    readonly property var cameraApps: root._uniq(root._videoSources.cam)
    readonly property var screenApps: root._uniq(root._videoSources.scr)

    readonly property bool mic: micApps.length > 0
    readonly property bool camera: cameraApps.length > 0
    readonly property bool screen: screenApps.length > 0
    readonly property bool active: mic || camera || screen
    readonly property color color: camera && !mic && !screen ? Theme.ok : Theme.warn

    readonly property var kinds: {
        const k = [];
        if (mic) k.push({ key: "mic", apps: micApps });
        if (camera) k.push({ key: "camera", apps: cameraApps });
        if (screen) k.push({ key: "screen", apps: screenApps });
        return k;
    }
}
