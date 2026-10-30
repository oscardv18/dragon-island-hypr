// =============================================================================
// dragon-island — Idle.qml
// Service: the idle sequence (docs/design/26-inactividad.png): warning + dim, lock, screens off, suspend.
// =============================================================================
/**
 * hypridle drives the timing with the config bin/dragon-idle generates from settings.json; its first step calls
 * `qs ipc call idle warn` (island state "idleWarn" + the dragon-dim layer rising to Theme.idleDimOpacity in
 * Theme.durDim) and `qs ipc call idle resume` when the user comes back. Changing a time in Ajustes › Energía runs
 * `dragon-idle restart` (hypridle only reads its config when it starts).
 * Nothing advances while `inhibit` is true: an IdleInhibitor on the island window (modules/island/IslandWindow.qml)
 * holds hypridle back when
 *   - a herdr agent is working (Settings.idleInhibitAgents, default on),
 *   - the recording mode is on,
 *   - a video plays: mpv and Chromium-based browsers inhibit by themselves (Wayland idle-inhibit / the D-Bus
 *     ScreenSaver interface hypridle listens to); as a fallback, an MPRIS player of a browser or video player is playing
 *     while one of its windows is on a visible workspace.
 *
 * Properties:
 *   - warning: bool [readonly] (island state "idleWarn", the dim layer is up)
 *   - lockIn: int [readonly] (seconds between the warning and the lock, for "Bloqueo en 60 s")
 *   - inhibit: bool [readonly] (something holds the sequence back) · inhibitReason: string [readonly]
 *
 * Functions:
 *   - warn(): void      resume(): void      applyTimes(): void (regenerate hypridle's config and restart it)
 *
 * IPC (`qs ipc call idle <fn>`): warn(), resume(), apply(), state(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool warning: false
    readonly property int lockIn: Math.max(0, Settings.idleLockSeconds - Settings.idleDimSeconds)

    readonly property bool _video: {
        if (!Media.isPlaying) return false;
        const id = (Media.identity || "").toLowerCase();
        if (!/(brave|chrom|firefox|librewolf|vivaldi|mpv|vlc|haruna|celluloid|totem|kodi)/.test(id)) return false;
        return Hypr.workspaces.some(w => w.visible && Hypr.windowsOn(w.id).some(t => (t.appClass || "").toLowerCase().includes(id.split(" ")[0])));
    }
    readonly property string inhibitReason: Settings.idleInhibitAgents && (Herdr.counts?.working ?? 0) > 0 ? "agente trabajando"
                                          : (RecordingMode.active ? "modo grabación" : (_video ? "vídeo en reproducción" : ""))
    readonly property bool inhibit: inhibitReason.length > 0

    function warn(): void { if (!root.inhibit) root.warning = true; }
    function resume(): void { root.warning = false; }
    onInhibitChanged: if (inhibit) root.warning = false

    function applyTimes(): void { Quickshell.execDetached([`${Quickshell.env("HOME")}/.local/bin/dragon-idle`, "restart"]); }
    // a time changed in Ajustes: regenerate (debounced, the slider writes several values)
    readonly property string _times: `${Settings.idleDimSeconds},${Settings.idleLockSeconds},${Settings.idleScreenOffSeconds},${Settings.idleSuspendSeconds}`
    property string _applied: ""
    on_TimesChanged: if (_applied.length > 0 && _applied !== _times) applyTimer.restart()
    Component.onCompleted: _applied = _times
    Timer { id: applyTimer; interval: 1500; onTriggered: { root._applied = root._times; root.applyTimes(); } }

    IpcHandler {
        target: "idle"
        function warn(): void { root.warn(); }
        function resume(): void { root.resume(); }
        function apply(): void { root.applyTimes(); }
        function state(): string { return `warning=${root.warning} inhibit=${root.inhibit} (${root.inhibitReason})`; }
    }
}
